import base64
import json
import os
import urllib.error
import urllib.request
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel


ROOT = Path(__file__).parent
STATIC_DIR = ROOT / "static"
MAX_IMAGE_BYTES = 8 * 1024 * 1024

NUTRITION_SCHEMA = (
    '{"title": "dish name", "mealType": "meal", "weightGrams": 350, "sizeDescription": "about the size of a tennis ball", '
    '"calories": 550, "proteinGrams": 25, "fatGrams": 18, '
    '"carbsGrams": 60, "fiberGrams": 5, "sugarGrams": 8, "sodiumMg": 450, '
    '"vitaminA": 15, "vitaminC": 20, "calcium": 10, "iron": 8, '
    '"confidence": "High", "notes": ["short helpful note"]}'
)
NUTRITION_NOTES = (
    "weightGrams is your best estimate of the total weight of the food in grams. "
    "sizeDescription is a short everyday comparison like 'about the size of a tennis ball', "
    "'roughly two fists', 'a standard dinner plate portion', etc. "
    "mealType must be exactly 'meal' or 'snack': use 'snack' for items under ~250 calories or "
    "clearly snack-like foods (fruit, chips, yogurt, coffee, drink, candy, small bar), "
    "use 'meal' for everything else. "
    "vitaminA, vitaminC, calcium, iron are % Daily Value as integers. "
    "confidence must be Low, Medium, or High. "
    "notes should have 1-2 short observations about the estimate."
)


class AnalyzeRequest(BaseModel):
    imageDataUrl: str
    description: str = ""  # optional brand / quality notes to assist photo


class AnalyzeTextRequest(BaseModel):
    description: str


def mock_estimate() -> dict:
    return {
        "title": "Chicken rice bowl",
        "weightGrams": 420,
        "sizeDescription": "about the size of a large fist",
        "calories": 640,
        "proteinGrams": 38,
        "fatGrams": 14,
        "carbsGrams": 72,
        "fiberGrams": 4,
        "sugarGrams": 3,
        "sodiumMg": 620,
        "vitaminA": 8,
        "vitaminC": 12,
        "calcium": 6,
        "iron": 15,
        "confidence": "Medium",
        "notes": [
            "Mock result — set ANTHROPIC_API_KEY in Vercel environment variables to enable real analysis.",
            "Serving size and sauces can change the estimate significantly.",
        ],
        "source": "mock",
    }


def validate_image_data_url(image_data_url: str) -> None:
    if not image_data_url.startswith("data:image/"):
        raise HTTPException(status_code=400, detail="Upload a valid image before analyzing.")
    try:
        encoded = image_data_url.split(",", 1)[1]
        raw = base64.b64decode(encoded, validate=True)
    except (IndexError, ValueError, base64.binascii.Error) as exc:
        raise HTTPException(status_code=400, detail="Could not read the uploaded image.") from exc
    if len(raw) > MAX_IMAGE_BYTES:
        raise HTTPException(status_code=400, detail="Image is too large. Keep uploads under 8 MB.")


def extract_json(text: str) -> dict:
    text = text.strip()
    if text.startswith("```"):
        lines = text.split("\n")
        inner = lines[1:]
        if inner and inner[-1].strip() == "```":
            inner = inner[:-1]
        text = "\n".join(inner).strip()
    start = text.find("{")
    end = text.rfind("}") + 1
    if start == -1 or end == 0:
        raise ValueError("No JSON object found")
    return json.loads(text[start:end])


