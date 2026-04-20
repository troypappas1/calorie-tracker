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

function clamp(val) { return Math.min(val || 0, 100); }

function setBar(barId, labelId, val) {
  const bar = document.getElementById(barId);
  const label = document.getElementById(labelId);
  if (bar) bar.style.width = `${clamp(val)}%`;
  if (label) label.textContent = `${val || 0}%`;
}

function render() {
  const entries = getDayEntries();

  const t = entries.reduce(
    (acc, e) => {
      acc.calories += e.calories || 0;
      acc.protein  += e.proteinGrams || 0;
      acc.fat      += e.fatGrams || 0;
      acc.carbs    += e.carbsGrams || 0;
      acc.fiber    += e.fiberGrams || 0;
      acc.sugar    += e.sugarGrams || 0;
      acc.sodium   += e.sodiumMg || 0;
      acc.vitA     += e.vitaminA || 0;
      acc.vitC     += e.vitaminC || 0;
      acc.calcium  += e.calcium || 0;
      acc.iron     += e.iron || 0;
      return acc;
    },
    { calories: 0, protein: 0, fat: 0, carbs: 0, fiber: 0, sugar: 0, sodium: 0, vitA: 0, vitC: 0, calcium: 0, iron: 0 }
  );

  document.getElementById("s-calories").textContent = t.calories;
  document.getElementById("s-protein").textContent  = `${t.protein}g`;
  document.getElementById("s-fat").textContent      = `${t.fat}g`;
  document.getElementById("s-carbs").textContent    = `${t.carbs}g`;
  document.getElementById("s-fiber").textContent    = `${t.fiber}g`;
  document.getElementById("s-sugar").textContent    = `${t.sugar}g`;
  document.getElementById("s-sodium").textContent   = `${t.sodium}mg`;

  setBar("s-bar-vitA",    "s-vitA",    t.vitA);
  setBar("s-bar-vitC",    "s-vitC",    t.vitC);
  setBar("s-bar-calcium", "s-calcium", t.calcium);
  setBar("s-bar-iron",    "s-iron",    t.iron);

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
