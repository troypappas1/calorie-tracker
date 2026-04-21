// ─── Firebase (loaded dynamically so the app works without it) ────────────────
import { FIREBASE_CONFIG, FIREBASE_ENABLED } from '/firebase-config.js';

let auth = null, db = null, currentUser = null;
let GoogleAuthProvider, signInWithPopup, signOut;
let fsDoc, fsGetDoc, fsSetDoc, fsArrayUnion;

if (FIREBASE_ENABLED) {
  try {
    const [appMod, authMod, storeMod] = await Promise.all([
      import('https://www.gstatic.com/firebasejs/10.8.0/firebase-app.js'),
      import('https://www.gstatic.com/firebasejs/10.8.0/firebase-auth.js'),
      import('https://www.gstatic.com/firebasejs/10.8.0/firebase-firestore.js'),
    ]);
    const app = appMod.initializeApp(FIREBASE_CONFIG);
    auth = authMod.getAuth(app);
    db   = storeMod.getFirestore(app);
    ({ GoogleAuthProvider, signInWithPopup, signOut } = authMod);
    ({ doc: fsDoc, getDoc: fsGetDoc, setDoc: fsSetDoc, arrayUnion: fsArrayUnion } = storeMod);

    authMod.onAuthStateChanged(auth, async (user) => {
      currentUser = user;
      updateAuthUI(user);
      if (user) await syncLocalToFirestore(TODAY);
      await renderCalendar();
      await render(viewDate);
    });
  } catch (e) {
    console.warn('Firebase unavailable:', e.message);
    showNotConfigured();
    initWithoutFirebase();
  }
} else {
  showNotConfigured();
  initWithoutFirebase();
}

function showNotConfigured() {
  const hint = document.getElementById('auth-hint');
  if (hint) hint.textContent = 'Firebase not set up — see firebase-config.js';
}

// ─── Constants ────────────────────────────────────────────────────────────────
function todayPT() {
  return new Date().toLocaleDateString('en-CA', { timeZone: 'America/Los_Angeles' });
}
const TODAY = todayPT();
const MONTH_NAMES = ['January','February','March','April','May','June','July','August','September','October','November','December'];

function computeGoals() {
  try {
    const p = JSON.parse(localStorage.getItem('ct_profile') || '{}');
    if (!p.weight || !p.height || !p.age) return defaultGoals();

    // Mifflin-St Jeor BMR
    const bmr = p.sex === 'female'
      ? 10 * p.weight + 6.25 * p.height - 5 * p.age - 161
      : 10 * p.weight + 6.25 * p.height - 5 * p.age + 5;
    const tdee = Math.round(bmr * 1.55);
    const cal  = p.goal === 'lose' ? Math.max(tdee - 500, 1200) : p.goal === 'gain' ? tdee + 300 : tdee;

    // Protein: 0.8g/kg maintain, 1.2g/kg lose (preserve muscle), 1.6g/kg gain (build muscle)
    const proteinRate = p.goal === 'gain' ? 1.6 : p.goal === 'lose' ? 1.2 : 0.8;
    const protein = Math.round(p.weight * proteinRate);

    // Fat: 25-35% of calories; use 30%
    const fat   = Math.round(cal * 0.30 / 9);

    // Carbs: remaining calories after protein and fat
    const carbs = Math.round((cal - protein * 4 - fat * 9) / 4);

    // Fiber: 14g per 1000 kcal (DRI), capped at 38g men / 25g women
    const fiberMax = p.sex === 'female' ? 25 : 38;
    const fiber = Math.min(Math.round(cal / 1000 * 14), fiberMax);

    // Sugar limit: <10% of calories (WHO)
    const sugar = Math.round(cal * 0.10 / 4);

    // Sodium: 2300mg all adults (AHA)
    const sodium = 2300;

    // Vitamins & minerals — DRI by sex and age (% Daily Value targets as mg/mcg)
    // We track as % DV so targets are always 100 for each micronutrient
    // but we store the actual DV reference amounts for tooltip/display purposes
    const female = p.sex === 'female';
    const age    = p.age;

    // Vitamin A (mcg RAE): 700 women, 900 men
    const vitA_dv  = female ? 700 : 900;
    // Vitamin C (mg): 75 women, 90 men; +35 smokers (unknown, ignore)
    const vitC_dv  = female ? 75 : 90;
    // Calcium (mg): varies significantly by age
    const calcium_dv = age < 19 ? 1300 : age <= 50 ? 1000 : female ? 1200 : 1000;
    // Iron (mg): 18 women 19-50, 8 otherwise
    const iron_dv = female && age >= 19 && age <= 50 ? 18 : 8;

    return {
      calories: cal, protein, carbs, fat, fiber, sugar, sodium,
      vitA_dv, vitC_dv, calcium_dv, iron_dv,
    };
  } catch { return defaultGoals(); }
}

