from fastapi import FastAPI, HTTPException, Header, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, validator
from supabase import create_client, Client
from enum import Enum
import os
import random
import uuid
from dotenv import load_dotenv
from typing import Optional, Set, Dict

# Load environment variables
load_dotenv()

# ─── Endpoints ───────────────────────────────────────────────────────────────

@app.get("/health")
async def health_check():
    """
    Returns API status and database connectivity info.
    Mobile app uses this to show 'Database Offline' warnings.
    """
    return {
        "status": "online",
        "db_connected": supabase is not None,
        "mode": "production" if os.getenv("RAILWAY_ENVIRONMENT") else "development"
    }

    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Connect to Supabase
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_ANON_KEY")

supabase: Optional[Client] = None

if not SUPABASE_URL or not SUPABASE_KEY:
    print("Warning: Supabase credentials missing. Running in OFFLINE mode.")
else:
    try:
        # Use Service Role Key to bypass RLS in backend logic if required
        supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
        print("Backend: Supabase Connected")
    except Exception as e:
        print(f"Warning: Supabase Initialization Failed ({e}). Running in OFFLINE mode with local data.")
        supabase = None


# ─── Agricultural Data Dictionary ────────────────────────────────────────────
# Strict Enum + Mapping ensures only scientifically valid crop/disease pairs
# reach the database. Garbage data is rejected at the API boundary (422).

class CropType(str, Enum):
    APPLE        = "Apple"
    CHERRY       = "Cherry"
    CORN         = "Corn (Maize)"
    GRAPE        = "Grape"
    PEACH        = "Peach"
    PEPPER_BELL  = "Pepper (Bell)"
    POTATO       = "Potato"
    RICE         = "Rice"
    SOYBEAN      = "Soybean"
    STRAWBERRY   = "Strawberry"
    TOMATO       = "Tomato"
    WHEAT        = "Wheat"


VALID_CROP_DISEASES: dict[CropType, Set[str]] = {
    CropType.APPLE:       {"Apple Scab", "Black Rot", "Cedar Apple Rust", "Healthy"},
    CropType.CHERRY:      {"Powdery Mildew", "Healthy"},
    CropType.CORN:        {"Cercospora Leaf Spot", "Common Rust", "Northern Leaf Blight", "Healthy"},
    CropType.GRAPE:       {"Black Rot", "Esca (Black Measles)", "Leaf Blight", "Healthy"},
    CropType.PEACH:       {"Bacterial Spot", "Healthy"},
    CropType.PEPPER_BELL: {"Bacterial Spot", "Healthy"},
    CropType.POTATO:      {"Early Blight", "Late Blight", "Healthy"},
    CropType.RICE:        {"Brown Spot", "Hispa", "Leaf Blast", "Healthy"},
    CropType.SOYBEAN:     {"Caterpillar Damage", "Diabrotica Speciosa", "Healthy"},
    CropType.STRAWBERRY:  {"Leaf Scorch", "Healthy"},
    CropType.TOMATO: {
        "Bacterial Spot", "Early Blight", "Late Blight", "Leaf Mold",
        "Septoria Leaf Spot", "Spider Mites (Two-Spotted)", "Target Spot",
        "Yellow Leaf Curl Virus", "Mosaic Virus", "Healthy",
    },
    CropType.WHEAT:       {"Brown Rust", "Yellow Rust", "Healthy"},
}

# --- BACKEND LOGIC: Treatment Mapping & PKR Calculation ---
# Moving logic from Flutter (treatment_service.dart) to FastAPI

