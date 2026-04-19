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


class AnalyzeRequest(BaseModel):
    imageDataUrl: str


def mock_estimate() -> dict:
    return {
        "title": "Chicken rice bowl",
        "calories": 640,
        "proteinGrams": 38,
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


def analyze_with_anthropic(image_data_url: str, api_key: str) -> dict:
    header, encoded = image_data_url.split(",", 1)
    media_type = header.split(":")[1].split(";")[0]
    supported = {"image/jpeg", "image/png", "image/gif", "image/webp"}
    if media_type not in supported:
        media_type = "image/jpeg"

    payload = {
        "model": "claude-haiku-4-5-20251001",
        "max_tokens": 512,
        "messages": [
            {
                "role": "user",
                "content": [
                    {
                        "type": "image",
                        "source": {
                            "type": "base64",
                            "media_type": media_type,
                            "data": encoded,
                        },
                    },
                    {
                        "type": "text",
                        "text": (
                            "You are a nutrition expert. Identify the food(s) in this image and "
                            "estimate the dish name, calories (kcal), and protein (grams) for the "
                            "visible serving size.\n\n"
                            "Reply with ONLY a JSON object, no other text:\n"
                            '{"title": "dish name", "calories": 550, "proteinGrams": 25, '
                            '"confidence": "High", "notes": ["short helpful note"]}\n\n'
                            "confidence must be Low, Medium, or High. "
                            "notes should have 1-2 short observations about your estimate."
                        ),
                    },
                ],
            }
        ],
    }

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
        estimate = extract_json(content[0]["text"])
    except (json.JSONDecodeError, ValueError) as exc:
        raise HTTPException(status_code=502, detail="Could not parse nutrition data from response.") from exc

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
    return analyze_with_anthropic(request.imageDataUrl, api_key) if api_key else mock_estimate()


@app.get("/")
def index() -> FileResponse:
    return FileResponse(STATIC_DIR / "index.html")


@app.get("/{file_path:path}")
def frontend_files(file_path: str):
    candidate = (STATIC_DIR / file_path).resolve()
    if not str(candidate).startswith(str(STATIC_DIR.resolve())) or not candidate.exists() or not candidate.is_file():
        raise HTTPException(status_code=404, detail="Not found")
    return FileResponse(candidate)
