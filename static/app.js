const photoInput = document.getElementById("photo-input");
const previewShell = document.getElementById("preview-shell");
const previewImage = document.getElementById("preview-image");
const analyzeButton = document.getElementById("analyze-button");
const clearButton = document.getElementById("clear-button");
const statusText = document.getElementById("status-text");
const dishTitle = document.getElementById("dish-title");
const providerPill = document.getElementById("provider-pill");
const caloriesValue = document.getElementById("calories-value");
const proteinValue = document.getElementById("protein-value");
const confidenceValue = document.getElementById("confidence-value");
const notesList = document.getElementById("notes-list");
const addToDayRow = document.getElementById("add-to-day-row");
const addToDayButton = document.getElementById("add-to-day-button");
const clearDayButton = document.getElementById("clear-day-button");
const totalCalories = document.getElementById("total-calories");
const totalProtein = document.getElementById("total-protein");
const foodLog = document.getElementById("food-log");

let imageDataUrl = "";
let currentResult = null;

// --- Tab switching ---
document.querySelectorAll(".tab").forEach((tab) => {
  tab.addEventListener("click", () => {
    document.querySelectorAll(".tab").forEach((t) => t.classList.remove("active"));
    tab.classList.add("active");
    const target = tab.dataset.tab;
    document.querySelectorAll(".tab-content").forEach((section) => {
      section.hidden = section.id !== `tab-${target}`;
    });
    if (target === "my-day") renderMyDay();
  });
});

// --- Photo input ---
photoInput.addEventListener("change", async (event) => {
  const file = event.target.files?.[0];
  if (!file) return;
  if (!file.type.startsWith("image/")) {
    setStatus("Please choose an image file.");
    return;
  }
  imageDataUrl = await fileToDataUrl(file);
  previewImage.src = imageDataUrl;
  previewShell.hidden = false;
  analyzeButton.disabled = false;
  clearButton.disabled = false;
  setStatus("Photo ready. Analyze whenever you're ready.");
  resetResult();
});

// --- Analyze button ---
analyzeButton.addEventListener("click", async () => {
  if (!imageDataUrl) {
    setStatus("Upload a photo first.");
    return;
  }
  analyzeButton.disabled = true;
  clearButton.disabled = true;
  setStatus("Analyzing your meal...");
  providerPill.textContent = "Working";

  try {
    const response = await fetch("/api/analyze", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ imageDataUrl }),
    });
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

// --- Clear button ---
clearButton.addEventListener("click", () => {
  imageDataUrl = "";
  currentResult = null;
  photoInput.value = "";
  previewImage.removeAttribute("src");
  previewShell.hidden = true;
  analyzeButton.disabled = true;
  clearButton.disabled = true;
  resetResult();
  setStatus("Upload a photo to begin.");
});

// --- Add to My Day ---
addToDayButton.addEventListener("click", async () => {
  if (!currentResult) return;
  const thumb = imageDataUrl ? await createThumbnail(imageDataUrl) : null;
  const entry = {
    id: Date.now().toString(),
    title: currentResult.title,
    calories: currentResult.calories,
    proteinGrams: currentResult.proteinGrams,
    thumb,
  };
  addDayEntry(entry);
  addToDayButton.textContent = "Added!";
  addToDayButton.disabled = true;
});

// --- Clear Day ---
clearDayButton.addEventListener("click", () => {
  if (confirm("Clear all meals for today?")) {
    localStorage.removeItem(todayKey());
    renderMyDay();
  }
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
      canvas.width = Math.round(img.width * ratio);
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
  try {
    return JSON.parse(localStorage.getItem(todayKey()) || "[]");
  } catch {
    return [];
  }
}

function saveDayEntries(entries) {
  try {
    localStorage.setItem(todayKey(), JSON.stringify(entries));
  } catch {
    alert("Could not save — local storage may be full.");
  }
}

function addDayEntry(entry) {
  const entries = getDayEntries();
  entries.push(entry);
  saveDayEntries(entries);
}

function removeDayEntry(id) {
  saveDayEntries(getDayEntries().filter((e) => e.id !== id));
  renderMyDay();
}

function renderMyDay() {
  const entries = getDayEntries();
  const totalCal = entries.reduce((sum, e) => sum + e.calories, 0);
  const totalProt = entries.reduce((sum, e) => sum + e.proteinGrams, 0);
  totalCalories.textContent = totalCal;
  totalProtein.textContent = `${totalProt}g`;

  if (entries.length === 0) {
    foodLog.innerHTML = '<p class="empty-log">No meals logged yet. Analyze a photo and tap "Add to My Day".</p>';
    return;
  }

  foodLog.innerHTML = "";
  for (const entry of entries) {
    const article = document.createElement("article");
    article.className = "food-entry";
    const thumbHtml = entry.thumb
      ? `<img class="food-thumb" src="${entry.thumb}" alt="${entry.title}">`
      : `<div class="food-thumb-placeholder">🍽</div>`;
    article.innerHTML = `
      ${thumbHtml}
      <div class="food-entry-info">
        <strong class="food-entry-title">${entry.title}</strong>
        <span class="food-entry-meta">${entry.calories} cal &middot; ${entry.proteinGrams}g protein</span>
      </div>
      <button class="remove-btn" data-id="${entry.id}" aria-label="Remove">✕</button>
    `;
    foodLog.appendChild(article);
  }

  foodLog.querySelectorAll(".remove-btn").forEach((btn) => {
    btn.addEventListener("click", () => removeDayEntry(btn.dataset.id));
  });
}

function renderResult(result) {
  dishTitle.textContent = result.title;
  caloriesValue.textContent = String(result.calories);
  proteinValue.textContent = `${result.proteinGrams}g`;
  confidenceValue.textContent = result.confidence;
  const pillLabels = { anthropic: "Claude", openai: "OpenAI", mock: "Mock" };
  providerPill.textContent = pillLabels[result.source] || result.source;
  notesList.innerHTML = "";
  for (const note of result.notes) {
    const item = document.createElement("li");
    item.textContent = note;
    notesList.appendChild(item);
  }
  addToDayRow.hidden = false;
  addToDayButton.textContent = "+ Add to My Day";
  addToDayButton.disabled = false;
}

function resetResult() {
  dishTitle.textContent = "No result yet";
  providerPill.textContent = "Waiting";
  caloriesValue.textContent = "--";
  proteinValue.textContent = "--";
  confidenceValue.textContent = "--";
  notesList.innerHTML = "<li>Results will appear here after analysis.</li>";
  addToDayRow.hidden = true;
  currentResult = null;
}

function setStatus(message) {
  statusText.textContent = message;
}
