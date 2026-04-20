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
import keras

# Load environment variables
load_dotenv()

# --- Initialize the FastAPI App ---
app = FastAPI(title="Plant Pulse API")

# --- Load the ML Model and Class Indices ---
# Check current dir, then parent for AI_Model (Handles both local and Railway/Docker structures)
BASE_DIR = os.path.dirname(__file__)
MODEL_NAME = "plant_pulse_model.h5"
CLASSES_NAME = "class_indices.json"

possible_paths = [
    os.path.join(BASE_DIR, "AI_Model"),           # Inside backend
    os.path.join(BASE_DIR, "..", "AI_Model"),      # At root (Current Local Structure)
    "/app/AI_Model"                                # Docker/Railway Absolute
]

MODEL_PATH = None
CLASS_INDICES_PATH = None

for p in possible_paths:
    m_p = os.path.join(p, MODEL_NAME)
    c_p = os.path.join(p, CLASSES_NAME)
    if os.path.exists(m_p):
        MODEL_PATH = m_p
        CLASS_INDICES_PATH = c_p
        break

if not MODEL_PATH:
    # Fallback to local default if search fails
    MODEL_PATH = os.path.join(BASE_DIR, "AI_Model", MODEL_NAME)
    CLASS_INDICES_PATH = os.path.join(BASE_DIR, "AI_Model", CLASSES_NAME)

print("Loading ML Model...")
try:
    model = keras.models.load_model(MODEL_PATH)
    with open(CLASS_INDICES_PATH, "r", encoding="utf-8") as f:
        raw_data = json.load(f)
    
    # NEW: Handle list of objects format [{"id": "0", "disease_name": "..."}]
    if isinstance(raw_data, list):
        class_indices = {str(item["id"]): item["disease_name"] for item in raw_data}
    else:
        # Fallback to legacy {label: index} format
        class_indices = {str(v): k for k, v in raw_data.items()}

    print(f"Loaded {len(class_indices)} classes from {CLASSES_NAME}")
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

# ─── System / Health ────────────────────────────────────────────────────────

@app.get("/")
@app.get("/health")
async def health_check():
    return {
        "status": "online",
        "db_connected": supabase is not None,
        "mode": "production" if os.getenv("RAILWAY_ENVIRONMENT") else "development"
    }


# ─── Mock Endpoints for FYP Defense / Readiness ──────────────────────────────

@app.get("/stats")
async def get_stats():
    """Returns basic mock stats in the format expected by CropSummary model."""
    return {
        "total_scans": 0,
        "healthy_count": 0,
        "diseased_count": 0,
        "healthy_pct": 0.0,
        "diseased_pct": 0.0,
        "top_diseases": []
    }
 
@app.get("/reminders")
async def get_reminders():
    """Returns an empty list of reminders in the format expected by the app."""
    return {"reminders": [], "count": 0}

@app.post("/reminders")
async def post_reminder(payload: ReminderCreateRequest):
    """Mock endpoint for creating a reminder."""
    return {
        "success": True,
        "record_id": str(uuid.uuid4()),
        "message": "Reminder scheduled (Mock)."
    }


# ─── Treatment Database ──────────────────────────────────────────────────────