TREATMENT_DATA = {
    "Tomato___Late_blight": {
        "en": {
            "solution": "Apply a mixture of 1 tbsp baking soda and 1 tsp liquid soap in 1 liter of water.",
            "notes": "Spray during cool hours. Repeat every 7-10 days if humidity persists."
        },
        "ur": {
            "solution": "ایک لیٹر پانی میں 1 کھانے کا چمچ بیکنگ سوڈا اور 1 چائے کا چمچ مائع صابن ملا کر سپرے کریں۔",
            "notes": "ٹھنڈے اوقات میں سپرے کریں۔ نمی برقرار رہنے کی صورت میں ہر 7-10 دن بعد دہرائیں۔"
        },
        "dosage_per_acre_g": 500,
        "products": [
            {"name": "Antracol", "company": "Bayer", "size": "500g", "price": 1850},
            {"name": "Fruton", "company": "Engro", "size": "250g", "price": 950},
        ]
    },
    "Tomato___Early_blight": {
        "en": {
            "solution": "Use copper-based organic spray or Neem oil (5ml per liter).",
            "notes": "Remove lower infected leaves before spraying."
        },
        "ur": {
            "solution": "کاپر پر مبنی نامیاتی سپرے یا نیم کا تیل (5 ملی لیٹر فی لیٹر) استعمال کریں۔",
            "notes": "سپرے کرنے سے پہلے نیچے کے متاثرہ پتے ہٹا دیں۔"
        },
        "dosage_per_acre_g": 400,
        "products": [
            {"name": "Cabrio Top", "company": "BASF", "size": "250g", "price": 2400},
            {"name": "Polyram", "company": "Jaffar Bros", "size": "500g", "price": 1600},
        ]
    },
     "Tomato___Leaf_Miner": {
        "en": {
            "solution": "Install yellow sticky traps and use Neem oil spray.",
            "notes": "Apply at the first sign of winding tunnels in leaves."
        },
        "ur": {
            "solution": "پیلی چپکنے والی جالیاں (Sticky Traps) لگائیں اور نیم کے تیل کا سپرے کریں۔",
            "notes": "پتوں میں بل کھاتی ہوئی سرنگوں کی پہلی علامت پر استعمال کریں۔"
        },
        "dosage_per_acre_g": 350,
        "products": [
            {"name": "Coragen", "company": "FMC", "size": "50ml", "price": 2800},
            {"name": "Belt", "company": "Bayer", "size": "50ml", "price": 3200},
        ]
    },
    "Potato___Late_blight": {
        "en": {
            "solution": "Destroy infected tubers and apply copper manure.",
            "notes": "Ensure full coverage of both upper and lower leaf surfaces."
        },
        "ur": {
            "solution": "متاثرہ آلوؤں کو تلف کریں اور کاپر پر مبنی قدرتی کھاد ڈالیں۔",
            "notes": "پتوں کی اوپری اور نچلی دونوں سطحوں پر مکمل کوریج کو یقینی بنائیں۔"
        },
        "dosage_per_acre_g": 600,
        "products": [
            {"name": "Revus", "company": "Syngenta", "size": "250ml", "price": 3500},
            {"name": "Ridomil Gold", "company": "Syngenta", "size": "500g", "price": 2900},
        ]
    },
    "Corn_(maize)___Common_rust_": {
        "en": {
            "solution": "Improve air circulation and avoid overhead watering.",
            "notes": "Apply preventative spray if cool, wet weather is forecast."
        },
        "ur": {
            "solution": "ہوا کی نکاسی کو بہتر بنائیں اور اوپر سے پانی دینے سے گریز کریں۔",
            "notes": "اگر ٹھنڈے اور ابر آلود موسم کی پیش گوئی ہو تو حفاظتی اسپرے کریں۔"
        },
        "dosage_per_acre_g": 300,
        "products": [
            {"name": "Tilt", "company": "Syngenta", "size": "100ml", "price": 2200},
            {"name": "Nativo", "company": "Bayer", "size": "100g", "price": 4500},
        ]
    }
}

# ─── New Models for Phase 8 Architecture ──────────────────────────────────────

class ProfileUpdate(BaseModel):
    user_id: str
    full_name: Optional[str] = ""
    phone: Optional[str] = ""
    location: Optional[str] = ""

            "notes": "ٹھنڈے اور برساتی موسم کی پیش گوئی کی صورت میں حفاظتی سپرے کریں۔"
        },
        "dosage_per_acre_g": 450,
        "products": [
            {"name": "Tilt", "company": "Syngenta", "size": "100ml", "price": 1450},
            {"name": "Nativo", "company": "Bayer", "size": "100g", "price": 2200},
        ]
    }
}

