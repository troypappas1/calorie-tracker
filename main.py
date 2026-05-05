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


class BeverageRequest(BaseModel):
    imageDataUrl: str
    description: str = ""  # required: name of the beverage


class AnalyzeTextRequest(BaseModel):
    description: str


class MealPlanRequest(BaseModel):
    budget: float = 75.0
    people: int = 2
    diet: str = "no restrictions"
    skill: str = "intermediate"
    notes: str = ""


class WorkoutVideoRequest(BaseModel):
    frameDataUrls: list[str]   # up to 6 base64 frames extracted client-side
    description: str = ""      # optional user hint ("I'm doing squats")


class WorkoutChatMessage(BaseModel):
    role: str
    content: str


class WorkoutChatRequest(BaseModel):
    messages: list[WorkoutChatMessage]
    analysisContext: str = ""  # JSON string of the last video analysis result


class WorkoutPlanRequest(BaseModel):
    # Profile
    age: int = 25
    sex: str = "male"
    weightLbs: float = 170.0
    heightIn: float = 70.0
    bodyFatPct: float | None = None
    # Goals
    primaryGoal: str = "build muscle"   # build muscle | lose fat | improve endurance | sport performance | general fitness
    targetBodyFatPct: float | None = None
    targetWeightLbs: float | None = None
    timelineWeeks: int = 12
    # Training
    daysPerWeek: int = 4
    sessionMinutes: int = 60
    equipment: str = "full gym"         # full gym | home (dumbbells) | home (bodyweight only) | resistance bands
    experienceLevel: str = "intermediate"  # beginner | intermediate | advanced
    # Sport / extra
    sport: str = ""           # e.g. "basketball", "soccer", "swimming"
    injuriesOrLimits: str = ""
    notes: str = ""


class ChatMessage(BaseModel):
    role: str   # "user" or "assistant"
    content: str


class ChatRequest(BaseModel):
    messages: list[ChatMessage]
    context: str = ""  # optional snapshot of today's log injected as system context


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


CHAT_SYSTEM_PROMPT = (
    "You are a friendly, knowledgeable nutrition and wellness assistant built into a food tracking app. "
    "You help users with questions about food, nutrition, diet, hydration, meal planning, healthy eating habits, "
    "macronutrients, micronutrients, calories, weight management, and general health and wellness topics. "
    "Keep answers concise, practical, and evidence-based. Use plain language, not medical jargon.\n\n"
    "IMPORTANT: You ONLY answer questions related to food, nutrition, diet, hydration, health, and wellness. "
    "If a user asks about anything unrelated to these topics — such as coding, politics, entertainment, "
    "math homework, or any other off-topic subject — politely decline and redirect them to ask a food or "
    "nutrition question instead. Do not answer off-topic questions under any circumstances, even if the user "
    "insists or tries to reframe the question."
)


