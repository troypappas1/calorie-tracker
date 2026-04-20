// Daily goals (based on standard 2,000 kcal diet)
const GOALS = {
  calories: 2000,
  protein:  50,    // g
  carbs:    275,   // g
  fat:      78,    // g
  fiber:    28,    // g
  sugar:    50,    // g  (limit)
  sodium:   2300,  // mg (limit)
  vitA:     100,   // % DV
  vitC:     100,
  calcium:  100,
  iron:     100,
};

// Nutrients where hitting the goal is good (vs limit nutrients where lower is better)
const LIMIT_NUTRIENTS = new Set(["sugar", "sodium", "fat"]);

const RECS = {
  calories_low:   { icon: "↑", text: "You still have calorie room — add a balanced meal or healthy snack." },
  calories_over:  { icon: "↓", text: "You're over your calorie goal. Opt for lighter options like salad or broth soup." },
  protein_low:    { icon: "↑", text: "Boost protein with chicken, fish, eggs, Greek yogurt, or legumes." },
  protein_over:   { icon: "✓", text: "Great protein intake today!" },
  carbs_low:      { icon: "↑", text: "Carbs are low — try whole grains, fruit, or starchy vegetables for energy." },
  carbs_over:     { icon: "↓", text: "Carbs are high. Choose fiber-rich options and cut back on refined sugars." },
  fat_over:       { icon: "↓", text: "Fat is high. Choose lean proteins and limit fried or processed foods." },
  fiber_low:      { icon: "↑", text: "Fiber is low — eat more vegetables, fruits, beans, or whole grains." },
  sugar_over:     { icon: "↓", text: "Sugar is high. Cut back on sweets, sodas, and processed snacks." },
  sodium_over:    { icon: "↓", text: "Sodium is high. Limit salty snacks, fast food, and canned foods." },
  vitA_low:       { icon: "↑", text: "Low Vitamin A — try carrots, sweet potato, spinach, or eggs." },
  vitC_low:       { icon: "↑", text: "Low Vitamin C — eat citrus fruits, bell peppers, or strawberries." },
  calcium_low:    { icon: "↑", text: "Low Calcium — try dairy, fortified plant milk, leafy greens, or almonds." },
  iron_low:       { icon: "↑", text: "Low Iron — add red meat, lentils, spinach, or fortified cereals." },
};

// ─── localStorage helpers ───────────────────────────────────────────────────

function todayKey() {
  return `ct_log_${new Date().toISOString().slice(0, 10)}`;
}

function getDayEntries() {
  try { return JSON.parse(localStorage.getItem(todayKey()) || "[]"); }
  catch { return []; }
}

function saveDayEntries(entries) {
  try { localStorage.setItem(todayKey(), JSON.stringify(entries)); }
  catch { alert("Could not save — local storage may be full."); }
}

function removeDayEntry(id) {
  saveDayEntries(getDayEntries().filter((e) => e.id !== id));
  render();
}

// ─── Goal bar helpers ────────────────────────────────────────────────────────

function goalColor(pct, isLimit) {
  if (isLimit) {
    if (pct <= 80)  return "#4caf50";
    if (pct <= 100) return "#ff9800";
    return "#e53935";
  }
  if (pct < 50)   return "#d96f32";
  if (pct < 80)   return "#ff9800";
  if (pct <= 110) return "#4caf50";
  return "#e53935";
}

function setSidebarGoalBar(barId, current, goal, isLimit) {
  const bar = document.getElementById(barId);
  if (!bar) return;
  const pct = goal > 0 ? Math.round((current / goal) * 100) : 0;
  bar.style.width  = `${Math.min(pct, 100)}%`;
  bar.style.background = goalColor(pct, isLimit);
}

function clamp(val) { return Math.min(val || 0, 100); }

function setVitBar(barId, labelId, val) {
  const bar = document.getElementById(barId);
  const label = document.getElementById(labelId);
  if (bar) {
    bar.style.width = `${clamp(val)}%`;
    bar.style.background = val >= 80 ? "#4caf50" : val >= 50 ? "#ff9800" : "var(--accent)";
  }
  if (label) label.textContent = `${val || 0}%`;
}

// ─── Recommendation engine ────────────────────────────────────────────────────