def calculate_pkr_price(products, acres: float):
    """
    Enhanced PKR Price Calculation.
    Assuming price is per pack and usage is normalized.
    """
    results = []
    for p in products:
        # Simple estimate: assume 1 pack per acre for now, or based on product size
        total_pkr = p['price'] * acres
        results.append({
            **p,
            "total_estimated_pkr": total_pkr,
            "required_packs": acres # Simple 1:1 for demonstration
        })
    return results

@app.get("/")
@app.get("/health")
async def health_check():
    return {"status": "Plant Pulse API is Online", "database": "connected" if SUPABASE_URL else "disconnected"}


# --- Disease labels the model can detect ---
MODEL_LABELS = [
    "Tomato___Late_blight",
    "Tomato___Early_blight",
    "Tomato___Leaf_Miner",
    "Potato___Late_blight",
    "Corn_(maize)___Common_rust_",
    "Tomato___healthy",
    "Potato___healthy",
]

@app.post("/scan")
async def scan_image(file: UploadFile = File(...)):
    """
    Image Disease Detection Endpoint.
    Accepts a multipart image upload and returns disease label + confidence.
    
    TODO: Replace mock logic with real TFLite/ONNX server-side inference
    when the trained model is deployed to this backend.
    """
    # Validate file type
    content_type = file.content_type or ""
    if not content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Only image files are accepted.")

    # Read image bytes (for future real inference)
    image_bytes = await file.read()
    if len(image_bytes) == 0:
        raise HTTPException(status_code=400, detail="Empty image received.")

    # --- MOCK INFERENCE ---
    # Returns realistic predictions for FYP demo.
    # Replace this block with actual model.predict(image_bytes) when model is ready.
    diseased_labels = [l for l in MODEL_LABELS if "healthy" not in l]
    label = random.choice(diseased_labels)
    confidence = round(random.uniform(0.72, 0.96), 4)

    return {
        "label": label,
        "confidence": confidence,
        "source": "fastapi_mock",
    }


@app.post("/predict")
async def predict_image(file: UploadFile = File(...)):
    """
    Primary inference endpoint consumed by the Flutter app (scanner_screen.dart).
    Accepts a multipart/form-data image upload and returns disease prediction.

    Mock response: returns a fixed Tomato Early Blight result for end-to-end
    flow testing while the real Kaggle-trained model is being finalised.
    Replace the return block with actual model inference when ready.
    """
    # Validate file type
    content_type = file.content_type or ""
    if not content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Only image files are accepted.")

    # Read and validate image bytes
    image_bytes = await file.read()
    if len(image_bytes) == 0:
        raise HTTPException(status_code=400, detail="Empty image received.")

    # --- MOCK RESPONSE ---
    # Fixed result for full app-flow testing.
    # TODO: replace with real model inference once Kaggle training is complete.
    return {
        "label": "Tomato___Early_blight",
        "confidence": 0.91,
    }

@app.get("/treatment/{disease_id}")
async def get_treatment_data(disease_id: str, acres: float = 1.0, lang: Optional[str] = Header("en")):
    """
    Bilingual Endpoint: Returns localized strings and calculated prices.
    """
    # Normalize lang
    lang = "ur" if lang and "ur" in lang.lower() else "en"
    
    # 1. Try fetching from Supabase (Mirroring logic if table exists, otherwise fallback to TREATMENT_DATA)
    try:
        # If disease_id is a label string
        data = TREATMENT_DATA.get(disease_id)
        
        if not data:
            # Try numeric lookup if Supabase is connected
            if SUPABASE_URL:
                response = supabase.table('treatments').select("*").eq('disease_id', disease_id).single().execute()
                if response.data:
                    # Map Supabase response to our format
                    # This is a sample mapping, actual depend on schema
                    return response.data

            raise HTTPException(status_code=404, detail="Treatment not found in Knowledge Base")

        # 2. Localized content selection
        localized = data.get(lang)
        
        # 3. Instruction Merging
        instruction = f"{localized['solution']}\n\n{localized['notes']}"
        
        # 4. Price Calculation & Key Alignment
        acres = max(0.5, acres) # Safety
        processed_products = []
        for p in data['products']:
            total_pkr = p['price'] * acres
            processed_products.append({
                "local_brand": p['name'],
                "company": p['company'],
                "size": p['size'],
                "pkr_price": total_pkr,
                "required_packs": int(acres) if acres >= 1 else 1
            })
        
        return {
            "disease": disease_id,
            "language": lang,
            "instruction": instruction,
            "dosage_per_acre": f"{data['dosage_per_acre_g']}g",
            "market_recommendations": processed_products
        }

    except Exception as e:
        if isinstance(e, HTTPException): raise e
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {str(e)}")