function defaultGoals() {
  return {
    calories: 2000, protein: 50, carbs: 275, fat: 65, fiber: 28, sugar: 50, sodium: 2300,
    vitA_dv: 900, vitC_dv: 90, calcium_dv: 1000, iron_dv: 8,
  };
}

let GOALS = computeGoals();

// Returns a 0-1 fraction representing how far through the eating day we are.
// Eating window: 7am–9pm (14 hrs). Clamp to [0,1].
function dayProgress() {
  const now = new Date();
  const ptStr = now.toLocaleString('en-US', { timeZone: 'America/Los_Angeles', hour: 'numeric', minute: 'numeric', hour12: false });
  const [h, m] = ptStr.split(':').map(Number);
  const minutesSince7am = h * 60 + m - 7 * 60;
  return Math.max(0, Math.min(1, minutesSince7am / (14 * 60)));
}

// ─── State ────────────────────────────────────────────────────────────────────
let viewDate = TODAY;
let calYear  = new Date().getFullYear();
let calMonth = new Date().getMonth(); // 0-indexed

// ─── Data layer ───────────────────────────────────────────────────────────────

function localKey(dateStr) { return `ct_log_${dateStr}`; }

function getLocalEntries(dateStr) {
  try { return JSON.parse(localStorage.getItem(localKey(dateStr)) || '[]'); }
  catch { return []; }
}

function saveLocalEntries(dateStr, entries) {
  try { localStorage.setItem(localKey(dateStr), JSON.stringify(entries)); }
  catch { alert('Could not save — local storage may be full.'); }
}

async function getEntries(dateStr) {
  const local = getLocalEntries(dateStr);
  if (!currentUser || !db) return local;
  try {
    const snap = await fsGetDoc(fsDoc(db, 'users', currentUser.uid, 'logs', dateStr));
    const cloud = snap.exists() ? (snap.data().entries || []) : [];
    const cloudIds = new Set(cloud.map(e => e.id));
    const merged = [...cloud, ...local.filter(e => !cloudIds.has(e.id))];
    saveLocalEntries(dateStr, merged);
    return merged;
  } catch { return local; }
}

async function saveEntries(dateStr, entries) {
  saveLocalEntries(dateStr, entries);
  if (!currentUser || !db) return;
  try {
    await fsSetDoc(fsDoc(db, 'users', currentUser.uid, 'logs', dateStr), { entries });
    const [y, m] = dateStr.split('-');
    await fsSetDoc(
      fsDoc(db, 'users', currentUser.uid, 'months', `${y}-${m}`),
      { days: fsArrayUnion(parseInt(dateStr.split('-')[2])) },
      { merge: true }
    );
  } catch (e) { console.error('Firestore save error:', e); }
}

async function removeEntry(dateStr, id) {
  const entries = await getEntries(dateStr);
  await saveEntries(dateStr, entries.filter(e => e.id !== id));
  await render(dateStr);
  await renderCalendar();
}

async function clearDay(dateStr) {
  saveLocalEntries(dateStr, []);
  if (currentUser && db) {
    try { await fsSetDoc(fsDoc(db, 'users', currentUser.uid, 'logs', dateStr), { entries: [] }); }
    catch {}
  }
  await render(dateStr);
  await renderCalendar();
}

async function syncLocalToFirestore(dateStr) {
  if (!currentUser || !db) return;
  const local = getLocalEntries(dateStr);
  if (!local.length) return;
  try {
    const snap = await fsGetDoc(fsDoc(db, 'users', currentUser.uid, 'logs', dateStr));
    const cloud = snap.exists() ? (snap.data().entries || []) : [];
    const cloudIds = new Set(cloud.map(e => e.id));
    const toAdd = local.filter(e => !cloudIds.has(e.id));
    if (toAdd.length) await saveEntries(dateStr, [...cloud, ...toAdd]);
  } catch {}
}