TREATMENT_DB = {
    "Apple Brown_spot": {
        "disease": "Apple Brown_spot",
        "instruction": "Remove and destroy fallen infected leaves. Spray copper fungicide or neem oil solution.",
        "dosage_per_acre": "Standard",
        "market_recommendations": [
            {
                "local_brand": "Antracol (Bayer), Score (Syngenta)",
                "company": "Local",
                "size": "Pack",
                "pkr_price": 0,
                "required_packs": 1
            }
        ]
    },
    "Apple Normal": {
        "disease": "Apple Normal",
        "instruction": "Maintain regular composting and mulching.",
        "dosage_per_acre": "Standard",
        "market_recommendations": [
            {
                "local_brand": "N/A",
                "company": "Local",
                "size": "Pack",
                "pkr_price": 0,
                "required_packs": 1
            }
        ]
    },
    "Apple black_spot": {
        "disease": "Apple black_spot",
        "instruction": "Apply sulfur-based organic sprays or Bacillus subtilis bio-fungicides.",
        "dosage_per_acre": "Standard",
        "market_recommendations": [
            {
                "local_brand": "Nativo (Bayer), Folicur (Bayer)",
                "company": "Local",
                "size": "Pack",
                "pkr_price": 0,
                "required_packs": 1
            }
        ]
    },
    "Apricot Normal": {
        "disease": "Apricot Normal",
        "instruction": "Standard organic compost application.",
        "dosage_per_acre": "Standard",
        "market_recommendations": [
            {
                "local_brand": "N/A",
                "company": "Local",
                "size": "Pack",
                "pkr_price": 0,
                "required_packs": 1
            }
        ]
    },
    "Apricot blight leaf disease": {
        "disease": "Apricot blight leaf disease",
        "instruction": "Prune out diseased wood during dry weather. Apply fixed copper sprays during dormancy.",
        "dosage_per_acre": "Standard",
        "market_recommendations": [
            {
                "local_brand": "Cobox (BASF), Daconil (Syngenta)",
                "company": "Local",
                "size": "Pack",
                "pkr_price": 0,
                "required_packs": 1
            }
        ]
    },
    "Apricot shot_hole": {
        "disease": "Apricot shot_hole",
        "instruction": "Dormant season spray of Bordeaux mixture or liquid copper fungicide.",
        "dosage_per_acre": "Standard",
        "market_recommendations": [
            {
                "local_brand": "Captan (Various local brands), Aliette (Bayer)",
                "company": "Local",
                "size": "Pack",
                "pkr_price": 0,
                "required_packs": 1
            }
        ]
    },
    "Bean Fungal_leaf disease": {
        "disease": "Bean Fungal_leaf disease",
        "instruction": "Use neem oil extract and avoid working in the field when plants are wet.",
        "dosage_per_acre": "Standard",
        "market_recommendations": [
            {
                "local_brand": "Amistar Top (Syngenta), Daconil (Syngenta)",
                "company": "Local",
                "size": "Pack",
                "pkr_price": 0,
                "required_packs": 1
            }
        ]
    },
    "Bean Normal leaf": {
        "disease": "Bean Normal leaf",
        "instruction": "Maintain soil health with organic matter.",
        "dosage_per_acre": "Standard",
        "market_recommendations": [
            {
                "local_brand": "N/A",
                "company": "Local",
                "size": "Pack",
                "pkr_price": 0,
                "required_packs": 1
            }
        ]
    },
    "Bean bean rust image": {
        "disease": "Bean bean rust image",
        "instruction": "Apply sulfur or copper-based sprays early in the season. Remove severely rusted leaves.",
        "dosage_per_acre": "Standard",
        "market_recommendations": [
            {
                "local_brand": "Tilt (Syngenta), Nativo (Bayer)",
                "company": "Local",
                "size": "Pack",
                "pkr_price": 0,
                "required_packs": 1
            }
        ]
    },
    "Bean shot_hole": {
        "disease": "Bean shot_hole",
        "instruction": "Apply copper-based bactericides/fungicides. Avoid handling wet plants.",
        "dosage_per_acre": "Standard",
        "market_recommendations": [
            {
                "local_brand": "Kocide (Corteva), Cobox (BASF)",
                "company": "Local",
                "size": "Pack",
                "pkr_price": 0,
                "required_packs": 1
            }
        ]
    },
    "Corn Fungal leaf": {
        "disease": "Corn Fungal leaf",
        "instruction": "Foliar application of compost tea or Bacillus amyloliquefaciens.",
        "dosage_per_acre": "Standard",
        "market_recommendations": [
            {
                "local_brand": "Cabrio Top (BASF), Amistar Xtra (Syngenta)",
                "company": "Local",
                "size": "Pack",
                "pkr_price": 0,
                "required_packs": 1
            }
        ]
    },
    "Corn Normal leaf": {
        "disease": "Corn Normal leaf",
        "instruction": "Maintain nitrogen levels naturally via manure.",
        "dosage_per_acre": "Standard",
        "market_recommendations": [
            {
                "local_brand": "N/A",
                "company": "Local",
                "size": "Pack",
                "pkr_price": 0,
                "required_packs": 1
            }
        ]
    },
    "Corn gray leaf spot": {
        "disease": "Corn gray leaf spot",
        "instruction": "No highly effective organic cure once established; early removal of lower infected leaves may help in small plots.",
        "dosage_per_acre": "Standard",
        "market_recommendations": [
            {
                "local_brand": "Nativo (Bayer), Tilt (Syngenta)",
                "company": "Local",
                "size": "Pack",
                "pkr_price": 0,
                "required_packs": 1
            }
        ]
    },
    "Corn holcus_ leaf spot": {
        "disease": "Corn holcus_ leaf spot",
        "instruction": "Usually cosmetic and plants recover naturally; apply copper soap if severe.",
        "dosage_per_acre": "Standard",
        "market_recommendations": [
            {
                "local_brand": "Cobox (BASF) - Copper Oxychloride",
                "company": "Local",
                "size": "Pack",
                "pkr_price": 0,
                "required_packs": 1
            }
        ]
    },
    "tomato Fusarium Wilt": {
        "disease": "tomato Fusarium Wilt",
        "instruction": "Solarize soil before planting. Use Mycorrhizal fungi and Trichoderma to protect roots.",
        "dosage_per_acre": "Standard",
        "market_recommendations": [
            {
                "local_brand": "Topsin-M (Arysta), Derosal (Bayer)",
                "company": "Local",
                "size": "Pack",
                "pkr_price": 0,
                "required_packs": 1
            }
        ]
    },
    "tomato spider mites": {
        "disease": "tomato spider mites",
        "instruction": "Spray neem oil, insecticidal soap, or release predatory mites (Phytoseiulus persimilis).",
        "dosage_per_acre": "Standard",
        "market_recommendations": [
            {
                "local_brand": "Oberon (Bayer), Agrimek (Syngenta), Pirate (BASF)",
                "company": "Local",
                "size": "Pack",
                "pkr_price": 0,
                "required_packs": 1
            }
        ]
    },
    "tomato verticillium wilt": {
        "disease": "tomato verticillium wilt",
        "instruction": "Remove and destroy affected plants. Apply compost tea to boost soil microbiome.",
        "dosage_per_acre": "Standard",
        "market_recommendations": [
            {
                "local_brand": "Topsin-M (Arysta)",
                "company": "Local",
                "size": "Pack",
                "pkr_price": 0,
                "required_packs": 1
            }
        ]
    },
    "tomato_bacterial_spot": {
        "disease": "tomato_bacterial_spot",
        "instruction": "Copper-based bactericide sprays. Do not handle plants when wet.",
        "dosage_per_acre": "Standard",
        "market_recommendations": [
            {
                "local_brand": "Cobox (BASF), Kocide (Corteva)",
                "company": "Local",
                "size": "Pack",
                "pkr_price": 0,
                "required_packs": 1
            }
        ]
    },
    "tomato_early_blight": {
        "disease": "tomato_early_blight",
        "instruction": "Prune lower leaves to prevent soil splash. Spray Bacillus subtilis or copper fungicide.",
        "dosage_per_acre": "Standard",
        "market_recommendations": [
            {
                "local_brand": "Daconil (Syngenta), Score (Syngenta), Antracol (Bayer)",
                "company": "Local",
                "size": "Pack",
                "pkr_price": 0,
                "required_packs": 1
            }
        ]
    },
    "tomato_healthy_leaf": {
        "disease": "tomato_healthy_leaf",
        "instruction": "Continue applying organic compost and worm tea.",
        "dosage_per_acre": "Standard",
        "market_recommendations": [
            {
                "local_brand": "N/A",
                "company": "Local",
                "size": "Pack",
                "pkr_price": 0,
                "required_packs": 1
            }
        ]
    },
    "tomato_late_blight": {
        "disease": "tomato_late_blight",
        "instruction": "Copper sprays can slow it down, but heavily infected plants must be uprooted and bagged immediately.",
        "dosage_per_acre": "Standard",
        "market_recommendations": [
            {
                "local_brand": "Acrobat MZ (BASF), Aliette (Bayer), Melody Duo (Bayer)",
                "company": "Local",
                "size": "Pack",
                "pkr_price": 0,
                "required_packs": 1
            }
        ]
    },
    "tomato_leaf_curl": {
        "disease": "tomato_leaf_curl",
        "instruction": "Remove and burn infected plants. Use yellow sticky traps and neem oil to control the whitefly vector.",
        "dosage_per_acre": "Standard",
        "market_recommendations": [
            {
                "local_brand": "Confidor (Bayer), Actara (Syngenta), Ulala (UPL)",
                "company": "Local",
                "size": "Pack",
                "pkr_price": 0,
                "required_packs": 1
            }
        ]
    },
    "tomato_leaf_miner": {
        "disease": "tomato_leaf_miner",
        "instruction": "Remove heavily mined leaves. Spray neem oil or Spinosad (organic formulation). Use pheromone traps.",
        "dosage_per_acre": "Standard",
        "market_recommendations": [
            {
                "local_brand": "Proclaim (Syngenta), Tracer (Corteva), Coragen (FMC)",
                "company": "Local",
                "size": "Pack",
                "pkr_price": 0,
                "required_packs": 1
            }
        ]
    },
    "tomato_leaf_mold": {
        "disease": "tomato_leaf_mold",
        "instruction": "Improve greenhouse ventilation to reduce humidity. Spray copper fungicides.",
        "dosage_per_acre": "Standard",
        "market_recommendations": [
            {
                "local_brand": "Score (Syngenta), Daconil (Syngenta)",
                "company": "Local",
                "size": "Pack",
                "pkr_price": 0,
                "required_packs": 1
            }
        ]
    },
    "tomato_septoria_leaf": {
        "disease": "tomato_septoria_leaf",
        "instruction": "Remove affected foliage immediately. Apply copper-based or potassium bicarbonate fungicidal sprays.",
        "dosage_per_acre": "Standard",
        "market_recommendations": [
            {
                "local_brand": "Antracol (Bayer), Amistar (Syngenta)",
                "company": "Local",
                "size": "Pack",
                "pkr_price": 0,
                "required_packs": 1
            }
        ]
    }
}

