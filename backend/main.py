from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, field_validator

class ReminderCreateRequest(BaseModel):
    user_id: str
    plant_name: str
    disease_name: str
    treatment_type: str
    scheduled_time: str

class ProfileUpdate(BaseModel):
    user_id: str
    full_name: str
    phone: str
    location: str
from supabase import create_client, Client
import os
import uuid
from dotenv import load_dotenv
from typing import Optional
from PIL import Image
import io
import json
import numpy as np
import cv2
from skimage.filters.rank import entropy
from skimage.morphology import disk

# Load environment variables
load_dotenv()

# ─── Rice-Entropy-Fusion Model Configuration ────────────────────────────────
# 6-class, 4-channel (RGB + Entropy) model — 97.9% accuracy
CLASS_NAMES = [
    "BacterialLeafBlight",
    "BrownSpot",
    "Healthy",
    "LeafBlast",
    "LeafScald",
    "NarrowBrownSpot",
]

# ─── Load TFLite Model ──────────────────────────────────────────────────────
import tflite_runtime.interpreter as tflite

MODEL_PATH = os.path.join(os.path.dirname(__file__), "AI_Model", "rice_model_97_final.tflite")
interpreter = None

try:
    interpreter = tflite.Interpreter(model_path=MODEL_PATH)
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    print(f"✅ Rice-Entropy-Fusion TFLite model loaded: {MODEL_PATH}")
    print(f"   Input shape:  {input_details[0]['shape']}")
    print(f"   Output shape: {output_details[0]['shape']}")
except Exception as e:
    print(f"❌ Failed to load TFLite model: {e}")
    interpreter = None

# ─── Load Causal Rules (Bilingual Expert System) ────────────────────────────
CAUSAL_RULES_PATH = os.path.join(os.path.dirname(__file__), "AI_Model", "causal_rules.json")
causal_rules: dict = {}

try:
    with open(CAUSAL_RULES_PATH, "r", encoding="utf-8") as f:
        causal_rules = json.load(f)
    print(f"✅ Causal rules loaded: {len(causal_rules)} entries")
except Exception as e:
    print(f"⚠️ Could not load causal_rules.json: {e}")

# --- Initialize the FastAPI App ---
app = FastAPI(title="Plant Pulse API — Rice-Entropy-Fusion v2.0")

# --- Configure CORS Middleware ---
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── Supabase Configuration ──────────────────────────────────────────────────

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_ANON_KEY")

supabase: Optional[Client] = None

if not SUPABASE_URL or not SUPABASE_KEY:
    print("Warning: Supabase credentials missing. Running in OFFLINE mode.")
else:
    try:
        import httpx
        supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
        print("Backend: Supabase Connected")
    except TypeError as e:
        if 'proxy' in str(e):
            from supabase._sync.client import SyncClient
            supabase = SyncClient(SUPABASE_URL, SUPABASE_KEY)
            print("Backend: Supabase Connected (compat mode)")
        else:
            print(f"Warning: Supabase Initialization Failed ({e}). Running in OFFLINE mode.")
            supabase = None
    except Exception as e:
        print(f"Warning: Supabase Initialization Failed ({e}). Running in OFFLINE mode.")
        supabase = None


# ══════════════════════════════════════════════════════════════════════════════
#  ENTROPY PIPELINE — 4-Channel Image Processing
# ══════════════════════════════════════════════════════════════════════════════

def build_entropy_channel(image_rgb: np.ndarray) -> np.ndarray:
    """
    Generate a local entropy mask from the RGB image.
    1. Convert to grayscale (uint8)
    2. Compute local entropy using skimage disk(5)
    3. Normalize to 0-255 range (uint8)
    Returns a (H, W) uint8 array.
    """
    gray = cv2.cvtColor(image_rgb, cv2.COLOR_RGB2GRAY)
    ent = entropy(gray, disk(5))
    # Normalize entropy to 0–255 range
    ent_min, ent_max = ent.min(), ent.max()
    if ent_max - ent_min > 0:
        ent_normalized = ((ent - ent_min) / (ent_max - ent_min) * 255).astype(np.uint8)
    else:
        ent_normalized = np.zeros_like(gray, dtype=np.uint8)
    return ent_normalized