async function getDaysWithEntries(year, month) {
  const days = new Set();
  const monthStr = `${year}-${String(month + 1).padStart(2, '0')}`;

  for (let i = 0; i < localStorage.length; i++) {
    const key = localStorage.key(i);
    if (!key || !key.startsWith(`ct_log_${monthStr}-`)) continue;
    const entries = JSON.parse(localStorage.getItem(key) || '[]');
    if (entries.length) days.add(parseInt(key.slice(-2)));
  }

  if (currentUser && db) {
    try {
      const snap = await fsGetDoc(fsDoc(db, 'users', currentUser.uid, 'months', monthStr));
      if (snap.exists()) (snap.data().days || []).forEach(d => days.add(d));
    } catch {}
  }
  return days;
}

// ─── Calendar ─────────────────────────────────────────────────────────────────

async function renderCalendar() {
  document.getElementById('cal-month-label').textContent = `${MONTH_NAMES[calMonth]} ${calYear}`;

  const daysWithEntries = await getDaysWithEntries(calYear, calMonth);
  const firstWeekday   = new Date(calYear, calMonth, 1).getDay();
  const daysInMonth    = new Date(calYear, calMonth + 1, 0).getDate();
  const grid = document.getElementById('cal-grid');
  grid.innerHTML = '';

  for (let i = 0; i < firstWeekday; i++) {
    grid.appendChild(Object.assign(document.createElement('div'), { className: 'cal-cell cal-empty' }));
  }

  for (let d = 1; d <= daysInMonth; d++) {
    const dateStr = `${calYear}-${String(calMonth + 1).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
    const isFuture   = dateStr > TODAY;
    const isToday    = dateStr === TODAY;
    const isSelected = dateStr === viewDate;
    const hasEntries = daysWithEntries.has(d);

    const cell = document.createElement('div');
    cell.className = ['cal-cell',
      isFuture   ? 'cal-future'   : '',
      isToday    ? 'cal-today'    : '',
      isSelected ? 'cal-selected' : '',
      hasEntries ? 'cal-has-data' : '',
    ].filter(Boolean).join(' ');

    cell.innerHTML = `<span class="cal-num">${d}</span>${hasEntries ? '<span class="cal-dot"></span>' : ''}`;

    if (!isFuture) {
      cell.addEventListener('click', async () => {
        viewDate = dateStr;
        // Sync calendar month to selected date's month
        calYear  = parseInt(dateStr.split('-')[0]);
        calMonth = parseInt(dateStr.split('-')[1]) - 1;
        await renderCalendar();
        await render(viewDate);
      });
    }
    grid.appendChild(cell);
  }
}

document.getElementById('cal-prev').addEventListener('click', async () => {
  calMonth--; if (calMonth < 0) { calMonth = 11; calYear--; }
  await renderCalendar();
});
document.getElementById('cal-next').addEventListener('click', async () => {
  calMonth++; if (calMonth > 11) { calMonth = 0; calYear++; }
  await renderCalendar();
});

// ─── Auth UI ──────────────────────────────────────────────────────────────────

function updateAuthUI(user) {
  const out        = document.getElementById('auth-signed-out');
  const inEl       = document.getElementById('auth-signed-in');
  const loading    = document.getElementById('auth-loading');
  const chip       = document.getElementById('user-chip');
  const chipAvatar = document.getElementById('chip-avatar');
  const chipName   = document.getElementById('chip-name');
  loading.hidden = true;
  if (user) {
    out.hidden  = true;
    inEl.hidden = false;
    document.getElementById('user-name').textContent = user.displayName || user.email || 'Signed in';
    const avatar = document.getElementById('user-avatar');
    avatar.src = user.photoURL || '';
    avatar.style.display = user.photoURL ? 'block' : 'none';
    if (chip) {
      chip.hidden = false;
      chipAvatar.src = user.photoURL || '';
      chipAvatar.style.display = user.photoURL ? 'block' : 'none';
      chipName.textContent = (user.displayName || user.email || '').split(' ')[0];
    }
  } else {
    out.hidden  = false;
    inEl.hidden = true;
    if (chip) chip.hidden = true;
  }
}

document.getElementById('sign-in-btn').addEventListener('click', async () => {
  if (!auth || !GoogleAuthProvider) {
    alert('Google Sign-In is not set up yet.\n\nOpen static/firebase-config.js and follow the instructions inside to connect your Firebase project.');
    return;
  }
  document.getElementById('auth-loading').hidden    = false;
  document.getElementById('auth-signed-out').hidden = true;
  try {
    await signInWithPopup(auth, new GoogleAuthProvider());
  } catch (e) {
    document.getElementById('auth-loading').hidden    = true;
    document.getElementById('auth-signed-out').hidden = false;
    if (e.code !== 'auth/popup-closed-by-user') console.error('Sign-in error:', e);
  }
});

document.getElementById('sign-out-btn').addEventListener('click', async () => {
  if (!auth) return;
  try { await signOut(auth); } catch {}
});

// ─── Status + recommendations ─────────────────────────────────────────────────

function buildRecs(t, entries, dateStr) {
  if (!entries.length) return [];
  const isToday = dateStr === TODAY;
  const progress = isToday ? dayProgress() : 1;
  const pct  = (v, g) => g > 0 ? Math.round((v / g) * 100) : 0;
  const expected = (g) => g * progress; // how much we'd expect by now if eating evenly
  const meals  = entries.filter(e => (e.mealType || 'meal') === 'meal').length;
  const snacks = entries.filter(e => e.mealType === 'snack').length;
  const recs = [];

  // Calorie pace
  const calPct = pct(t.calories, GOALS.calories);
  if (isToday && progress > 0.1) {
    const expectedCalPct = Math.round(progress * 100);
    if (calPct < expectedCalPct - 20) {
      recs.push({ icon: '↑', text: `Calories are behind pace — you've had ${calPct}% of your goal but it's ${expectedCalPct}% through your eating day. Add a meal or snack.` });
    } else if (calPct > 110) {
      recs.push({ icon: '↓', text: `You're over your calorie goal for the day. Opt for lighter options like salad or broth soup.` });
    } else if (calPct >= expectedCalPct - 10) {
      recs.push({ icon: '✓', text: `Calories on pace — ${calPct}% of your goal with ${100 - expectedCalPct}% of the day left.` });
    }
  } else if (!isToday && calPct > 110) {
    recs.push({ icon: '↓', text: `Ended over calorie goal at ${calPct}%.` });
  }

  // Protein
  if (pct(t.protein, GOALS.protein) < Math.round(progress * 70))
    recs.push({ icon: '↑', text: `Protein is behind pace for ${meals} meal${meals !== 1 ? 's' : ''}. Add chicken, fish, eggs, Greek yogurt, or legumes.` });

  // Carbs
  if (pct(t.carbs, GOALS.carbs) > 115)
    recs.push({ icon: '↓', text: 'Carbs are high. Choose fiber-rich options and cut refined sugars.' });
  else if (isToday && pct(t.carbs, GOALS.carbs) < Math.round(progress * 50))
    recs.push({ icon: '↑', text: 'Carbs are low — try whole grains, fruit, or starchy vegetables for energy.' });

  // Limits (fat, sugar, sodium — only warn when over)
  if (pct(t.fat, GOALS.fat) > 110)
    recs.push({ icon: '↓', text: 'Fat is high. Choose lean proteins and limit fried or processed foods.' });
  if (pct(t.sugar, GOALS.sugar) > 100)
    recs.push({ icon: '↓', text: 'Sugar is over your daily limit. Cut back on sweets, sodas, and processed snacks.' });
  if (pct(t.sodium, GOALS.sodium) > 100)
    recs.push({ icon: '↓', text: 'Sodium is over your daily limit. Limit salty snacks, fast food, and canned foods.' });

  // Fiber
  if (pct(t.fiber, GOALS.fiber) < Math.round(progress * 60))
    recs.push({ icon: '↑', text: 'Fiber is low — eat more vegetables, fruits, beans, or whole grains.' });

  // Vitamins
  const scaleVit = (pct, fdaDv, personalDv) => Math.round(pct * (fdaDv / personalDv));
  if (scaleVit(t.vitA, 900, GOALS.vitA_dv) < 40)
    recs.push({ icon: '↑', text: 'Low Vitamin A — try carrots, sweet potato, spinach, or eggs.' });
  if (scaleVit(t.vitC, 90, GOALS.vitC_dv) < 40)
    recs.push({ icon: '↑', text: 'Low Vitamin C — eat citrus fruits, bell peppers, or strawberries.' });
  if (scaleVit(t.calcium, 1300, GOALS.calcium_dv) < 40)
    recs.push({ icon: '↑', text: 'Low Calcium — try dairy, fortified plant milk, leafy greens, or almonds.' });
  if (scaleVit(t.iron, 18, GOALS.iron_dv) < 40)
    recs.push({ icon: '↑', text: 'Low Iron — add red meat, lentils, spinach, or fortified cereals.' });

  // Snack count note
  if (snacks >= 3)
    recs.push({ icon: '↓', text: `${snacks} snacks logged today — watch that snacking doesn't crowd out balanced meals.` });

  return recs;
}

