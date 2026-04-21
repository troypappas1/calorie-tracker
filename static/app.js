const photoInput      = document.getElementById("photo-input");
const previewShell    = document.getElementById("preview-shell");
const previewImage    = document.getElementById("preview-image");
const analyzeButton   = document.getElementById("analyze-button");
const clearButton     = document.getElementById("clear-button");
const statusText      = document.getElementById("status-text");
const dishTitle       = document.getElementById("dish-title");
const providerPill    = document.getElementById("provider-pill");
const caloriesValue   = document.getElementById("calories-value");
const proteinValue    = document.getElementById("protein-value");
const fatValue        = document.getElementById("fat-value");
const carbsValue      = document.getElementById("carbs-value");
const fiberValue      = document.getElementById("fiber-value");
const sugarValue      = document.getElementById("sugar-value");
const sodiumValue     = document.getElementById("sodium-value");
const confidenceValue = document.getElementById("confidence-value");
const confidenceFill  = document.getElementById("confidence-fill");
const confidenceMeter = document.getElementById("confidence-meter");
const notesList       = document.getElementById("notes-list");
const addToDayRow     = document.getElementById("add-to-day-row");
const addToDayButton  = document.getElementById("add-to-day-button");
const notesInput      = document.getElementById("notes-input");
const servingSizeRow  = document.getElementById("serving-size-row");
const sizeRow         = document.getElementById("size-row");
const weightValue     = document.getElementById("weight-value");
const sizeDesc        = document.getElementById("size-desc");

let imageDataUrl    = "";
let currentResult   = null;
let currentMultiplier = 1;

// ─── Button state ─────────────────────────────────────────────────────────────

function syncButtons() {
  const ready = !!imageDataUrl || notesInput.value.trim().length > 0;
  analyzeButton.disabled = !ready;
  clearButton.disabled   = !ready;
}

notesInput.addEventListener("input", syncButtons);

// ─── Photo input ──────────────────────────────────────────────────────────────

photoInput.addEventListener("change", async (event) => {
  const file = event.target.files?.[0];
  if (!file) return;
  if (!file.type.startsWith("image/")) { setStatus("Please choose an image file."); return; }
  if (file.size > 20 * 1024 * 1024) { setStatus("Image is too large. Please choose a file under 20 MB."); return; }
  imageDataUrl = await fileToDataUrl(file);
  previewImage.src = imageDataUrl;
  previewShell.hidden = false;
  syncButtons();
  setStatus("Photo ready — analyze when you're ready.");
  resetResult();
});

// ─── Analyze ──────────────────────────────────────────────────────────────────

analyzeButton.addEventListener("click", async () => {
  analyzeButton.disabled = true;
  clearButton.disabled   = true;
  setStatus("Analyzing...");
  providerPill.textContent = "Working";

  try {
    const description = notesInput.value.trim();
    let response;

    if (imageDataUrl) {
      // Photo is primary; notes assist identification
      response = await fetch("/api/analyze", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ imageDataUrl, description }),
      });
    } else {
      // Text-only fallback
      if (!description) { setStatus("Upload a photo or add a description first."); return; }
      response = await fetch("/api/analyze-text", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ description }),
      });
    }

    const payload = await response.json();
    if (!response.ok) throw new Error(payload.detail || "Analysis failed.");
    currentResult = payload;
    renderResult(payload);
    setStatus("Estimate ready.");
  } catch (error) {
    setStatus(error.message || "Something went wrong.");
    providerPill.textContent = "Error";
  } finally {
    syncButtons();
  }
});

// ─── Clear ────────────────────────────────────────────────────────────────────

clearButton.addEventListener("click", () => {
  imageDataUrl = "";
  photoInput.value = "";
  notesInput.value = "";
  previewImage.removeAttribute("src");
  previewShell.hidden = true;
  syncButtons();
  resetResult();
  setStatus("Upload a photo to begin.");
});

// ─── Serving size ─────────────────────────────────────────────────────────────

document.querySelectorAll(".serving-btn").forEach((btn) => {
  btn.addEventListener("click", () => {
    document.querySelectorAll(".serving-btn").forEach((b) => b.classList.remove("active"));
    btn.classList.add("active");
    currentMultiplier = parseFloat(btn.dataset.mult);
    if (currentResult) renderScaled(currentResult, currentMultiplier);
  });
});

function scale(val, mult) {
  return Math.round((val || 0) * mult);
}