def preprocess_image(image_bytes: bytes) -> np.ndarray:
    """
    Full preprocessing pipeline:
    1. Decode image → RGB (224×224)
    2. Generate entropy channel
    3. Stack RGB + Entropy → (1, 224, 224, 4) float32 normalized /255.0
    """
    # Decode image
    nparr = np.frombuffer(image_bytes, np.uint8)
    img_bgr = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if img_bgr is None:
        raise ValueError("Could not decode image")

    # Resize to model input size
    img_bgr = cv2.resize(img_bgr, (224, 224), interpolation=cv2.INTER_AREA)
    img_rgb = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)

    # Generate entropy channel
    entropy_channel = build_entropy_channel(img_rgb)

    # Stack RGB + Entropy → (224, 224, 4)
    four_channel = np.dstack([img_rgb, entropy_channel])

    # Normalize to [0, 1] and add batch dimension
    tensor = four_channel.astype(np.float32) / 255.0
    tensor = np.expand_dims(tensor, axis=0)  # (1, 224, 224, 4)

    return tensor


# ══════════════════════════════════════════════════════════════════════════════
#  API ENDPOINTS
# ══════════════════════════════════════════════════════════════════════════════

# ─── System / Health ────────────────────────────────────────────────────────

@app.get("/")
@app.get("/health")
async def health_check():
    return {
        "status": "online",
        "model": "Rice-Entropy-Fusion v2.0 (97.9%)",
        "model_loaded": interpreter is not None,
        "db_connected": supabase is not None,
        "mode": "production" if os.getenv("RAILWAY_ENVIRONMENT") else "development",
        "classes": CLASS_NAMES,
    }


# ─── Inference Endpoint (4-Channel Entropy Pipeline) ────────────────────────

@app.post("/predict")
async def predict_image(file: UploadFile = File(...)):
    """
    Rice disease inference endpoint.
    Accepts a raw image, builds the 4-channel (RGB + Entropy) tensor,
    and returns the predicted class with confidence.
    """
    if interpreter is None:
        raise HTTPException(
            status_code=503,
            detail="Rice-Entropy-Fusion model is not loaded. Check server logs."
        )

    try:
        # Read uploaded image
        image_bytes = await file.read()
        if not image_bytes:
            raise HTTPException(status_code=400, detail="Empty file uploaded.")

        # Build 4-channel tensor
        tensor = preprocess_image(image_bytes)

        # Run TFLite inference
        interpreter.set_tensor(input_details[0]['index'], tensor)
        interpreter.invoke()
        predictions = interpreter.get_tensor(output_details[0]['index'])[0]

        # Get top prediction
        predicted_index = int(np.argmax(predictions))
        confidence = float(predictions[predicted_index])
        label = CLASS_NAMES[predicted_index]

        return {
            "label": label,
            "confidence": round(confidence, 6),
            "all_predictions": {
                CLASS_NAMES[i]: round(float(predictions[i]), 6)
                for i in range(len(CLASS_NAMES))
            },
        }

    except HTTPException:
        raise
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Inference failed: {str(e)}")


# ─── Treatment / Expert System Endpoint ──────────────────────────────────────

@app.get("/treatment/{disease_id}")
async def get_treatment(disease_id: str, acres: float = 1.0):
    """
    Returns bilingual (EN/UR) causal + treatment data for a given disease label.
    Reads from causal_rules.json which contains the 6-class expert system data.
    """
    rule = causal_rules.get(disease_id)

    if not rule:
        return {
            "disease": disease_id,
            "language": "en",
            "instruction": "Treatment data not found for this label. Please consult a local agricultural expert.\nاس بیماری کے لیے علاج کی معلومات دستیاب نہیں۔ مقامی زرعی ماہر سے مشورہ کریں۔",
            "dosage_per_acre": "N/A",
            "market_recommendations": [],
        }

    # Build unified treatment instruction from causal_rules
    treatment_en = rule.get("treatment_en", "No treatment data available.")
    treatment_ur = rule.get("treatment_ur", "علاج کی معلومات دستیاب نہیں۔")
    symptoms = rule.get("symptoms", "")
    cause = rule.get("cause", "")
    prevention = rule.get("prevention", "")
    severity = rule.get("severity_level", "Unknown")

    instruction = (
        f"Severity: {severity}\n"
        f"Symptoms: {symptoms}\n"
        f"Cause: {cause}\n\n"
        f"Treatment:\n{treatment_en}\n\n"
        f"Prevention:\n{prevention}\n\n"
        f"--- اردو ---\n"
        f"علاج:\n{treatment_ur}"
    )

    return {
        "disease": rule.get("name_en", disease_id),
        "language": "en",
        "instruction": instruction,
        "dosage_per_acre": "Standard",
        "market_recommendations": [],
    }