function buildRecs(t, entries) {
  if (entries.length === 0) return [];

  const pct = (val, goal) => goal > 0 ? Math.round((val / goal) * 100) : 0;

  const keys = [];

  // Calories
  const calPct = pct(t.calories, GOALS.calories);
  if (calPct < 60)       keys.push("calories_low");
  else if (calPct > 110) keys.push("calories_over");

  // Protein
  const protPct = pct(t.protein, GOALS.protein);
  if (protPct < 60)      keys.push("protein_low");
  else if (protPct > 130) keys.push("protein_over");

  // Carbs
  const carbPct = pct(t.carbs, GOALS.carbs);
  if (carbPct < 50)      keys.push("carbs_low");
  else if (carbPct > 110) keys.push("carbs_over");

  // Fat (limit)
  if (pct(t.fat, GOALS.fat) > 110) keys.push("fat_over");

  // Fiber
  if (pct(t.fiber, GOALS.fiber) < 60) keys.push("fiber_low");

  // Sugar (limit)
  if (pct(t.sugar, GOALS.sugar) > 100) keys.push("sugar_over");

  // Sodium (limit)
  if (pct(t.sodium, GOALS.sodium) > 100) keys.push("sodium_over");

  // Vitamins
  if (t.vitA < 50)    keys.push("vitA_low");
  if (t.vitC < 50)    keys.push("vitC_low");
  if (t.calcium < 50) keys.push("calcium_low");
  if (t.iron < 50)    keys.push("iron_low");

  return keys.map((k) => RECS[k]).filter(Boolean);
}

function overallStatus(t, entries) {
  if (entries.length === 0) {
    return { label: "No meals yet", cls: "dsp-badge--neutral", sub: "Add a meal from the analyzer to start tracking your day." };
  }
  const calPct  = t.calories / GOALS.calories * 100;
  const sodPct  = t.sodium   / GOALS.sodium   * 100;
  const sugPct  = t.sugar    / GOALS.sugar    * 100;
  const fatPct  = t.fat      / GOALS.fat      * 100;

  if (calPct > 115 || sodPct > 115 || sugPct > 115 || fatPct > 115) {
    return { label: "Over Goal", cls: "dsp-badge--over", sub: "Some nutrients are above recommended limits. See suggestions below." };
  }

  const protPct = t.protein / GOALS.protein * 100;
  const carbPct = t.carbs   / GOALS.carbs   * 100;
  const fibPct  = t.fiber   / GOALS.fiber   * 100;

  const allGood = [calPct, protPct, carbPct, fibPct].every((p) => p >= 65);
  if (allGood && calPct <= 110) {
    return { label: "On Track", cls: "dsp-badge--good", sub: "You're doing well today. Keep it up!" };
  }

  return { label: "Needs Attention", cls: "dsp-badge--warn", sub: "A few nutrients need some attention. See the tips below." };
}

// ─── Main render ─────────────────────────────────────────────────────────────

