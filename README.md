# Calorie Tracker Web

Public-ready web app that lets users upload a food photo and estimate:

- Calories
- Protein (grams)

It now uses a FastAPI backend so you can run it locally on Windows or deploy it for everyone to use.

## What is included

- `main.py` - FastAPI backend with `/api/health` and `/api/analyze`
- `app.py` - local launcher for `uvicorn`
- `static/` - browser UI for uploading and previewing a food photo
- `requirements.txt` - Python dependencies
- `render.yaml` - Render deployment config
- `Procfile` - optional process declaration for hosts that support it
- `CalorieTracker/` - the earlier iOS prototype, kept for reference

## Run locally on Windows

1. Open PowerShell in this folder.
2. Create a virtual environment.
3. Install dependencies.
4. Start the app.
5. Open the local URL in your browser.

```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python app.py
```

Then open `http://127.0.0.1:8000`.

### Use OpenAI locally

Set your key in the current PowerShell window before starting the app:

```powershell
$env:OPENAI_API_KEY="your_key_here"
python app.py
```

## Deploy publicly on Render

1. Push this folder to a GitHub repo.
2. Create a new `Web Service` in Render and connect the repo.
3. Render should detect `render.yaml` automatically.
4. Add the `OPENAI_API_KEY` environment variable in Render.
5. Deploy.

Render will use:

- Build command: `pip install -r requirements.txt`
- Start command: `uvicorn main:app --host 0.0.0.0 --port $PORT`

## API shape

### `GET /api/health`

Returns whether the service is up and whether it is using `mock` or `openai`.

### `POST /api/analyze`

Request body:

```json
{
  "imageDataUrl": "data:image/jpeg;base64,..."
}
```

Response body:

```json
{
  "title": "Chicken rice bowl",
  "calories": 640,
  "proteinGrams": 38,
  "confidence": "Medium",
  "notes": [
    "Estimate assumes a single serving."
  ],
  "source": "openai"
}
```

## How it works

1. The browser converts the uploaded image into a data URL.
2. The frontend posts that image to `/api/analyze`.
3. The backend validates the upload and either:
   - returns a mock estimate, or
   - calls the OpenAI Responses API with image input and strict JSON output

## Notes

- Nutrition from a photo is always an estimate.
- The OpenAI API key stays on the server, not in browser JavaScript.
- Uploaded images are processed in memory and are not saved to disk by this app.
- Before opening this to the public, you should strongly consider rate limiting, auth, and usage monitoring.
