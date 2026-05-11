import tensorflow as tf
import os
from dotenv import load_dotenv
load_dotenv()

import numpy as np
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import json
import logging
from pydantic import BaseModel
from typing import List, Optional
from inference_server import RiceInferenceEngine
from datetime import datetime
from supabase import create_client, Client

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("PlantPulse-Backend")

# --- SUPABASE CONFIG ---
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

supabase: Client = None
if SUPABASE_URL and SUPABASE_KEY:
    try:
        supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
        logger.info("SUCCESS: Supabase client: READY")
    except Exception as e:
        logger.error(f"FAILED: Supabase client initialization: {e}")

# ══════════════════════════════════════════════════════════════════════════════
#  PLANT PULSE RICE-TFLITE — PRODUCTION PIPELINE
# ══════════════════════════════════════════════════════════════════════════════

app = FastAPI(title="PlantPulse_Rice_API_v1.2")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- 1. MODEL CONFIGURATION ---

CATEGORIES = [
    'bacterial_leaf_blight', 
    'brown_spot', 
    'healthy', 
    'leaf_blast', 
    'leaf_scald', 
    'narrow_brown_spot', 
    'not_rice'
]

MODEL_PATH = os.path.join(
    os.path.dirname(__file__), 
    "AI_Model", 
    "model_v2.tflite"
)

# --- 2. DATA SCHEMAS ---

class HistorySave(BaseModel):
    user_id: str
    crop_name: str
    disease_result: str
    confidence_score: float

class ReminderCreate(BaseModel):
    user_id: str
    plant_name: str
    disease_name: str
    treatment_type: str
    scheduled_time: str

class ProfileSync(BaseModel):
    user_id: str
    full_name: str
    phone: str
    location: str

# --- 3. CORE LOGIC ---

try:
    engine = RiceInferenceEngine(MODEL_PATH, categories=CATEGORIES)
except Exception as e:
    logger.error(f"Failed to load AI Engine: {e}")
    engine = None

with open(os.path.join(os.path.dirname(__file__), "AI_Model", "causal_rules.json"), "r", encoding="utf-8") as f:
    EXPERT_RULES = json.load(f)

# --- 3b. PLANT IDENTIFICATION MODEL ---

PLANT_MODEL_PATH = os.path.join(
    os.path.dirname(__file__),
    "AI_Model",
    "plant_model.tflite"
)

PLANT_LABELS_PATH = os.path.join(
    os.path.dirname(__file__),
    "AI_Model",
    "plant_identification_class_indices.json"
)

PLANT_RULES_PATH = os.path.join(
    os.path.dirname(__file__),
    "AI_Model",
    "Plant_Identification_Model_casual_rule.json"
)

plant_engine = None
plant_idx_to_class = {}
plant_rules = {}

try:
    plant_engine = RiceInferenceEngine(
        PLANT_MODEL_PATH,
        labels_path=PLANT_LABELS_PATH,
    )
    logger.info("SUCCESS: Plant Identification engine loaded.")
except Exception as e:
    logger.error(f"Failed to load Plant Identification engine: {e}")

try:
    with open(PLANT_LABELS_PATH, "r", encoding="utf-8") as f:
        plant_idx_to_class = json.load(f)
    with open(PLANT_RULES_PATH, "r", encoding="utf-8") as f:
        plant_rules = json.load(f)
    logger.info(f"SUCCESS: Plant ID labels ({len(plant_idx_to_class)}) and rules ({len(plant_rules)}) loaded.")
except Exception as e:
    logger.error(f"Failed to load plant labels/rules: {e}")

# --- 4. ENDPOINTS ---

@app.get("/health")
async def health():
    return {
        "status": "online",
        "engine": "READY" if engine else "OFFLINE",
        "database": "CONNECTED" if supabase else "OFFLINE"
    }

@app.post("/predict")
async def predict(file: UploadFile = File(...)):
    if not engine:
        raise HTTPException(status_code=500, detail="AI Engine not initialized")
    
    try:
        contents = await file.read()
        result = engine.predict(contents)
        return result
    except Exception as e:
        logger.error(f"Inference error: {e}")
        raise HTTPException(status_code=400, detail=str(e))

@app.post("/identify")
async def identify_plant(file: UploadFile = File(...)):
    if not plant_engine:
        raise HTTPException(status_code=500, detail="Plant Identification Engine not initialized")
    
    try:
        contents = await file.read()
        result = plant_engine.predict(contents)
        
        class_name = result.get("class_name", "unknown")
        confidence = result.get("confidence", 0.0)
        
        # Look up detailed info from plant rules JSON
        rule = plant_rules.get(class_name, {})
        
        return {
            "status": "success",
            "plant_name": rule.get("name_en", class_name.replace("_", " ").title()),
            "scientific_name": rule.get("scientific_name", "N/A"),
            "category": class_name,
            "description": rule.get("details", "No description available."),
            "growing_tips": rule.get("care_tips", "No tips available."),
            "confidence": confidence,
            "predicted_index": result.get("predicted_index", -1),
        }
    except Exception as e:
        logger.error(f"Plant identification error: {e}")
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/treatment/{disease_id}")
async def get_treatment(disease_id: str, acres: float = 1.0):
    rule = EXPERT_RULES.get(disease_id)
    if not rule:
        raise HTTPException(status_code=404, detail="Disease guidelines not found")
    
    # Simple acreage scaling for quantity
    quantity = f"{acres * 100}ml" if "liquid" in rule['treatment_en'].lower() else f"{acres * 0.5}kg"
    
    return {
        "id": disease_id,
        "name_en": rule.get('name_en', 'Unknown'),
        "name_ur": rule.get('name_ur', 'نامعلوم'),
        "description_en": rule.get('description_en') or rule.get('symptoms', 'No description available.'),
        "treatment_en": rule.get('treatment_en', 'No treatment guidelines found.'),
        "treatment_ur": rule.get('treatment_ur', 'علاج کی ہدایات نہیں ملیں۔'),
        "quantity": quantity
    }

