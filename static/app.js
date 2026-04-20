const photoInput     = document.getElementById("photo-input");
const previewShell   = document.getElementById("preview-shell");
const previewImage   = document.getElementById("preview-image");
const analyzeButton  = document.getElementById("analyze-button");
const clearButton    = document.getElementById("clear-button");
const statusText     = document.getElementById("status-text");
const dishTitle      = document.getElementById("dish-title");
const providerPill   = document.getElementById("provider-pill");
const caloriesValue  = document.getElementById("calories-value");
const proteinValue   = document.getElementById("protein-value");
const fatValue       = document.getElementById("fat-value");
const carbsValue     = document.getElementById("carbs-value");
const fiberValue     = document.getElementById("fiber-value");
const sugarValue     = document.getElementById("sugar-value");
const sodiumValue    = document.getElementById("sodium-value");
const confidenceValue = document.getElementById("confidence-value");
const notesList      = document.getElementById("notes-list");
const addToDayRow    = document.getElementById("add-to-day-row");
const addToDayButton = document.getElementById("add-to-day-button");
const notesInput     = document.getElementById("notes-input");

let imageDataUrl = "";
let currentResult = null;
let currentSubTab = "photo";

// --- Sub-tab switching ---
document.querySelectorAll(".sub-tab").forEach((tab) => {
  tab.addEventListener("click", () => {
    document.querySelectorAll(".sub-tab").forEach((t) => t.classList.remove("active"));
    tab.classList.add("active");
    currentSubTab = tab.dataset.sub;
    document.querySelectorAll(".sub-tab-content").forEach((s) => {
      s.hidden = s.id !== `sub-${currentSubTab}`;
    });
    syncButtons();
    resetResult();
    setStatus(currentSubTab === "photo"
      ? "Upload a photo to begin."
      : "Describe your meal to begin.");
  });
});

function syncButtons() {
  const ready = currentSubTab === "photo"
    ? !!imageDataUrl
    : notesInput.value.trim().length > 0;
  analyzeButton.disabled = !ready;
  clearButton.disabled = !ready;
}

notesInput.addEventListener("input", syncButtons);

// --- Photo input ---
photoInput.addEventListener("change", async (event) => {
  const file = event.target.files?.[0];
  if (!file) return;
  if (!file.type.startsWith("image/")) { setStatus("Please choose an image file."); return; }
  imageDataUrl = await fileToDataUrl(file);
  previewImage.src = imageDataUrl;
  previewShell.hidden = false;
  syncButtons();
  setStatus("Photo ready. Analyze whenever you're ready.");
  resetResult();
});

// --- Analyze ---
analyzeButton.addEventListener("click", async () => {
  analyzeButton.disabled = true;
  clearButton.disabled = true;
  setStatus("Analyzing your meal...");
  providerPill.textContent = "Working";

  try {
    let response;
    if (currentSubTab === "photo") {
      if (!imageDataUrl) { setStatus("Upload a photo first."); return; }
      response = await fetch("/api/analyze", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ imageDataUrl }),
      });
    } else {
      const description = notesInput.value.trim();
      if (!description) { setStatus("Describe your meal first."); return; }
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
    analyzeButton.disabled = false;
    clearButton.disabled = false;
  }
});

// --- Clear ---
clearButton.addEventListener("click", () => {
  imageDataUrl = "";
  currentResult = null;
  photoInput.value = "";
  notesInput.value = "";
  previewImage.removeAttribute("src");
  previewShell.hidden = true;
  syncButtons();
  resetResult();
  setStatus(currentSubTab === "photo" ? "Upload a photo to begin." : "Describe your meal to begin.");
});

// --- Add to My Day ---
addToDayButton.addEventListener("click", async () => {
  if (!currentResult) return;
  const thumb = (currentSubTab === "photo" && imageDataUrl) ? await createThumbnail(imageDataUrl) : null;
  addDayEntry({
    id: Date.now().toString(),
    title:       currentResult.title,
    calories:    currentResult.calories    || 0,
    proteinGrams: currentResult.proteinGrams || 0,
    fatGrams:    currentResult.fatGrams    || 0,
    carbsGrams:  currentResult.carbsGrams  || 0,
    fiberGrams:  currentResult.fiberGrams  || 0,
    sugarGrams:  currentResult.sugarGrams  || 0,
    sodiumMg:    currentResult.sodiumMg    || 0,
    vitaminA:    currentResult.vitaminA    || 0,
    vitaminC:    currentResult.vitaminC    || 0,
    calcium:     currentResult.calcium     || 0,
    iron:        currentResult.iron        || 0,
    thumb,
  });
  addToDayButton.textContent = "Added!";
  addToDayButton.disabled = true;
});

// --- Helpers ---
function fileToDataUrl(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result);
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
      const ratio = Math.min(maxSize / img.width, maxSize / img.height);
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
  dishTitle.textContent     = result.title;
  caloriesValue.textContent = String(result.calories ?? "--");
  proteinValue.textContent  = result.proteinGrams != null ? `${result.proteinGrams}g` : "--";
  fatValue.textContent      = result.fatGrams      != null ? `${result.fatGrams}g`    : "--";
  carbsValue.textContent    = result.carbsGrams    != null ? `${result.carbsGrams}g`  : "--";
  fiberValue.textContent    = result.fiberGrams    != null ? `${result.fiberGrams}g`  : "--";
  sugarValue.textContent    = result.sugarGrams    != null ? `${result.sugarGrams}g`  : "--";
  sodiumValue.textContent   = result.sodiumMg      != null ? `${result.sodiumMg}mg`   : "--";

  setVitaminBar("bar-vitA",    "vitA-value",    result.vitaminA);
  setVitaminBar("bar-vitC",    "vitC-value",    result.vitaminC);
  setVitaminBar("bar-calcium", "calcium-value", result.calcium);
  setVitaminBar("bar-iron",    "iron-value",    result.iron);

  confidenceValue.textContent = result.confidence;
  const pillLabels = { anthropic: "Claude", mock: "Mock" };
  providerPill.textContent = pillLabels[result.source] || result.source;

  notesList.innerHTML = "";
  for (const note of result.notes) {
    const li = document.createElement("li");
    li.textContent = note;
    notesList.appendChild(li);
  }

  addToDayRow.hidden = false;
  addToDayButton.textContent = "+ Add to My Day";
  addToDayButton.disabled = false;
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

  confidenceValue.textContent = "--";
  notesList.innerHTML = "<li>Results will appear here after analysis.</li>";
  addToDayRow.hidden = true;
  currentResult = null;
}

function setStatus(msg) { statusText.textContent = msg; }
