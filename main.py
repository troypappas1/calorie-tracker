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
            "Mock result is enabled because no OpenAI API key is configured.",
            "Serving size and sauces can change the estimate a lot.",
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


def analyze_with_openai(image_data_url: str, api_key: str) -> dict:
    schema = {
        "type": "object",
        "properties": {
            "title": {"type": "string"},
            "calories": {"type": "integer"},
            "proteinGrams": {"type": "integer"},
            "confidence": {
                "type": "string",
                "enum": ["Low", "Medium", "High"],
            },
            "notes": {
                "type": "array",
                "items": {"type": "string"},
            },
        },
        "required": ["title", "calories", "proteinGrams", "confidence", "notes"],
        "additionalProperties": False,
    }

    payload = {
        "model": "gpt-4.1-mini",
        "input": [
            {
                "role": "user",
                "content": [
                    {
                        "type": "input_text",
                        "text": (
                            "Analyze this food image and estimate the likely dish name, "
                            "calories, and protein in grams for the visible serving. "
                            "Return JSON only. If the image is unclear, make your best "
                            "estimate and lower confidence."
                        ),
                    },
                    {
                        "type": "input_image",
                        "image_url": image_data_url,
                        "detail": "high",
                    },
                ],
            }
        ],
        "text": {
            "format": {
                "type": "json_schema",
                "name": "nutrition_estimate",
                "strict": True,
                "schema": schema,
            }
        },
    }

    request = urllib.request.Request(
        "https://api.openai.com/v1/responses",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
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
            message = detail or f"OpenAI request failed with status {exc.code}."
        raise HTTPException(status_code=502, detail=message) from exc
    except urllib.error.URLError as exc:
        raise HTTPException(
            status_code=502,
            detail="Could not reach OpenAI. Check your internet connection.",
        ) from exc

    parsed_response = json.loads(response_body)
    output_text = parsed_response.get("output_text")
    if not output_text:
        raise HTTPException(status_code=502, detail="OpenAI did not return structured nutrition output.")

    try:
        estimate = json.loads(output_text)
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=502, detail="OpenAI returned invalid nutrition JSON.") from exc

    estimate["source"] = "openai"
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
        "provider": "openai" if os.getenv("OPENAI_API_KEY") else "mock",
    }


@app.post("/api/analyze")
def analyze(request: AnalyzeRequest) -> dict:
    validate_image_data_url(request.imageDataUrl)
    api_key = os.getenv("OPENAI_API_KEY", "").strip()
    return analyze_with_openai(request.imageDataUrl, api_key) if api_key else mock_estimate()


@app.get("/")
def index() -> FileResponse:
    return FileResponse(STATIC_DIR / "index.html")


@app.get("/{file_path:path}")
def frontend_files(file_path: str):
    candidate = (STATIC_DIR / file_path).resolve()

    if not str(candidate).startswith(str(STATIC_DIR.resolve())) or not candidate.exists() or not candidate.is_file():
        raise HTTPException(status_code=404, detail="Not found")

    return FileResponse(candidate)
