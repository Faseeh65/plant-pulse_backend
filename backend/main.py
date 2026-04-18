from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, field_validator
from supabase import create_client, Client
import os
import uuid
from dotenv import load_dotenv
from typing import Optional
from PIL import Image
import io
import json
import numpy as np
import keras

# Load environment variables
load_dotenv()

# --- Initialize the FastAPI App ---
app = FastAPI(title="Plant Pulse API")

# --- Load the ML Model and Class Indices ---
MODEL_PATH = os.path.join(os.path.dirname(__file__), "AI_Model", "plant_pulse_model.h5")
CLASS_INDICES_PATH = os.path.join(os.path.dirname(__file__), "AI_Model", "class_indices.json")

print("Loading ML Model...")
try:
    model = keras.models.load_model(MODEL_PATH)
    with open(CLASS_INDICES_PATH, "r") as f:
        class_indices = json.load(f)
    print("Model and class indices loaded successfully.")
except Exception as e:
    print(f"Warning: Failed to load model or class indices: {e}")
    model = None
    class_indices = {}

# --- Configure CORS Middleware ---
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], 
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── Supabase Configuration ──────────────────────────────────────────────────

# ADD YOUR SUPABASE KEYS HERE (reads from .env file or Railway Variables)
SUPABASE_URL = os.getenv("SUPABASE_URL")        # e.g. https://xyz.supabase.co
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

# ─── System / Health ────────────────────────────────────────────────────────

@app.get("/")
@app.get("/health")
async def health_check():
    return {
        "status": "online",
        "db_connected": supabase is not None,
        "mode": "production" if os.getenv("RAILWAY_ENVIRONMENT") else "development"
    }


# ─── Inference Endpoint ──────────────────────────────────────────────────────

@app.post("/predict")
async def predict_image(file: UploadFile = File(...)):
    """
    Live inference endpoint.
    Accepts a multipart/form-data image upload, resizes to 224x224,
    rescales by 1/255, and returns the disease prediction mapped from JSON labels.
    """
    if model is None:
        raise HTTPException(status_code=503, detail="Model is not loaded on the server.")

    content_type = file.content_type or ""
    if not content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Only image files are accepted.")

    try:
        image_bytes = await file.read()
        if len(image_bytes) == 0:
            raise HTTPException(status_code=400, detail="Empty image received.")

        # Preprocess the image
        img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        img = img.resize((224, 224))
        
        # Rescale exactly as requested (1/255.0)
        img_array = np.array(img, dtype=np.float32) / 255.0
        img_array = np.expand_dims(img_array, axis=0) # Add batch dimension

        # Predict
        predictions = model.predict(img_array)
        predicted_class_index = str(np.argmax(predictions[0]))
        confidence = float(np.max(predictions[0]))

        # Map to actual string name
        disease_name = class_indices.get(predicted_class_index, "Unknown")

        return {
            "label": disease_name,
            "confidence": confidence,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Inference processing error: {str(e)}")


# ─── Core Models ─────────────────────────────────────────────────────────────

class ProfileUpdate(BaseModel):
    user_id: str
    full_name: Optional[str] = ""
    phone: Optional[str] = ""
    location: Optional[str] = ""

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
async def save_scan(payload: ScanResultCreate):
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
async def crop_summary(user_id: str):
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
                "total_scans":       0,
                "healthy_count":     0,
                "diseased_count":    0,
                "healthy_pct":       0.0,
                "diseased_pct":      0.0,
                "top_diseases":      [],
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


# ─── Spray Reminders API ─────────────────────────────────────────────────────

@app.post("/api/v1/reminders/create")
async def create_reminder(payload: ReminderCreateRequest):
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
async def get_active_reminders(user_id: str):
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
async def complete_reminder(reminder_id: str, user_id: str):
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

@app.get("/api/v1/profile/{user_id}")
async def get_user_profile(user_id: str):
    if supabase is None:
        raise HTTPException(status_code=503, detail="Database unavailable.")

    try:
        response = supabase.table("profiles").select("*").eq("id", user_id).execute()
        if not response.data:
            return {"id": user_id, "full_name": "", "phone": "", "location": ""}
        return response.data[0]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch profile: {str(e)}")

@app.post("/api/v1/profile/sync")
async def sync_user_profile(payload: ProfileUpdate):
    if supabase is None:
        raise HTTPException(status_code=503, detail="Database unavailable.")

    if not payload.user_id:
        raise HTTPException(status_code=400, detail="user_id is required.")

    try:
        data = {
            "id": payload.user_id,
            "full_name": payload.full_name,
            "phone": payload.phone,
            "location": payload.location,
            "updated_at": "now()"
        }

        response = supabase.table("profiles").upsert(data).execute()

        if not response.data:
            raise HTTPException(status_code=500, detail="Profile sync failed.")

        return {"success": True, "message": "Profile synced successfully."}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to sync profile: {str(e)}")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
