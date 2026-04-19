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

let imageDataUrl = "";

photoInput.addEventListener("change", async (event) => {
  const file = event.target.files?.[0];
  if (!file) {
    return;
  }

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
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ imageDataUrl }),
    });

    const payload = await response.json();
    if (!response.ok) {
      throw new Error(payload.error || "Analysis failed.");
    }

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

clearButton.addEventListener("click", () => {
  imageDataUrl = "";
  photoInput.value = "";
  previewImage.removeAttribute("src");
  previewShell.hidden = true;
  analyzeButton.disabled = true;
  clearButton.disabled = true;
  resetResult();
  setStatus("Upload a photo to begin.");
});

function fileToDataUrl(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result);
    reader.onerror = () => reject(new Error("Could not read that file."));
    reader.readAsDataURL(file);
  });
}

function renderResult(result) {
  dishTitle.textContent = result.title;
  caloriesValue.textContent = String(result.calories);
  proteinValue.textContent = `${result.proteinGrams}g`;
  confidenceValue.textContent = result.confidence;
  providerPill.textContent = result.source === "openai" ? "OpenAI" : "Mock";
  notesList.innerHTML = "";

  for (const note of result.notes) {
    const item = document.createElement("li");
    item.textContent = note;
    notesList.appendChild(item);
  }
}

function resetResult() {
  dishTitle.textContent = "No result yet";
  providerPill.textContent = "Waiting";
  caloriesValue.textContent = "--";
  proteinValue.textContent = "--";
  confidenceValue.textContent = "--";
  notesList.innerHTML = "<li>Results will appear here after analysis.</li>";
}

function setStatus(message) {
  statusText.textContent = message;
}
