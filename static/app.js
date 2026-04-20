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