# ─── Scan History ─────────────────────────────────────────────────────────────

class ScanResultCreate(BaseModel):
    """
    Strictly-validated payload for saving scan results.

    - crop_name      : Must be a known CropType enum value (e.g. "Tomato").
                       Unknown crops are rejected with HTTP 422 automatically.
    - disease_result : Must exist in the valid disease set for that crop.
                       Cross-contamination (e.g. Tomato + Cedar Apple Rust) is blocked.
    - confidence_score: Clamped to [0.0, 1.0].
    """
    user_id:         str
    crop_name:       CropType        # enum — FastAPI validates automatically
    disease_result:  str
    confidence_score: float

    @validator("disease_result")
    def validate_disease_for_crop(cls, v: str, values: dict) -> str:
        crop: CropType | None = values.get("crop_name")
        if crop is not None:
            valid = VALID_CROP_DISEASES.get(crop, set())
            if v not in valid:
                raise ValueError(
                    f"Disease '{v}' is not valid for crop '{crop.value}'. "
                    f"Valid options: {sorted(valid)}"
                )
        return v

    @validator("confidence_score")
    def clamp_confidence(cls, v: float) -> float:
        if not (0.0 <= v <= 1.0):
            raise ValueError("confidence_score must be between 0.0 and 1.0")
        return round(v, 6)


@app.post("/api/v1/scans/save")
async def save_scan(payload: ScanResultCreate):
    """
    Securely persists a validated scan into the Supabase scan_history table.

    Validation chain (all automatic before this function body runs):
      1. crop_name must be a known CropType value → 422 if not
      2. disease_result must belong to that crop's disease set → 422 if not
      3. confidence_score must be in [0.0, 1.0] → 422 if not

    Returns the new record's UUID on success.
    Raises HTTP 503 if Supabase is not configured (offline mode).
    """
    if supabase is None:
        raise HTTPException(
            status_code=503,
            detail="Database unavailable — running in offline mode."
        )

    if not payload.user_id or not payload.user_id.strip():
        raise HTTPException(status_code=400, detail="user_id is required.")

    record_id = str(uuid.uuid4())

    try:
        response = supabase.table("scan_history").insert({
            "id":               record_id,
            "user_id":          payload.user_id.strip(),
            "plant_name":       payload.crop_name.value,   # canonical casing from Enum
            "disease_result":   payload.disease_result,    # already validated
            "confidence_score": payload.confidence_score,  # already clamped
        }).execute()

        data = response.data
        if not data:
            raise HTTPException(status_code=500, detail="Insert returned no data.")

        return {
            "success":   True,
            "record_id": record_id,
            "message":   "Scan saved to history.",
        }

    except HTTPException:
        raise
    except Exception as e:
        print(f"[scan_history] insert failed: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to save scan: {str(e)}")


# ─── Crop Statistics ──────────────────────────────────────────────────────────