function renderScaled(result, mult) {
  dishTitle.textContent = mult === 1 ? result.title : `${result.title} (${mult}×)`;

  caloriesValue.textContent = String(scale(result.calories, mult));
  proteinValue.textContent  = `${scale(result.proteinGrams, mult)}g`;
  fatValue.textContent      = `${scale(result.fatGrams, mult)}g`;
  carbsValue.textContent    = `${scale(result.carbsGrams, mult)}g`;
  fiberValue.textContent    = `${scale(result.fiberGrams, mult)}g`;
  sugarValue.textContent    = `${scale(result.sugarGrams, mult)}g`;
  sodiumValue.textContent   = `${scale(result.sodiumMg, mult)}mg`;

  setVitaminBar("bar-vitA",    "vitA-value",    scale(result.vitaminA, mult));
  setVitaminBar("bar-vitC",    "vitC-value",    scale(result.vitaminC, mult));
  setVitaminBar("bar-calcium", "calcium-value", scale(result.calcium, mult));
  setVitaminBar("bar-iron",    "iron-value",    scale(result.iron, mult));

  if (result.weightGrams != null) {
    weightValue.textContent = `${scale(result.weightGrams, mult)}g`;
    sizeDesc.textContent = mult === 1
      ? (result.sizeDescription || "--")
      : `${result.sizeDescription || "--"} ×${mult}`;
    sizeRow.hidden = false;
  }
}

// ─── Add to My Day ────────────────────────────────────────────────────────────

addToDayButton.addEventListener("click", async () => {
  if (!currentResult) return;
  const thumb = imageDataUrl ? await createThumbnail(imageDataUrl) : null;
  const m     = currentMultiplier;
  const label = m === 1 ? currentResult.title : `${currentResult.title} (${m}×)`;
  addDayEntry({
    id:           Date.now().toString(),
    title:        label,
    mealType:     currentResult.mealType || (scale(currentResult.calories, m) < 250 ? 'snack' : 'meal'),
    calories:     scale(currentResult.calories,     m),
    proteinGrams: scale(currentResult.proteinGrams, m),
    fatGrams:     scale(currentResult.fatGrams,     m),
    carbsGrams:   scale(currentResult.carbsGrams,   m),
    fiberGrams:   scale(currentResult.fiberGrams,   m),
    sugarGrams:   scale(currentResult.sugarGrams,   m),
    sodiumMg:     scale(currentResult.sodiumMg,     m),
    vitaminA:     scale(currentResult.vitaminA,     m),
    vitaminC:     scale(currentResult.vitaminC,     m),
    calcium:      scale(currentResult.calcium,      m),
    iron:         scale(currentResult.iron,         m),
    thumb,
  });
  addToDayButton.textContent = "Added!";
  addToDayButton.disabled    = true;
});

// ─── Helpers ──────────────────────────────────────────────────────────────────

function fileToDataUrl(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload  = () => resolve(reader.result);
    reader.onerror = () => reject(new Error("Could not read that file."));
    reader.readAsDataURL(file);
  });
}

function createThumbnail(dataUrl) {
  return new Promise((resolve) => {
    const img = new Image();
    img.onload = () => {
      const canvas = document.createElement("canvas");
      const maxSize = 80;
      const ratio   = Math.min(maxSize / img.width, maxSize / img.height);
      canvas.width  = Math.round(img.width  * ratio);
      canvas.height = Math.round(img.height * ratio);
      canvas.getContext("2d").drawImage(img, 0, 0, canvas.width, canvas.height);
      resolve(canvas.toDataURL("image/jpeg", 0.7));
    };
    img.onerror = () => resolve(null);
    img.src = dataUrl;
  });
}

function todayKey() {
  const d = new Date().toLocaleDateString('en-CA', { timeZone: 'America/Los_Angeles' });
  return `ct_log_${d}`;
}

function getDayEntries() {
  try { return JSON.parse(localStorage.getItem(todayKey()) || "[]"); }
  catch { return []; }
}

function saveDayEntries(entries) {
  try { localStorage.setItem(todayKey(), JSON.stringify(entries)); }
  catch { alert("Could not save — local storage may be full."); }
}

function addDayEntry(entry) {
  const entries = getDayEntries();
  entries.push(entry);
  saveDayEntries(entries);
}

function setVitaminBar(barId, valueId, pct) {
  const bar = document.getElementById(barId);
  const val = document.getElementById(valueId);
  if (bar) bar.style.width = `${Math.min(pct || 0, 100)}%`;
  if (val) val.textContent = pct != null ? `${pct}%` : "--";
}