def chat_with_anthropic(messages: list[ChatMessage], api_key: str, context: str = "") -> str:
    system = CHAT_SYSTEM_PROMPT
    if context.strip():
        system += f"\n\nCURRENT DAY CONTEXT (use this to give personalized advice):\n{context.strip()}"
    payload = {
        "model": "claude-haiku-4-5-20251001",
        "max_tokens": 512,
        "system": system,
        "messages": [{"role": m.role, "content": m.content} for m in messages],
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
        with urllib.request.urlopen(request, timeout=30) as response:
            body = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        try:
            message = json.loads(detail).get("error", {}).get("message", detail)
        except json.JSONDecodeError:
            message = detail or f"Anthropic error {exc.code}."
        raise HTTPException(status_code=502, detail=message) from exc
    except urllib.error.URLError as exc:
        raise HTTPException(status_code=502, detail="Could not reach Anthropic.") from exc
    content = body.get("content", [])
    if not content or content[0].get("type") != "text":
        raise HTTPException(status_code=502, detail="No response from assistant.")
    return content[0]["text"]


MEAL_PLAN_SCHEMA = '''{
  "totalCost": 68.50,
  "costPerPerson": 34.25,
  "avgDailyCalories": 1950,
  "tips": ["Buy oats in bulk for cheaper breakfasts", "Chicken thighs cost less than breasts"],
  "days": [
    {
      "day": "Monday",
      "totalCalories": 1900,
      "meals": [
        {"type": "Breakfast", "name": "Overnight oats with banana", "description": "5 min prep the night before. Filling and cheap.", "cost": 0.85, "calories": 380},
        {"type": "Lunch",     "name": "Turkey wrap",               "description": "Whole-wheat tortilla, turkey, lettuce, mustard.", "cost": 2.10, "calories": 520},
        {"type": "Dinner",    "name": "Sheet-pan chicken thighs",  "description": "With roasted broccoli and rice. 25 min oven time.", "cost": 3.80, "calories": 650},
        {"type": "Snack",     "name": "Apple and peanut butter",   "description": "", "cost": 0.60, "calories": 250}
      ]
    }
  ]
}'''


def meal_plan_with_anthropic(budget: float, people: int, diet: str, skill: str, notes: str, api_key: str) -> dict:
    skill_map = {
        "beginner": "very simple recipes under 15 minutes that require minimal cooking skill",
        "intermediate": "straightforward recipes under 30 minutes",
        "confident": "recipes up to 1 hour that may involve basic techniques like sautéing or roasting",
    }
    skill_desc = skill_map.get(skill, skill_map["intermediate"])

    notes_line = f'\nExtra notes from user: "{notes.strip()}"' if notes.strip() else ""

    prompt = (
        f"You are a budget-conscious meal planning expert. Create a realistic 7-day meal plan for {people} person(s) "
        f"with a total weekly grocery budget of ${budget:.0f} USD.\n\n"
        f"Dietary preference: {diet}\n"
        f"Cooking skill: {skill_desc}{notes_line}\n\n"
        "Rules:\n"
        "- Include breakfast, lunch, dinner, and one snack every day\n"
        "- Meals must be genuinely easy and affordable — no gourmet ingredients\n"
        "- Reuse ingredients across days to reduce waste and cost\n"
        "- Keep per-meal costs realistic for a US grocery store\n"
        "- Estimate calories per meal realistically\n"
        "- Include 2-3 actionable shopping tips\n\n"
        f"Reply with ONLY a valid JSON object exactly matching this schema:\n{MEAL_PLAN_SCHEMA}"
    )
    payload = {
        "model": "claude-haiku-4-5-20251001",
        "max_tokens": 2500,
        "messages": [{"role": "user", "content": prompt}],
    }
    result = call_anthropic(payload, api_key)
    return result


WORKOUT_ANALYSIS_SCHEMA = '''{
  "exercise": "Barbell Back Squat",
  "muscleGroups": {"primary": ["Quadriceps", "Glutes"], "secondary": ["Hamstrings", "Core", "Erector Spinae"]},
  "repCount": 3,
  "formScore": 82,
  "formGrade": "B+",
  "keyObservations": ["Good depth achieved below parallel", "Slight forward lean on ascent"],
  "formBreakdowns": [
    {"issue": "Forward lean", "severity": "minor", "cue": "Chest up, think about pushing the floor away"},
    {"issue": "Knee cave on rep 2", "severity": "moderate", "cue": "Drive knees out over pinky toes throughout the lift"}
  ],
  "positiveFeedback": ["Controlled eccentric", "Neutral spine at bottom"],
  "safetyFlags": [],
  "breathingCue": "Brace core and breathe out at the top of each rep",
  "progressionTips": ["Add 5 lbs next session if form holds", "Film from the side for a better depth check"]
}'''

WORKOUT_PLAN_SCHEMA = '''{
  "planTitle": "12-Week Hypertrophy Block",
  "overview": "A progressive overload program focused on muscle growth across all major groups.",
  "weeklyStructure": "4 days on, 3 days rest. Upper/Lower split.",
  "estimatedCalsBurned": 350,
  "macroTip": "Aim for 0.8–1g protein per lb of bodyweight to support muscle growth.",
  "phases": [
    {
      "phase": 1,
      "weeks": "1–4",
      "focus": "Foundation & technique",
      "days": [
        {
          "dayLabel": "Day 1 — Upper (Push)",
          "exercises": [
            {"name": "Barbell Bench Press", "sets": 4, "reps": "6–8", "rest": "90s", "cue": "Retract scapula, drive feet into floor"},
            {"name": "Incline Dumbbell Press", "sets": 3, "reps": "10–12", "rest": "60s", "cue": "Full stretch at bottom"},
            {"name": "Overhead Press", "sets": 3, "reps": "8–10", "rest": "75s", "cue": "Squeeze glutes to protect lower back"},
            {"name": "Lateral Raises", "sets": 3, "reps": "15–20", "rest": "45s", "cue": "Lead with elbows, slight forward lean"},
            {"name": "Tricep Pushdowns", "sets": 3, "reps": "12–15", "rest": "45s", "cue": "Keep elbows pinned"}
          ]
        }
      ]
    }
  ],
  "cardioRecommendation": "2–3 sessions of 20–30 min moderate cardio on rest days.",
  "recoveryTips": ["Sleep 7–9 hrs", "Walk 8k steps daily", "Foam roll quads and lats post-workout"]
}'''


def analyze_workout_video(frames: list[str], api_key: str, description: str = "") -> dict:
    content = []
    for frame_data_url in frames[:6]:
        try:
            header, encoded = frame_data_url.split(",", 1)
            media_type = header.split(":")[1].split(";")[0]
            if media_type not in {"image/jpeg", "image/png", "image/gif", "image/webp"}:
                media_type = "image/jpeg"
            content.append({"type": "image", "source": {"type": "base64", "media_type": media_type, "data": encoded}})
        except Exception:
            continue

    if not content:
        raise HTTPException(status_code=400, detail="No valid frames extracted from video.")

    hint = f'\n\nUser hint: "{description.strip()}"' if description.strip() else ""
    prompt = (
        "You are an expert strength and conditioning coach and movement analyst. "
        "You are viewing frames extracted from a workout video. Analyze the exercise being performed.\n\n"
        "STEP 1 — IDENTIFY: Name the exact exercise (e.g. 'Barbell Back Squat', 'Push-Up', 'Dumbbell Romanian Deadlift'). "
        "Identify all muscle groups worked: list primary movers and secondary stabilizers.\n\n"
        "STEP 2 — REP COUNT: Count how many reps are visible across the frames.\n\n"
        "STEP 3 — FORM ANALYSIS: Score form 0–100. Look for:\n"
        "- Joint alignment (knees tracking over toes, neutral spine, elbow position, etc.)\n"
        "- Range of motion (full extension/flexion, adequate depth)\n"
        "- Tempo and control (no bouncing, controlled eccentric)\n"
        "- Body positioning (bar path, foot placement, grip width)\n"
        "- Breathing and bracing cues\n\n"
        "STEP 4 — FEEDBACK: List specific form breakdowns with severity (minor/moderate/major) and a single corrective cue for each. "
        "Also note what the athlete is doing well. Flag any safety concerns.\n"
        f"{hint}\n\n"
        f"Reply with ONLY a JSON object:\n{WORKOUT_ANALYSIS_SCHEMA}"
    )
    content.append({"type": "text", "text": prompt})

    payload = {
        "model": "claude-sonnet-4-6",
        "max_tokens": 1200,
        "messages": [{"role": "user", "content": content}],
    }
    result = call_anthropic(payload, api_key)
    result["source"] = "anthropic"
    return result


WORKOUT_CHAT_SYSTEM = (
    "You are an expert personal trainer and strength & conditioning coach embedded in a fitness app. "
    "You just analyzed a video of the user's workout and have detailed form feedback. "
    "Help the user understand their form, answer follow-up questions, suggest drills to fix issues, "
    "explain muscle activation, and give programming advice. "
    "Keep answers practical, encouraging, and concise. Use plain language. "
    "ONLY answer questions related to fitness, exercise, form, training, recovery, and sports performance. "
    "Decline off-topic questions politely."
)


def chat_workout_with_anthropic(messages: list[WorkoutChatMessage], api_key: str, context: str = "") -> str:
    system = WORKOUT_CHAT_SYSTEM
    if context.strip():
        system += f"\n\nLAST VIDEO ANALYSIS RESULT (use this as context for all answers):\n{context.strip()}"
    payload = {
        "model": "claude-haiku-4-5-20251001",
        "max_tokens": 600,
        "system": system,
        "messages": [{"role": m.role, "content": m.content} for m in messages],
    }
    request = urllib.request.Request(
        "https://api.anthropic.com/v1/messages",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json", "x-api-key": api_key, "anthropic-version": "2023-06-01"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            body = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        try:
            message = json.loads(detail).get("error", {}).get("message", detail)
        except json.JSONDecodeError:
            message = detail or f"Anthropic error {exc.code}."
        raise HTTPException(status_code=502, detail=message) from exc
    except urllib.error.URLError as exc:
        raise HTTPException(status_code=502, detail="Could not reach Anthropic.") from exc
    content_blocks = body.get("content", [])
    if not content_blocks or content_blocks[0].get("type") != "text":
        raise HTTPException(status_code=502, detail="No response from assistant.")
    return content_blocks[0]["text"]


def generate_workout_plan(req: WorkoutPlanRequest, api_key: str) -> dict:
    height_ft = int(req.heightIn // 12)
    height_in = int(req.heightIn % 12)
    bf_str = f", ~{req.bodyFatPct}% body fat" if req.bodyFatPct else ""
    target_bf = f"Target body fat: {req.targetBodyFatPct}%" if req.targetBodyFatPct else ""
    target_wt = f"Target weight: {req.targetWeightLbs} lbs" if req.targetWeightLbs else ""
    sport_str = f"Sport performance focus: {req.sport}" if req.sport.strip() else ""
    injuries_str = f"Injuries/limitations: {req.injuriesOrLimits}" if req.injuriesOrLimits.strip() else ""
    notes_str = f"Additional notes: {req.notes}" if req.notes.strip() else ""

    prompt = (
        "You are an elite personal trainer and strength & conditioning specialist. "
        f"Create a detailed {req.timelineWeeks}-week workout plan for the following athlete:\n\n"
        f"Profile: {req.age}yo {req.sex}, {req.weightLbs} lbs, {height_ft}'{height_in}\"{bf_str}\n"
        f"Experience: {req.experienceLevel}\n"
        f"Primary goal: {req.primaryGoal}\n"
        f"{target_bf}\n{target_wt}\n"
        f"Training: {req.daysPerWeek} days/week, {req.sessionMinutes} min/session\n"
        f"Equipment: {req.equipment}\n"
        f"{sport_str}\n{injuries_str}\n{notes_str}\n\n"
        "Requirements:\n"
        "- Structure the plan into phases (e.g. foundation, hypertrophy, strength, peak)\n"
        "- For EACH training day list every exercise with sets, reps/duration, rest, and a 1-sentence coaching cue\n"
        "- Include cardio/conditioning recommendations\n"
        "- Include a macro/nutrition tip personalized to the goal\n"
        "- Include recovery tips\n"
        "- Exercises must match the available equipment\n"
        "- Account for any injuries or sport-specific demands\n\n"
        f"Reply with ONLY a valid JSON object matching this schema:\n{WORKOUT_PLAN_SCHEMA}"
    )
    payload = {
        "model": "claude-sonnet-4-6",
        "max_tokens": 4000,
        "messages": [{"role": "user", "content": prompt}],
    }
    result = call_anthropic(payload, api_key)
    return result


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


def analyze_beverage_with_anthropic(image_data_url: str, api_key: str, description: str = "") -> dict:
    header, encoded = image_data_url.split(",", 1)
    media_type = header.split(":")[1].split(";")[0]
    if media_type not in {"image/jpeg", "image/png", "image/gif", "image/webp"}:
        media_type = "image/jpeg"

    beverage_hint = f'The user says this is: "{description.strip()}".' if description.strip() else "The user did not specify the beverage — make your best identification from the image."

    text_prompt = (
        "You are a precise nutrition analyst specializing in beverages and drinks.\n\n"
        f"{beverage_hint}\n\n"
        "STEP 1 — IDENTIFY the beverage: brand, type, flavor, and whether it appears to be diet/regular/alcoholic.\n\n"
        "STEP 2 — ESTIMATE VOLUME: Use any visible hand, bottle label, glass size, or contextual cues to estimate the volume in the cup/glass/bottle shown. "
        "A standard water bottle is ~500ml. A coffee mug is ~240–350ml. A soda can is ~355ml. "
        "If a hand is visible, use it to calibrate — a typical adult hand spans about 20cm. "
        "Do NOT default to a standard serving — estimate what is literally shown.\n\n"
        "STEP 3 — NUTRITION: Calculate based on the identified beverage and estimated volume. "
        "Include calories, sugar, caffeine if relevant. For water, all values are 0 except volume.\n\n"
        f"Reply with ONLY a JSON object:\n{NUTRITION_SCHEMA}\n\n{NUTRITION_NOTES}\n\n"
        "For beverages: weightGrams = volume in ml (1ml water ≈ 1g). sizeDescription should describe the container size."
    )

    payload = {
        "model": "claude-sonnet-4-6",
        "max_tokens": 600,
        "messages": [{
            "role": "user",
            "content": [
                {"type": "image", "source": {"type": "base64", "media_type": media_type, "data": encoded}},
                {"type": "text", "text": text_prompt},
            ],
        }],
    }
    estimate = call_anthropic(payload, api_key)
    estimate["source"] = "anthropic"
    return estimate


@app.post("/api/analyze-beverage")
def analyze_beverage(request: BeverageRequest) -> dict:
    validate_image_data_url(request.imageDataUrl)
    api_key = os.getenv("ANTHROPIC_API_KEY", "").strip()
    if not api_key:
        return mock_estimate()
    return analyze_beverage_with_anthropic(request.imageDataUrl, api_key, request.description)


@app.post("/api/chat")
def chat(request: ChatRequest) -> dict:
    if not request.messages:
        raise HTTPException(status_code=400, detail="No messages provided.")
    api_key = os.getenv("ANTHROPIC_API_KEY", "").strip()
    if not api_key:
        return {"reply": "The nutrition assistant isn't available yet — the API key hasn't been configured."}
    reply = chat_with_anthropic(request.messages, api_key, request.context)
    return {"reply": reply}


@app.post("/api/meal-plan")
def meal_plan(request: MealPlanRequest) -> dict:
    api_key = os.getenv("ANTHROPIC_API_KEY", "").strip()
    if not api_key:
        raise HTTPException(status_code=503, detail="Meal planner requires an API key. Set ANTHROPIC_API_KEY.")
    return meal_plan_with_anthropic(
        request.budget, request.people, request.diet, request.skill, request.notes, api_key
    )


@app.post("/api/analyze-text")
def analyze_text(request: AnalyzeTextRequest) -> dict:
    if not request.description.strip():
        raise HTTPException(status_code=400, detail="Please enter a meal description.")
    api_key = os.getenv("ANTHROPIC_API_KEY", "").strip()
    return analyze_text_with_anthropic(request.description.strip(), api_key) if api_key else mock_estimate()


@app.post("/api/analyze-workout")
def analyze_workout(request: WorkoutVideoRequest) -> dict:
    if not request.frameDataUrls:
        raise HTTPException(status_code=400, detail="No video frames provided.")
    api_key = os.getenv("ANTHROPIC_API_KEY", "").strip()
    if not api_key:
        raise HTTPException(status_code=503, detail="Workout analysis requires an API key.")
    return analyze_workout_video(request.frameDataUrls, api_key, request.description)


@app.post("/api/chat-workout")
def chat_workout(request: WorkoutChatRequest) -> dict:
    if not request.messages:
        raise HTTPException(status_code=400, detail="No messages provided.")
    api_key = os.getenv("ANTHROPIC_API_KEY", "").strip()
    if not api_key:
        return {"reply": "The workout assistant isn't available yet — the API key hasn't been configured."}
    reply = chat_workout_with_anthropic(request.messages, api_key, request.analysisContext)
    return {"reply": reply}


@app.post("/api/workout-plan")
def workout_plan(request: WorkoutPlanRequest) -> dict:
    api_key = os.getenv("ANTHROPIC_API_KEY", "").strip()
    if not api_key:
        raise HTTPException(status_code=503, detail="Workout plan generation requires an API key.")
    return generate_workout_plan(request, api_key)


@app.get("/")
def index() -> FileResponse:
    return FileResponse(STATIC_DIR / "index.html")


@app.get("/my-day")
def my_day() -> FileResponse:
    return FileResponse(STATIC_DIR / "my-day.html")


@app.get("/meal-planner")
def meal_planner_page() -> FileResponse:
    return FileResponse(STATIC_DIR / "meal-planner.html")


@app.get("/workout")
def workout_page() -> FileResponse:
    return FileResponse(STATIC_DIR / "workout.html")


@app.get("/workout-plan")
def workout_plan_page() -> FileResponse:
    return FileResponse(STATIC_DIR / "workout-plan.html")


@app.get("/signup")
def signup() -> FileResponse:
    return FileResponse(STATIC_DIR / "signup.html")


@app.get("/contact")
def contact() -> FileResponse:
    return FileResponse(STATIC_DIR / "contact.html")


@app.get("/{file_path:path}")
def frontend_files(file_path: str):
    candidate = (STATIC_DIR / file_path).resolve()
    if not str(candidate).startswith(str(STATIC_DIR.resolve())) or not candidate.exists() or not candidate.is_file():
        raise HTTPException(status_code=404, detail="Not found")
    return FileResponse(candidate)