# ─── Statistics API ─────────────────────────────────────────────────────────

@app.get("/stats")
async def crop_summary_short(user_id: str):
    if supabase is None:
        raise HTTPException(status_code=503, detail="Database unavailable — running in offline mode.")

    if not user_id or not user_id.strip():
        raise HTTPException(status_code=400, detail="user_id is required.")

    try:
        response = supabase.table("scan_history") \
            .select("disease_result, confidence_score") \
            .eq("user_id", user_id.strip()) \
            .execute()

        rows = response.data or []
        total_scans = len(rows)

        if total_scans == 0:
            return {
                "total_scans":    0,
                "healthy_count":  0,
                "diseased_count": 0,
                "healthy_pct":    0.0,
                "diseased_pct":   0.0,
                "top_diseases":   [],
            }

        healthy_count = sum(1 for r in rows if "healthy" in r.get("disease_result", "").lower())
        diseased_count = total_scans - healthy_count

        def pct(n): return round((n / total_scans) * 100, 1)

        freq: dict[str, int] = {}
        for r in rows:
            label = r.get("disease_result", "Unknown")
            if "healthy" not in label.lower():
                freq[label] = freq.get(label, 0) + 1

        top_diseases = sorted(
            [{"disease": label, "count": count, "percentage": pct(count)} for label, count in freq.items()],
            key=lambda x: x["count"],
            reverse=True,
        )[:10]

        return {
            "total_scans":    total_scans,
            "healthy_count":  healthy_count,
            "diseased_count": diseased_count,
            "healthy_pct":    pct(healthy_count),
            "diseased_pct":   pct(diseased_count),
            "top_diseases":   top_diseases,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Stats query failed: {str(e)}")


# ─── Spray Reminders API ─────────────────────────────────────────────────────

@app.get("/reminders")
async def get_reminders_short(user_id: str):
    if supabase is None:
        return {"reminders": [], "count": 0}

    if not user_id or not user_id.strip():
        raise HTTPException(status_code=400, detail="user_id is required.")

    try:
        from datetime import datetime, timezone
        now_iso = datetime.now(timezone.utc).isoformat()

        response = supabase.table("spray_reminders") \
            .select("id, plant_name, disease_name, treatment_type, scheduled_time, is_completed") \
            .eq("user_id", user_id.strip()) \
            .eq("is_completed", False) \
            .order("scheduled_time", desc=False) \
            .execute()

        return {
            "reminders": response.data or [],
            "count":     len(response.data or []),
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch reminders: {str(e)}")


@app.post("/reminders")
async def create_reminder_short(payload: ReminderCreateRequest):
    if supabase is None:
        return {"success": True, "record_id": str(uuid.uuid4()), "message": "Offline mode."}

    if not payload.user_id.strip():
        raise HTTPException(status_code=400, detail="user_id is required.")

    record_id = str(uuid.uuid4())

    try:
        supabase.table("spray_reminders").insert({
            "id":             record_id,
            "user_id":        payload.user_id.strip(),
            "plant_name":     payload.plant_name.strip(),
            "disease_name":   payload.disease_name.strip(),
            "treatment_type": payload.treatment_type.strip(),
            "scheduled_time": payload.scheduled_time.strip(),
            "is_completed":   False,
        }).execute()

        return {
            "success":   True,
            "record_id": record_id,
            "message":   "Reminder scheduled.",
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create reminder: {str(e)}")


@app.patch("/reminders/{reminder_id}/complete")
async def complete_reminder_short(reminder_id: str, user_id: str):
    if supabase is None:
        return {"success": True}

    try:
        response = supabase.table("spray_reminders") \
            .update({"is_completed": True}) \
            .eq("id", reminder_id) \
            .eq("user_id", user_id) \
            .execute()

        if not response.data:
            raise HTTPException(status_code=404, detail="Reminder not found.")

        return {"success": True, "message": "Reminder marked as complete."}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to complete reminder: {str(e)}")


# ─── Core Models ─────────────────────────────────────────────────────────────

class ScanResultCreate(BaseModel):
    user_id:         str
    crop_name:       str
    disease_result:  str
    confidence_score: float

    @field_validator("confidence_score")
    @classmethod
    def clamp_confidence(cls, v: float) -> float:
        if not (0.0 <= v <= 1.0):
            raise ValueError("confidence_score must be between 0.0 and 1.0")
        return round(v, 6)

class ReminderCreateRequest(BaseModel):
    user_id:        str
    plant_name:     str
    disease_name:   str
    treatment_type: str
    scheduled_time: str


# ─── Scan History API ────────────────────────────────────────────────────────

@app.post("/api/v1/scans/save")
async def save_scan_v1(payload: ScanResultCreate):
    if supabase is None:
        raise HTTPException(status_code=503, detail="Database unavailable — running in offline mode.")

    if not payload.user_id or not payload.user_id.strip():
        raise HTTPException(status_code=400, detail="user_id is required.")

    record_id = str(uuid.uuid4())

    try:
        response = supabase.table("scan_history").insert({
            "id":               record_id,
            "user_id":          payload.user_id.strip(),
            "plant_name":       payload.crop_name.strip(),
            "disease_result":   payload.disease_result.strip(),
            "confidence_score": payload.confidence_score,
        }).execute()

        if not response.data:
            raise HTTPException(status_code=500, detail="Insert returned no data.")

        return {
            "success":   True,
            "record_id": record_id,
            "message":   "Scan saved to history.",
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to save scan: {str(e)}")


@app.get("/api/v1/stats/crop-summary")
async def crop_summary_v1(user_id: str):
    if supabase is None:
        raise HTTPException(status_code=503, detail="Database unavailable — running in offline mode.")

    if not user_id or not user_id.strip():
        raise HTTPException(status_code=400, detail="user_id is required.")

    try:
        response = supabase.table("scan_history") \
            .select("disease_result, confidence_score") \
            .eq("user_id", user_id.strip()) \
            .execute()

        rows = response.data or []
        total_scans = len(rows)

        if total_scans == 0:
            return {
                "total_scans":    0,
                "healthy_count":  0,
                "diseased_count": 0,
                "healthy_pct":    0.0,
                "diseased_pct":   0.0,
                "top_diseases":   [],
            }

        healthy_count = sum(1 for r in rows if "healthy" in r.get("disease_result", "").lower())
        diseased_count = total_scans - healthy_count

        def pct(n): return round((n / total_scans) * 100, 1)

        freq: dict[str, int] = {}
        for r in rows:
            label = r.get("disease_result", "Unknown")
            if "healthy" not in label.lower():
                freq[label] = freq.get(label, 0) + 1

        top_diseases = sorted(
            [{"disease": label, "count": count, "percentage": pct(count)} for label, count in freq.items()],
            key=lambda x: x["count"],
            reverse=True,
        )[:10]

        return {
            "total_scans":    total_scans,
            "healthy_count":  healthy_count,
            "diseased_count": diseased_count,
            "healthy_pct":    pct(healthy_count),
            "diseased_pct":   pct(diseased_count),
            "top_diseases":   top_diseases,
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Stats query failed: {str(e)}")


# ─── Spray Reminders API (v1) ───────────────────────────────────────────────

@app.post("/api/v1/reminders/create")
async def create_reminder_v1(payload: ReminderCreateRequest):
    if supabase is None:
        raise HTTPException(status_code=503, detail="Database unavailable.")

    if not payload.user_id.strip():
        raise HTTPException(status_code=400, detail="user_id is required.")
    if not payload.scheduled_time.strip():
        raise HTTPException(status_code=400, detail="scheduled_time is required.")

    record_id = str(uuid.uuid4())

    try:
        response = supabase.table("spray_reminders").insert({
            "id":             record_id,
            "user_id":        payload.user_id.strip(),
            "plant_name":     payload.plant_name.strip(),
            "disease_name":   payload.disease_name.strip(),
            "treatment_type": payload.treatment_type.strip(),
            "scheduled_time": payload.scheduled_time.strip(),
            "is_completed":   False,
        }).execute()

        if not response.data:
            raise HTTPException(status_code=500, detail="Insert returned no data.")

        return {
            "success":   True,
            "record_id": record_id,
            "message":   "Reminder scheduled.",
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create reminder: {str(e)}")


@app.get("/api/v1/reminders/active")
async def get_active_reminders_v1(user_id: str):
    if supabase is None:
        raise HTTPException(status_code=503, detail="Database unavailable.")

    if not user_id.strip():
        raise HTTPException(status_code=400, detail="user_id is required.")

    try:
        from datetime import datetime, timezone
        now_iso = datetime.now(timezone.utc).isoformat()

        response = supabase.table("spray_reminders") \
            .select("id, plant_name, disease_name, treatment_type, scheduled_time, is_completed") \
            .eq("user_id", user_id.strip()) \
            .eq("is_completed", False) \
            .gte("scheduled_time", now_iso) \
            .order("scheduled_time", desc=False) \
            .execute()

        return {
            "reminders": response.data or [],
            "count":     len(response.data or []),
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch reminders: {str(e)}")


@app.patch("/api/v1/reminders/{reminder_id}/complete")
async def complete_reminder_v1(reminder_id: str, user_id: str):
    if supabase is None:
        raise HTTPException(status_code=503, detail="Database unavailable.")

    try:
        response = supabase.table("spray_reminders") \
            .update({"is_completed": True}) \
            .eq("id", reminder_id) \
            .eq("user_id", user_id) \
            .execute()

        if not response.data:
            raise HTTPException(status_code=404, detail="Reminder not found or not owned by user.")

        return {"success": True, "message": "Reminder marked as complete."}

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to complete reminder: {str(e)}")


# ─── Profile Management API ──────────────────────────────────────────────────

@app.get("/profile/{user_id}")
async def get_user_profile(user_id: str):
    if supabase is None:
        return {"id": user_id, "full_name": "", "phone": "", "location": ""}

    try:
        response = supabase.table("profiles").select("*").eq("id", user_id).execute()
        if not response.data:
            return {"id": user_id, "full_name": "", "phone": "", "location": ""}
        return response.data[0]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch profile: {str(e)}")


@app.post("/profile/sync")
async def sync_user_profile(payload: ProfileUpdate):
    if supabase is None:
        raise HTTPException(status_code=503, detail="Database unavailable.")

    try:
        data = {
            "id": payload.user_id,
            "full_name": payload.full_name,
            "phone": payload.phone,
            "location": payload.location,
            "updated_at": "now()"
        }

        supabase.table("profiles").upsert(data).execute()
        return {"success": True, "message": "Profile synced successfully."}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to sync profile: {str(e)}")

class ScanHistoryPayload(BaseModel):
    user_id: str
    crop_name: str
    disease_result: str
    confidence_score: float

# ─── Scan History API ────────────────────────────────────────────────────────

@app.post("/history/save")
async def save_scan_history(payload: ScanHistoryPayload):
    if supabase is None:
        raise HTTPException(status_code=503, detail="Database unavailable.")

    if not payload.user_id or not payload.user_id.strip():
        raise HTTPException(status_code=400, detail="user_id is required.")

    record_id = str(uuid.uuid4())

    try:
        supabase.table("scan_history").insert({
            "id":               record_id,
            "user_id":          payload.user_id.strip(),
            "plant_name":       payload.crop_name.strip(),
            "disease_result":   payload.disease_result.strip(),
            "confidence_score": payload.confidence_score,
        }).execute()

        return {
            "success":   True,
            "record_id": record_id,
            "message":   "Scan saved to history.",
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to save scan: {str(e)}")


@app.get("/history/{user_id}")
async def get_history(user_id: str):
    if supabase is None:
        return {"scans": []}
    try:
        response = supabase.table("scan_history") \
            .select("*") \
            .eq("user_id", user_id) \
            .order("created_at", desc=True) \
            .execute()
        return {"scans": response.data or []}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)