@app.get("/api/v1/stats/crop-summary")
async def crop_summary(user_id: str):
    """
    Aggregates scan_history for the specified user and returns:
      - total_scans
      - healthy_count / diseased_count + percentages
      - top_diseases: list of {disease, count, percentage} sorted desc

    Query param: user_id (Supabase auth UID)
    """
    if supabase is None:
        raise HTTPException(
            status_code=503,
            detail="Database unavailable — running in offline mode."
        )

    if not user_id or not user_id.strip():
        raise HTTPException(status_code=400, detail="user_id is required.")

    try:
        # Fetch all scans for this user (only needed columns)
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

        # ── Healthy vs Diseased ────────────────────────────────────────────
        healthy_count = sum(
            1 for r in rows
            if "healthy" in r.get("disease_result", "").lower()
        )
        diseased_count = total_scans - healthy_count

        def pct(n): return round((n / total_scans) * 100, 1)

        # ── Disease frequency map ──────────────────────────────────────────
        freq: dict[str, int] = {}
        for r in rows:
            label = r.get("disease_result", "Unknown")
            # Exclude healthy entries from disease breakdown
            if "healthy" not in label.lower():
                freq[label] = freq.get(label, 0) + 1

        top_diseases = sorted(
            [
                {
                    "disease":    label,
                    "count":      count,
                    "percentage": pct(count),
                }
                for label, count in freq.items()
            ],
            key=lambda x: x["count"],
            reverse=True,
        )[:10]  # cap at top-10

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
        print(f"[crop_summary] query failed: {e}")
        raise HTTPException(status_code=500, detail=f"Stats query failed: {str(e)}")


# ─── Spray Reminders ──────────────────────────────────────────────────────────

class ReminderCreateRequest(BaseModel):
    """
    Payload to schedule a new spray reminder.
    scheduled_time must be a valid ISO-8601 datetime string (UTC preferred).
    """
    user_id:        str
    plant_name:     str
    disease_name:   str
    treatment_type: str
    scheduled_time: str   # ISO-8601 e.g. "2025-04-15T09:00:00Z"


@app.post("/api/v1/reminders/create")
async def create_reminder(payload: ReminderCreateRequest):
    """
    Inserts a new spray reminder into the spray_reminders table.
    Returns the new record's UUID.
    """
    if supabase is None:
        raise HTTPException(status_code=503, detail="Database unavailable.")

    if not payload.user_id.strip():
        raise HTTPException(status_code=400, detail="user_id is required.")

    # Basic ISO string validation — supabase will raise if format is wrong
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
        print(f"[reminders/create] failed: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to create reminder: {str(e)}")


@app.get("/api/v1/reminders/active")
async def get_active_reminders(user_id: str):
    """
    Returns all upcoming (is_completed=false, scheduled_time >= now) reminders
    for the specified user, ordered by scheduled_time ascending.
    """
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
        print(f"[reminders/active] failed: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to fetch reminders: {str(e)}")


@app.patch("/api/v1/reminders/{reminder_id}/complete")
async def complete_reminder(reminder_id: str, user_id: str):
    """
    Marks a specific reminder as completed.
    user_id is required to ensure the user owns the reminder.
    """
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
        print(f"[reminders/complete] failed: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to complete reminder: {str(e)}")


# ─── Profile Management ──────────────────────────────────────────────────────

@app.get("/api/v1/profile/{user_id}")
async def get_user_profile(user_id: str):
    """
    Fetches user profile data from the 'profiles' table.
    """
    if supabase is None:
        raise HTTPException(status_code=503, detail="Database unavailable.")

    try:
        response = supabase.table("profiles").select("*").eq("id", user_id).execute()
        if not response.data:
            # Return empty skeleton so UI doesn't crash
            return {"id": user_id, "full_name": "", "phone": "", "location": ""}
        return response.data[0]
    except Exception as e:
        print(f"[profile/get] failed: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to fetch profile: {str(e)}")

@app.post("/api/v1/profile/sync")
async def sync_user_profile(payload: ProfileUpdate):
    """
    Upserts user profile data (name, phone, location).
    """
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

        # Supabase UPSERT based on 'id' primary key
        response = supabase.table("profiles").upsert(data).execute()

        if not response.data:
            raise HTTPException(status_code=500, detail="Profile sync failed.")

        return {"success": True, "message": "Profile synced successfully."}
    except Exception as e:
        print(f"[profile/sync] failed: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to sync profile: {str(e)}")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