function renderResult(result) {
  currentMultiplier = 1;
  document.querySelectorAll(".serving-btn").forEach((b) => {
    b.classList.toggle("active", b.dataset.mult === "1");
  });

  renderScaled(result, 1);

  setConfidence(result.confidence);
  providerPill.textContent = { anthropic: "Claude", mock: "Mock" }[result.source] || result.source;

  notesList.innerHTML = "";
  for (const note of result.notes || []) {
    const li = document.createElement("li");
    li.textContent = note;
    notesList.appendChild(li);
  }

  servingSizeRow.hidden = false;
  addToDayRow.hidden    = false;
  addToDayButton.textContent = "+ Add to My Day";
  addToDayButton.disabled    = false;
}

function resetResult() {
  dishTitle.textContent     = "No result yet";
  providerPill.textContent  = "Waiting";
  caloriesValue.textContent = "--";
  proteinValue.textContent  = "--";
  fatValue.textContent      = "--";
  carbsValue.textContent    = "--";
  fiberValue.textContent    = "--";
  sugarValue.textContent    = "--";
  sodiumValue.textContent   = "--";

  setVitaminBar("bar-vitA",    "vitA-value",    null);
  setVitaminBar("bar-vitC",    "vitC-value",    null);
  setVitaminBar("bar-calcium", "calcium-value", null);
  setVitaminBar("bar-iron",    "iron-value",    null);

  setConfidence(null);
  notesList.innerHTML = "<li>Results will appear here after analysis.</li>";
  sizeRow.hidden       = true;
  servingSizeRow.hidden = true;
  addToDayRow.hidden   = true;
  currentMultiplier    = 1;
  currentResult        = null;
}

function setStatus(msg) { statusText.textContent = msg; }

// ─── Beverage analyzer ────────────────────────────────────────────────────────

const bevPhotoInput    = document.getElementById('bev-photo-input');
const bevPreviewShell  = document.getElementById('bev-preview-shell');
const bevPreviewImage  = document.getElementById('bev-preview-image');
const bevAnalyzeBtn    = document.getElementById('bev-analyze-button');
const bevClearBtn      = document.getElementById('bev-clear-button');
const bevNotesInput    = document.getElementById('bev-notes-input');
const bevStatusText    = document.getElementById('bev-status-text');
const bevResultPanel   = document.getElementById('bev-result-panel');
const bevAddToDayRow   = document.getElementById('bev-add-to-day-row');
const bevAddToDayBtn   = document.getElementById('bev-add-to-day-button');

let bevImageDataUrl  = '';
let bevCurrentResult = null;

function syncBevButtons() {
  const ready = !!bevImageDataUrl;
  bevAnalyzeBtn.disabled = !ready;
  bevClearBtn.disabled   = !ready;
}

bevPhotoInput.addEventListener('change', async (e) => {
  const file = e.target.files?.[0];
  if (!file) return;
  if (!file.type.startsWith('image/')) { bevStatusText.textContent = 'Please choose an image file.'; return; }
  if (file.size > 20 * 1024 * 1024) { bevStatusText.textContent = 'Image too large — keep it under 20 MB.'; return; }
  bevImageDataUrl = await fileToDataUrl(file);
  bevPreviewImage.src = bevImageDataUrl;
  bevPreviewShell.hidden = false;
  syncBevButtons();
  bevStatusText.textContent = 'Photo ready — name the beverage below, then click Analyze Drink.';
  bevCurrentResult = null;
  bevResultPanel.hidden = true;
  bevAddToDayRow.hidden = true;
});

bevAnalyzeBtn.addEventListener('click', async () => {
  const desc = bevNotesInput.value.trim();
  if (!desc) {
    bevStatusText.textContent = '⚠️ Please enter the beverage name before analyzing.';
    bevNotesInput.focus();
    bevNotesInput.style.borderColor = 'var(--red)';
    bevNotesInput.addEventListener('input', () => { bevNotesInput.style.borderColor = ''; }, { once: true });
    return;
  }
  bevAnalyzeBtn.disabled = true;
  bevClearBtn.disabled   = true;
  bevStatusText.textContent = 'Analyzing drink…';

  try {
    const res = await fetch('/api/analyze-beverage', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ imageDataUrl: bevImageDataUrl, description: desc }),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.detail || 'Analysis failed.');
    bevCurrentResult = data;
    renderBevResult(data);
    bevStatusText.textContent = 'Drink estimate ready.';
  } catch (err) {
    bevStatusText.textContent = err.message || 'Something went wrong.';
  } finally {
    syncBevButtons();
  }
});