function render() {
  const entries = getDayEntries();

  const t = entries.reduce(
    (acc, e) => {
      acc.calories += e.calories     || 0;
      acc.protein  += e.proteinGrams || 0;
      acc.fat      += e.fatGrams     || 0;
      acc.carbs    += e.carbsGrams   || 0;
      acc.fiber    += e.fiberGrams   || 0;
      acc.sugar    += e.sugarGrams   || 0;
      acc.sodium   += e.sodiumMg     || 0;
      acc.vitA     += e.vitaminA     || 0;
      acc.vitC     += e.vitaminC     || 0;
      acc.calcium  += e.calcium      || 0;
      acc.iron     += e.iron         || 0;
      return acc;
    },
    { calories: 0, protein: 0, fat: 0, carbs: 0, fiber: 0, sugar: 0, sodium: 0, vitA: 0, vitC: 0, calcium: 0, iron: 0 }
  );

  // ── Sidebar values ──
  document.getElementById("s-calories").textContent = t.calories;
  document.getElementById("s-protein").textContent  = `${t.protein}g`;
  document.getElementById("s-fat").textContent      = `${t.fat}g`;
  document.getElementById("s-carbs").textContent    = `${t.carbs}g`;
  document.getElementById("s-fiber").textContent    = `${t.fiber}g`;
  document.getElementById("s-sugar").textContent    = `${t.sugar}g`;
  document.getElementById("s-sodium").textContent   = `${t.sodium}mg`;

  // ── Sidebar goal bars ──
  setSidebarGoalBar("sgb-calories", t.calories, GOALS.calories, false);
  setSidebarGoalBar("sgb-protein",  t.protein,  GOALS.protein,  false);
  setSidebarGoalBar("sgb-carbs",    t.carbs,    GOALS.carbs,    false);
  setSidebarGoalBar("sgb-fat",      t.fat,      GOALS.fat,      true);
  setSidebarGoalBar("sgb-fiber",    t.fiber,    GOALS.fiber,    false);
  setSidebarGoalBar("sgb-sugar",    t.sugar,    GOALS.sugar,    true);
  setSidebarGoalBar("sgb-sodium",   t.sodium,   GOALS.sodium,   true);

  // ── Vitamin bars ──
  setVitBar("s-bar-vitA",    "s-vitA",    t.vitA);
  setVitBar("s-bar-vitC",    "s-vitC",    t.vitC);
  setVitBar("s-bar-calcium", "s-calcium", t.calcium);
  setVitBar("s-bar-iron",    "s-iron",    t.iron);

  // ── Daily status panel ──
  const status = overallStatus(t, entries);
  const badge  = document.getElementById("dsp-badge");
  const sub    = document.getElementById("dsp-sub");
  badge.textContent = status.label;
  badge.className   = `dsp-badge ${status.cls}`;
  sub.textContent   = status.sub;

  const recsEl = document.getElementById("dsp-recs");
  const recs   = buildRecs(t, entries);
  if (recs.length === 0) {
    recsEl.innerHTML = "";
  } else {
    recsEl.innerHTML = recs.map((r) => `
      <div class="rec-card">
        <span class="rec-icon">${r.icon}</span>
        <span class="rec-text">${r.text}</span>
      </div>
    `).join("");
  }

  // ── Food log ──
  const log = document.getElementById("food-log-full");

  if (entries.length === 0) {
    log.innerHTML = '<p class="empty-log">No meals logged yet. Go back to the analyzer to add meals.</p>';
    return;
  }

  log.innerHTML = "";

  for (const entry of entries) {
    const article = document.createElement("article");
    article.className = "entry-card";

    const thumbHtml = entry.thumb
      ? `<img class="entry-thumb" src="${entry.thumb}" alt="${entry.title}">`
      : `<div class="entry-thumb-placeholder">&#127869;</div>`;

    article.innerHTML = `
      <div class="entry-card-top">
        ${thumbHtml}
        <div class="entry-card-title-row">
          <strong class="entry-card-title">${entry.title}</strong>
          <button class="remove-btn" data-id="${entry.id}" aria-label="Remove">&#10005; Remove</button>
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
        <div class="vitamin-item">
          <span class="vitamin-label">Vitamin A</span>
          <div class="vitamin-bar-wrap"><div class="vitamin-bar" style="width:${clamp(entry.vitaminA)}%"></div></div>
          <span class="vitamin-pct">${entry.vitaminA || 0}%</span>
        </div>
        <div class="vitamin-item">
          <span class="vitamin-label">Vitamin C</span>
          <div class="vitamin-bar-wrap"><div class="vitamin-bar" style="width:${clamp(entry.vitaminC)}%"></div></div>
          <span class="vitamin-pct">${entry.vitaminC || 0}%</span>
        </div>
        <div class="vitamin-item">
          <span class="vitamin-label">Calcium</span>
          <div class="vitamin-bar-wrap"><div class="vitamin-bar" style="width:${clamp(entry.calcium)}%"></div></div>
          <span class="vitamin-pct">${entry.calcium || 0}%</span>
        </div>
        <div class="vitamin-item">
          <span class="vitamin-label">Iron</span>
          <div class="vitamin-bar-wrap"><div class="vitamin-bar" style="width:${clamp(entry.iron)}%"></div></div>
          <span class="vitamin-pct">${entry.iron || 0}%</span>
        </div>
      </div>
    `;

    log.appendChild(article);
  }

  log.querySelectorAll(".remove-btn").forEach((btn) => {
    btn.addEventListener("click", () => removeDayEntry(btn.dataset.id));
  });
}

// ─── Init ─────────────────────────────────────────────────────────────────────

const dateEl = document.getElementById("sidebar-date");
if (dateEl) {
  dateEl.textContent = new Date().toLocaleDateString("en-US", {
    weekday: "long", month: "long", day: "numeric",
  });
}

document.getElementById("clear-day-btn").addEventListener("click", () => {
  if (confirm("Clear all meals for today?")) {
    localStorage.removeItem(todayKey());
    render();
  }
});

render();