function overallStatus(t, entries, dateStr) {
  if (!entries.length) return { label: 'No meals yet', cls: 'dsp-badge--neutral', sub: 'Add a meal from the analyzer to start tracking.' };
  const isToday = dateStr === TODAY;
  const progress = isToday ? dayProgress() : 1;
  const pct = (v, g) => v / g * 100;
  const meals = entries.filter(e => (e.mealType || 'meal') === 'meal').length;

  if ([pct(t.calories, GOALS.calories), pct(t.sodium, GOALS.sodium), pct(t.sugar, GOALS.sugar), pct(t.fat, GOALS.fat)].some(p => p > 115))
    return { label: 'Over Goal', cls: 'dsp-badge--over', sub: 'Some nutrients are above recommended limits for the day.' };

  if (isToday && progress > 0) {
    const calPct = pct(t.calories, GOALS.calories);
    const expectedPct = progress * 100;
    if (calPct >= expectedPct - 15 && calPct <= expectedPct + 15 && pct(t.protein, GOALS.protein) >= expectedPct * 0.6)
      return { label: 'On Pace', cls: 'dsp-badge--good', sub: `${meals} meal${meals !== 1 ? 's' : ''} logged — calories and protein are on track for the time of day.` };
    if (calPct < expectedPct - 20)
      return { label: 'Behind Pace', cls: 'dsp-badge--warn', sub: `Only ${Math.round(calPct)}% of your calorie goal so far. You may need another meal or snack.` };
  }

  if (!isToday && [pct(t.calories, GOALS.calories), pct(t.protein, GOALS.protein), pct(t.carbs, GOALS.carbs)].every(p => p >= 70))
    return { label: 'Good Day', cls: 'dsp-badge--good', sub: 'Hit most nutrition targets for the day.' };

  return { label: 'Needs Attention', cls: 'dsp-badge--warn', sub: 'A few nutrients need some attention.' };
}