def call_anthropic(payload: dict, api_key: str) -> dict:
    request = urllib.request.Request(
        "https://api.anthropic.com/v1/messages",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "x-api-key": api_key,
            "anthropic-version": "2023-06-01",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            response_body = response.read().decode("utf-8")
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        try:
            parsed = json.loads(detail)
            message = parsed.get("error", {}).get("message", detail)
        except json.JSONDecodeError:
            message = detail or f"Anthropic request failed with status {exc.code}."
        raise HTTPException(status_code=502, detail=message) from exc
    except urllib.error.URLError as exc:
        raise HTTPException(
            status_code=502,
            detail="Could not reach Anthropic. Check your internet connection.",
        ) from exc

    parsed_response = json.loads(response_body)
    content = parsed_response.get("content", [])
    if not content or content[0].get("type") != "text":
        raise HTTPException(status_code=502, detail="Anthropic did not return a text response.")
    try:
        return extract_json(content[0]["text"])
    except (json.JSONDecodeError, ValueError) as exc:
        raise HTTPException(status_code=502, detail="Could not parse nutrition data from response.") from exc


def analyze_with_anthropic(image_data_url: str, api_key: str, description: str = "") -> dict:
    header, encoded = image_data_url.split(",", 1)
    media_type = header.split(":")[1].split(";")[0]
    if media_type not in {"image/jpeg", "image/png", "image/gif", "image/webp"}:
        media_type = "image/jpeg"

    user_context = f'\n\nUser-provided context (use this to identify brand, restaurant, or quality): "{description.strip()}"' if description.strip() else ""

    text_prompt = (
        "You are a precise nutrition analyst. Study this food image carefully and follow these steps:\n\n"
        "STEP 1 — IDENTIFY: List every food item, ingredient, sauce, condiment, and drink visible. "
        "Note cooking methods (fried, grilled, etc.) that affect calorie content.\n\n"
        "STEP 2 — PORTION SIZE: Estimate the actual portion size from visual cues. "
        "If a human hand is visible, use it as calibration (adult palm ≈ 8–9 cm wide, 18–20 cm long). "
        "Look for plates, utensils, or packaging. Do NOT default to a generic 'standard serving' — "
        "estimate what is literally in the image. A large plate of pasta is not 200 calories.\n\n"
        "STEP 3 — NUTRITION: Calculate based on identified ingredients and the actual portion. "
        "Include all calorie sources: oils used in cooking, dressings, sauces, condiments."
        f"{user_context}\n\n"
        f"Reply with ONLY a JSON object:\n{NUTRITION_SCHEMA}\n\n{NUTRITION_NOTES}"
    )

    payload = {
        "model": "claude-sonnet-4-6",
        "max_tokens": 800,
        "messages": [
            {
                "role": "user",
                "content": [
                    {
                        "type": "image",
                        "source": {"type": "base64", "media_type": media_type, "data": encoded},
                    },
                    {"type": "text", "text": text_prompt},
                ],
            }
        ],
    }
    estimate = call_anthropic(payload, api_key)
    estimate["source"] = "anthropic"
    return estimate


def analyze_text_with_anthropic(description: str, api_key: str) -> dict:
    payload = {
        "model": "claude-sonnet-4-6",
        "max_tokens": 800,
        "messages": [
            {
                "role": "user",
                "content": (
                    f'You are a precise nutrition analyst. The user describes a meal: "{description}"\n\n'
                    "If a specific restaurant or brand is mentioned, use their actual nutritional data. "
                    "If a portion size is specified, use it exactly. "
                    "Otherwise estimate a realistic typical serving — not an overly conservative one.\n\n"
                    f"Reply with ONLY a JSON object:\n{NUTRITION_SCHEMA}\n\n{NUTRITION_NOTES}"
                ),
            }
        ],
    }
    estimate = call_anthropic(payload, api_key)
    estimate["source"] = "anthropic"
    return estimate


app = FastAPI(title="Calorie Tracker Web API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")


@app.get("/api/health")
def health() -> dict:
    return {
        "ok": True,
        "provider": "anthropic" if os.getenv("ANTHROPIC_API_KEY") else "mock",
    }


@app.post("/api/analyze")
def analyze(request: AnalyzeRequest) -> dict:
    validate_image_data_url(request.imageDataUrl)
    api_key = os.getenv("ANTHROPIC_API_KEY", "").strip()
    return analyze_with_anthropic(request.imageDataUrl, api_key, request.description) if api_key else mock_estimate()


@app.post("/api/analyze-text")
def analyze_text(request: AnalyzeTextRequest) -> dict:
    if not request.description.strip():
        raise HTTPException(status_code=400, detail="Please enter a meal description.")
    api_key = os.getenv("ANTHROPIC_API_KEY", "").strip()
    return analyze_text_with_anthropic(request.description.strip(), api_key) if api_key else mock_estimate()


@app.get("/")
def index() -> FileResponse:
    return FileResponse(STATIC_DIR / "index.html")


@app.get("/my-day")
def my_day() -> FileResponse:
    return FileResponse(STATIC_DIR / "my-day.html")


@app.get("/signup")
def signup() -> FileResponse:
    return FileResponse(STATIC_DIR / "signup.html")


@app.get("/{file_path:path}")
def frontend_files(file_path: str):
    candidate = (STATIC_DIR / file_path).resolve()
    if not str(candidate).startswith(str(STATIC_DIR.resolve())) or not candidate.exists() or not candidate.is_file():
        raise HTTPException(status_code=404, detail="Not found")
    return FileResponse(candidate)