# --- 5. HISTORY & REMINDERS (SUPABASE) ---

@app.post("/history/save")
async def save_history(data: HistorySave):
    if not supabase:
        # Fallback for offline mode if needed, but here we expect Supabase
        return {"status": "mock_success", "note": "Database offline, using dummy mode"}
    
    try:
        res = supabase.table("scan_history").insert({
            "user_id":          data.user_id,
            "crop_name":        data.crop_name,
            "disease_result":   data.disease_result,
            "confidence_score": data.confidence_score,
            "created_at":       datetime.now().isoformat()
        }).execute()
        return {"status": "success", "sync_id": res.data[0]['id'] if res.data else "local_only"}
    except Exception as e:
        logger.error(f"save_history error: {e}")
        return {"status": "error", "detail": str(e)}

@app.get("/history/{user_id}")
async def get_history(user_id: str):
    if not supabase:
        return {"scans": []}
    
    try:
        res = supabase.table("scan_history") \
            .select("*") \
            .eq("user_id", user_id) \
            .order("created_at", desc=True) \
            .execute()
        return {"scans": res.data}
    except Exception as e:
        logger.error(f"get_history error: {e}")
        return {"scans": []}

@app.get("/reminders")
async def get_reminders(user_id: str):
    if not supabase:
        return {"reminders": []}
    
    try:
        res = supabase.table("spray_reminders") \
            .select("*") \
            .eq("user_id", user_id) \
            .eq("is_completed", False) \
            .order("scheduled_time") \
            .execute()
        return {"reminders": res.data}
    except Exception as e:
        logger.error(f"get_reminders error: {e}")
        return {"reminders": []}

@app.post("/reminders")
async def create_reminder(data: ReminderCreate):
    if not supabase:
        raise HTTPException(status_code=503, detail="Database offline")
    
    try:
        res = supabase.table("spray_reminders").insert({
            "user_id":        data.user_id,
            "plant_name":     data.plant_name,
            "disease_name":   data.disease_name,
            "treatment_type": data.treatment_type,
            "scheduled_time": data.scheduled_time,
            "is_completed":   False
        }).execute()
        
        if res.data:
            return {"status": "success", "record_id": res.data[0]['id']}
        raise Exception("Insert failed")
    except Exception as e:
        logger.error(f"create_reminder error: {e}")
        raise HTTPException(status_code=400, detail=str(e))

@app.patch("/reminders/{reminder_id}/complete")
async def mark_reminder_complete(reminder_id: str, user_id: str):
    if not supabase:
        raise HTTPException(status_code=503, detail="Database offline")
    
    try:
        supabase.table("spray_reminders") \
            .update({"is_completed": True}) \
            .eq("id", reminder_id) \
            .eq("user_id", user_id) \
            .execute()
        return {"status": "success"}
    except Exception as e:
        logger.error(f"mark_reminder_complete error: {e}")
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/stats")
async def get_stats(user_id: str):
    if not supabase:
        return {"total_scans": 0, "healthy_count": 0, "diseased_count": 0}
    
    try:
        # Fetch all scans for this user
        res = supabase.table("scan_history").select("*").eq("user_id", user_id).execute()
        scans = res.data or []
        
        total = len(scans)
        healthy = len([s for s in scans if s['disease_result'].lower() == 'healthy'])
        diseased = total - healthy
        
        # Calculate percentages
        healthy_pct = (healthy / total * 100) if total > 0 else 0
        diseased_pct = (diseased / total * 100) if total > 0 else 0
        
        # Identify top diseases
        counts = {}
        for s in scans:
            d = s['disease_result']
            if d.lower() != 'healthy':
                counts[d] = counts.get(d, 0) + 1
        
        top_diseases = sorted(counts.items(), key=lambda x: x[1], reverse=True)[:3]
        
        return {
            "total_scans": total,
            "healthy_count": healthy,
            "diseased_count": diseased,
            "healthy_pct": round(healthy_pct, 1),
            "diseased_pct": round(diseased_pct, 1),
            "top_diseases": [d[0] for d in top_diseases]
        }
    except Exception as e:
        logger.error(f"get_stats error: {e}")
        return {"total_scans": 0, "healthy_count": 0, "diseased_count": 0}

@app.get("/profile/{user_id}")
async def get_profile(user_id: str):
    if not supabase:
        return {"full_name": "Farmer", "phone": "", "location": "Punjab"}
    
    try:
        res = supabase.table("profiles").select("*").eq("id", user_id).single().execute()
        return res.data if res.data else {"full_name": "Farmer", "phone": "", "location": "Punjab"}
    except:
        return {"full_name": "Farmer", "phone": "", "location": "Punjab"}

@app.post("/profile/sync")
async def sync_profile(data: ProfileSync):
    if not supabase:
        return {"status": "mock_success"}
    
    try:
        supabase.table("profiles").upsert({
            "id":        data.user_id,
            "full_name": data.full_name,
            "phone":     data.phone,
            "location":  data.location,
            "updated_at": datetime.now().isoformat()
        }).execute()
        return {"status": "success"}
    except Exception as e:
        logger.error(f"sync_profile error: {e}")
        return {"status": "error", "detail": str(e)}