// ─── Sidebar goal bars ────────────────────────────────────────────────────────

function goalColor(pct, isLimit) {
  if (isLimit) { if (pct <= 80) return '#4caf50'; if (pct <= 100) return '#ff9800'; return '#e53935'; }
  if (pct < 50) return '#d96f32'; if (pct < 80) return '#ff9800'; if (pct <= 110) return '#4caf50'; return '#e53935';
}

function setSidebarGoalBar(id, cur, goal, isLimit) {
  const bar = document.getElementById(id);
  if (!bar) return;
  const pct = goal > 0 ? Math.round((cur / goal) * 100) : 0;
  bar.style.width      = `${Math.min(pct, 100)}%`;
  bar.style.background = goalColor(pct, isLimit);
}

function clamp(v) { return Math.min(v || 0, 100); }

function setVitBar(barId, labelId, val) {
  const bar = document.getElementById(barId);
  const lbl = document.getElementById(labelId);
  if (bar) { bar.style.width = `${clamp(val)}%`; bar.style.background = val >= 80 ? '#4caf50' : val >= 50 ? '#ff9800' : 'var(--accent)'; }
  if (lbl) lbl.textContent = `${val || 0}%`;
}

// ─── Main render ──────────────────────────────────────────────────────────────

async function render(dateStr) {
  // Viewing label
  const labelEl = document.getElementById('myday-viewing-label');
  if (dateStr === TODAY) {
    labelEl.textContent = 'Today';
  } else {
    const d = new Date(dateStr + 'T12:00:00');
    labelEl.textContent = d.toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric' });
  }

  const entries = await getEntries(dateStr);

  const t = entries.reduce((a, e) => {
    a.calories += e.calories     || 0;
    a.protein  += e.proteinGrams || 0;
    a.fat      += e.fatGrams     || 0;
    a.carbs    += e.carbsGrams   || 0;
    a.fiber    += e.fiberGrams   || 0;
    a.sugar    += e.sugarGrams   || 0;
    a.sodium   += e.sodiumMg     || 0;
    a.vitA     += e.vitaminA     || 0;
    a.vitC     += e.vitaminC     || 0;
    a.calcium  += e.calcium      || 0;
    a.iron     += e.iron         || 0;
    return a;
  }, { calories: 0, protein: 0, fat: 0, carbs: 0, fiber: 0, sugar: 0, sodium: 0, vitA: 0, vitC: 0, calcium: 0, iron: 0 });

  GOALS = computeGoals();

  // Update sidebar goal labels
  const gl = document.getElementById('goal-label-calories');
  if (gl) gl.textContent = ` / ${GOALS.calories.toLocaleString()}`;
  const gp = document.getElementById('goal-label-protein');
  if (gp) gp.textContent = ` / ${GOALS.protein}g`;
  const gc = document.getElementById('goal-label-carbs');
  if (gc) gc.textContent = ` / ${GOALS.carbs}g`;
  const gf = document.getElementById('goal-label-fat');
  if (gf) gf.textContent = ` / ${GOALS.fat}g lim`;
  const gfi = document.getElementById('goal-label-fiber');
  if (gfi) gfi.textContent = ` / ${GOALS.fiber}g`;
  const gs = document.getElementById('goal-label-sugar');
  if (gs) gs.textContent = ` / ${GOALS.sugar}g lim`;
  const gso = document.getElementById('goal-label-sodium');
  if (gso) gso.textContent = ` / ${GOALS.sodium.toLocaleString()}mg`;

  // Sidebar values
  document.getElementById('s-calories').textContent = t.calories;
  document.getElementById('s-protein').textContent  = `${t.protein}g`;
  document.getElementById('s-fat').textContent      = `${t.fat}g`;
  document.getElementById('s-carbs').textContent    = `${t.carbs}g`;
  document.getElementById('s-fiber').textContent    = `${t.fiber}g`;
  document.getElementById('s-sugar').textContent    = `${t.sugar}g`;
  document.getElementById('s-sodium').textContent   = `${t.sodium}mg`;

  setSidebarGoalBar('sgb-calories', t.calories, GOALS.calories, false);
  setSidebarGoalBar('sgb-protein',  t.protein,  GOALS.protein,  false);
  setSidebarGoalBar('sgb-carbs',    t.carbs,    GOALS.carbs,    false);
  setSidebarGoalBar('sgb-fat',      t.fat,      GOALS.fat,      true);
  setSidebarGoalBar('sgb-fiber',    t.fiber,    GOALS.fiber,    false);
  setSidebarGoalBar('sgb-sugar',    t.sugar,    GOALS.sugar,    true);
  setSidebarGoalBar('sgb-sodium',   t.sodium,   GOALS.sodium,   true);

  // Scale % DV from AI (based on FDA label DVs) to personalized DVs.
  // FDA label reference DVs: vitA=900mcg, vitC=90mg, calcium=1300mg, iron=18mg
  const scaleVit = (pct, fdaDv, personalDv) => Math.round(pct * (fdaDv / personalDv));
  setVitBar('s-bar-vitA',    's-vitA',    scaleVit(t.vitA,    900,  GOALS.vitA_dv));
  setVitBar('s-bar-vitC',    's-vitC',    scaleVit(t.vitC,    90,   GOALS.vitC_dv));
  setVitBar('s-bar-calcium', 's-calcium', scaleVit(t.calcium, 1300, GOALS.calcium_dv));
  setVitBar('s-bar-iron',    's-iron',    scaleVit(t.iron,    18,   GOALS.iron_dv));

  // Status panel
  const status = overallStatus(t, entries, dateStr);
  const badge  = document.getElementById('dsp-badge');
  badge.textContent = status.label;
  badge.className   = `dsp-badge ${status.cls}`;
  document.getElementById('dsp-sub').textContent = status.sub;

  const recsEl = document.getElementById('dsp-recs');
  const recs   = buildRecs(t, entries, dateStr);
  recsEl.innerHTML = recs.map(r => `
    <div class="rec-card"><span class="rec-icon">${r.icon}</span><span class="rec-text">${r.text}</span></div>
  `).join('');

  // Food log
  const log = document.getElementById('food-log-full');
  if (!entries.length) {
    log.innerHTML = '<p class="empty-log">No meals logged for this day.</p>';
    return;
  }
  log.innerHTML = '';
  for (const entry of entries) {
    const article = document.createElement('article');
    article.className = 'entry-card';
    const thumbHtml = entry.thumb
      ? `<img class="entry-thumb" src="${entry.thumb}" alt="${entry.title}">`
      : `<div class="entry-thumb-placeholder">&#127869;</div>`;
    const typeLabel = (entry.mealType || 'meal');
    article.innerHTML = `
      <div class="entry-card-top">
        ${thumbHtml}
        <div class="entry-card-title-row">
          <div class="entry-card-title-wrap">
            <strong class="entry-card-title">${entry.title}</strong>
            <span class="entry-type-badge entry-type-${typeLabel}">${typeLabel}</span>
          </div>
          <button class="remove-btn" data-id="${entry.id}">&#10005; Remove</button>
        </div>
      </div>
      <div class="entry-macros-grid">
        <div class="entry-macro"><span class="entry-macro-label">Calories</span><strong>${entry.calories || 0}</strong></div>
        <div class="entry-macro"><span class="entry-macro-label">Protein</span><strong>${entry.proteinGrams || 0}g</strong></div>
        <div class="entry-macro"><span class="entry-macro-label">Fat</span><strong>${entry.fatGrams || 0}g</strong></div>
        <div class="entry-macro"><span class="entry-macro-label">Carbs</span><strong>${entry.carbsGrams || 0}g</strong></div>
        <div class="entry-macro"><span class="entry-macro-label">Fiber</span><strong>${entry.fiberGrams || 0}g</strong></div>
        <div class="entry-macro"><span class="entry-macro-label">Sugar</span><strong>${entry.sugarGrams || 0}g</strong></div>
        <div class="entry-macro"><span class="entry-macro-label">Sodium</span><strong>${entry.sodiumMg || 0}mg</strong></div>
      </div>
      <div class="entry-vitamins">
        <div class="vitamin-item"><span class="vitamin-label">Vitamin A</span><div class="vitamin-bar-wrap"><div class="vitamin-bar" style="width:${clamp(entry.vitaminA)}%"></div></div><span class="vitamin-pct">${entry.vitaminA || 0}%</span></div>
        <div class="vitamin-item"><span class="vitamin-label">Vitamin C</span><div class="vitamin-bar-wrap"><div class="vitamin-bar" style="width:${clamp(entry.vitaminC)}%"></div></div><span class="vitamin-pct">${entry.vitaminC || 0}%</span></div>
        <div class="vitamin-item"><span class="vitamin-label">Calcium</span><div class="vitamin-bar-wrap"><div class="vitamin-bar" style="width:${clamp(entry.calcium)}%"></div></div><span class="vitamin-pct">${entry.calcium || 0}%</span></div>
        <div class="vitamin-item"><span class="vitamin-label">Iron</span><div class="vitamin-bar-wrap"><div class="vitamin-bar" style="width:${clamp(entry.iron)}%"></div></div><span class="vitamin-pct">${entry.iron || 0}%</span></div>
      </div>`;
    log.appendChild(article);
  }
  log.querySelectorAll('.remove-btn').forEach(btn => {
    btn.addEventListener('click', () => removeEntry(dateStr, btn.dataset.id));
  });
}