bevClearBtn.addEventListener('click', () => {
  bevImageDataUrl = '';
  bevPhotoInput.value = '';
  bevNotesInput.value = '';
  bevPreviewImage.removeAttribute('src');
  bevPreviewShell.hidden = true;
  bevResultPanel.hidden = true;
  bevAddToDayRow.hidden = true;
  bevCurrentResult = null;
  syncBevButtons();
  bevStatusText.textContent = 'Upload a drink photo to begin.';
});

function renderBevResult(result) {
  document.getElementById('bev-dish-title').textContent = result.title || 'Unknown drink';
  document.getElementById('bev-provider-pill').textContent = { anthropic: 'Claude', mock: 'Mock' }[result.source] || result.source;
  document.getElementById('bev-calories-value').textContent = String(result.calories || 0);
  document.getElementById('bev-sugar-value').textContent    = `${result.sugarGrams || 0}g`;
  document.getElementById('bev-carbs-value').textContent    = `${result.carbsGrams || 0}g`;
  document.getElementById('bev-protein-value').textContent  = `${result.proteinGrams || 0}g`;
  document.getElementById('bev-fat-value').textContent      = `${result.fatGrams || 0}g`;
  document.getElementById('bev-sodium-value').textContent   = `${result.sodiumMg || 0}mg`;

  if (result.weightGrams != null) {
    document.getElementById('bev-weight-value').textContent = `${result.weightGrams}ml`;
    document.getElementById('bev-size-desc').textContent    = result.sizeDescription || '--';
    document.getElementById('bev-size-row').hidden = false;
  } else {
    document.getElementById('bev-size-row').hidden = true;
  }

  const notesList = document.getElementById('bev-notes-list');
  notesList.innerHTML = '';
  for (const note of result.notes || []) {
    const li = document.createElement('li');
    li.textContent = note;
    notesList.appendChild(li);
  }

  bevResultPanel.hidden  = false;
  bevAddToDayRow.hidden  = false;
  bevAddToDayBtn.textContent = '+ Add to My Day';
  bevAddToDayBtn.disabled    = false;
}

bevAddToDayBtn.addEventListener('click', async () => {
  if (!bevCurrentResult) return;
  const thumb = bevImageDataUrl ? await createThumbnail(bevImageDataUrl) : null;
  const title = bevCurrentResult.title || bevNotesInput.value.trim() || 'Drink';
  addDayEntry({
    id:           Date.now().toString(),
    title,
    mealType:     'snack',
    calories:     bevCurrentResult.calories     || 0,
    proteinGrams: bevCurrentResult.proteinGrams || 0,
    fatGrams:     bevCurrentResult.fatGrams     || 0,
    carbsGrams:   bevCurrentResult.carbsGrams   || 0,
    fiberGrams:   bevCurrentResult.fiberGrams   || 0,
    sugarGrams:   bevCurrentResult.sugarGrams   || 0,
    sodiumMg:     bevCurrentResult.sodiumMg     || 0,
    vitaminA:     bevCurrentResult.vitaminA     || 0,
    vitaminC:     bevCurrentResult.vitaminC     || 0,
    calcium:      bevCurrentResult.calcium      || 0,
    iron:         bevCurrentResult.iron         || 0,
    thumb,
  });

  // Sync hydration: convert ml (weightGrams) to glasses (240ml each), minimum 1
  const ml = bevCurrentResult.weightGrams || 0;
  if (ml > 0) {
    const todayStr = new Date().toLocaleDateString('en-CA', { timeZone: 'America/Los_Angeles' });
    const waterKey = `ct_water_${todayStr}`;
    const current  = parseInt(localStorage.getItem(waterKey) || '0', 10);
    const glasses  = Math.max(1, Math.round(ml / 240));
    localStorage.setItem(waterKey, Math.min(8, current + glasses).toString());
  }

  bevAddToDayBtn.textContent = 'Added!';
  bevAddToDayBtn.disabled    = true;
});

function setConfidence(level) {
  const levels = { Low: { pct: 22, cls: "cm-low" }, Medium: { pct: 57, cls: "cm-mid" }, High: { pct: 92, cls: "cm-high" } };
  const cfg = levels[level];
  if (!cfg) {
    confidenceValue.textContent = "--";
    confidenceFill.style.width  = "0%";
    confidenceFill.className    = "cm-fill";
    confidenceMeter.dataset.level = "";
    return;
  }
  confidenceValue.textContent   = level;
  confidenceFill.style.width    = `${cfg.pct}%`;
  confidenceFill.className      = `cm-fill ${cfg.cls}`;
  confidenceMeter.dataset.level = level.toLowerCase();
}