def normalize_label(label: str) -> str:
    """Uses exact match for new unified dataset labels."""
    return label

@app.get("/treatment/{disease_id}")
async def get_treatment(disease_id: str, acres: float = 1.0):
    normalized_key = normalize_label(disease_id)
    print(f"DEBUG: Input Label: '{disease_id}' -> Normalized Key: '{normalized_key}'")
    
    treatment = TREATMENT_DB.get(normalized_key)
    
    if not treatment:
        # Final fallback
        print(f"WARNING: No treatment found for '{normalized_key}'. Available: {list(TREATMENT_DB.keys())}")
        return {
            "disease": disease_id,
            "language": "en",
            "instruction": "Treatment data is currently unavailable for this specific disease. Please consult a local agricultural expert.",
            "dosage_per_acre": "N/A",
            "market_recommendations": []
        }
        
    # Simple adjustment for acres (packs are often per acre)
    # We clone to avoid modifying original DB
    resp = json.loads(json.dumps(treatment))
    for rec in resp["market_recommendations"]:
        rec["required_packs"] = int(np.ceil(rec["required_packs"] * acres))
        
    return resp


# ─── Inference Endpoint ──────────────────────────────────────────────────────

@app.post("/predict")
async def predict_image(file: UploadFile = File(...)):
    if model is None:
        raise HTTPException(status_code=503, detail="Model is not loaded on the server.")

    content_type = file.content_type or ""
    if not content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Only image files are accepted.")

    try:
        image_bytes = await file.read()
        if len(image_bytes) == 0:
            raise HTTPException(status_code=400, detail="Empty image received.")

        img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        img = img.resize((224, 224))
        img_array = np.array(img, dtype=np.float32) / 255.0
        img_array = np.expand_dims(img_array, axis=0)

        predictions = model.predict(img_array)
        predicted_class_index = str(np.argmax(predictions[0]))
        confidence = float(np.max(predictions[0]))

        # ─── Confidence Threshold ───────────────────────────────────────────
        # If model is less than 60% confident, reject as non-plant image
        if confidence < 0.60:
            return {
                "label": "Unknown - Please scan a clear plant leaf",
                "confidence": confidence,
            }
        # ────────────────────────────────────────────────────────────────────

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

class ScanHistoryPayload(BaseModel):
    user_id: str
    crop_name: str
    disease_result: str
    confidence_score: float

@app.post("/history/save")
async def save_scan(scan_data: ScanHistoryPayload):
    if supabase is None:
        raise HTTPException(status_code=503, detail="Database unavailable.")
    try:
        response = supabase.table("scan_history").insert(scan_data.model_dump()).execute()
        return {"status": "saved", "data": response.data}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/history/{user_id}")
async def get_history(user_id: str):
    if supabase is None:
        return {"scans": []}
    try:
        response = supabase.table("scan_history").select("*").eq("user_id", user_id).order("created_at", desc=True).execute()
        return {"scans": response.data}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)