// ─── Init (no Firebase path) ──────────────────────────────────────────────────

async function initWithoutFirebase() {
  await renderCalendar();
  await render(viewDate);
  attachStaticListeners();
}

function attachStaticListeners() {
  const dateEl = document.getElementById('sidebar-date');
  if (dateEl) dateEl.textContent = new Date().toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' });

  document.getElementById('clear-day-btn').addEventListener('click', () => {
    const label = viewDate === TODAY ? 'today' : viewDate;
    if (confirm(`Clear all meals for ${label}?`)) clearDay(viewDate);
  });
}

// ─── Sidebar date + clear button (also needed in Firebase path) ───────────────
const dateEl = document.getElementById('sidebar-date');
if (dateEl) dateEl.textContent = new Date().toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' });

document.getElementById('clear-day-btn').addEventListener('click', () => {
  const label = viewDate === TODAY ? 'today' : viewDate;
  if (confirm(`Clear all meals for ${label}?`)) clearDay(viewDate);
});

// Re-render goals immediately when profile is saved
window.addEventListener('storage', (e) => {
  if (e.key === 'ct_profile') render(viewDate);
});

// If Firebase is disabled, render now (Firebase path renders on auth state change)
if (!FIREBASE_ENABLED) {
  await renderCalendar();
  await render(viewDate);
}
