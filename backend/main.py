import tensorflow as tf
import os
import numpy as np
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
import json
import logging
from pydantic import BaseModel
from typing import List, Optional
from inference_server import RiceInferenceEngine
from datetime import datetime

# ══════════════════════════════════════════════════════════════════════════════
#  PLANT PULSE RICE-TFLITE — PRODUCTION PIPELINE
# ══════════════════════════════════════════════════════════════════════════════

load_dotenv()

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("PlantPulse-Backend")

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
    'AI_Model', 'model_v2.tflite'
)

# Initialize Engine (Now supports multi-input internally)
logger.info("Initializing RiceInferenceEngine...")
try:
    engine = RiceInferenceEngine(MODEL_PATH, categories=CATEGORIES)
    logger.info("SUCCESS: RiceInferenceEngine status: READY")
except Exception as e:
    logger.critical(f"FATAL ERROR: RiceInferenceEngine failed to initialize: {e}")
    import sys
    sys.exit(1)

# Load Expert System rules
CAUSAL_RULES_PATH = os.path.join(os.path.dirname(__file__), "AI_Model", "causal_rules.json")
causal_rules: dict = {}
try:
    if os.path.exists(CAUSAL_RULES_PATH):
        with open(CAUSAL_RULES_PATH, "r", encoding='utf-8') as f:
            causal_rules = json.load(f)
        logger.info("SUCCESS: Expert System rules: READY")
except Exception as e:
    logger.error(f"FAILED: Expert System rules: FAILED | Error: {e}")

LOAD_TIME = datetime.now().isoformat()

# --- 2. SCHEMAS ---
class HistorySave(BaseModel):
    user_id: str
    crop_name: str
    disease_result: str
    confidence_score: float
    metadata: Optional[dict] = None

# --- 3. ENDPOINTS ---

@app.get("/health")
async def health():
    return {
        "status": "online",
        "SYNC_CHECK_ID": "RICE_NODE_999",
        "deployment": "Rice-Fusion-V3"
    }

@app.get("/model-info")
async def model_info():
    return {
        "model_filename": os.path.basename(MODEL_PATH),
        "num_classes": len(engine.idx_to_class) if engine else 0,
        "classes": list(engine.idx_to_class.values()) if engine else [],
        "load_timestamp": LOAD_TIME,
        "input_shape": engine.input_details[0]['shape'].tolist() if engine else None
    }

@app.post("/predict")
async def predict(file: UploadFile = File(...)):
    try:
        image_bytes = await file.read()
        result = engine.predict(image_bytes)
        
        # Standardize response for Flutter client
        response = {
            "class_name": result['class_name'],
            "label": result['class_name'],
            "confidence": result['confidence'],
            "crop": "Rice",
            "disease": result['class_name']
        }
        logger.info(f"PREDICTION RESULT: {response['class_name']} ({response['confidence']:.2f})")
        return response
    except Exception as e:
        logger.error(f"Prediction Error: {e}")
        raise HTTPException(status_code=400, detail=str(e))

from fastapi import Header

@app.get("/treatment/{disease_id}")
async def get_treatment(disease_id: str, acres: float = 1.0, lang: str = Header("en")):
    """
    Returns treatment data formatted for the Flutter DiseaseResult model.
    Syncs with causal_rules.json keys.
    """
    if disease_id in causal_rules:
        rule = causal_rules[disease_id]
        
        # Map rules to Flutter-expected keys
        instruction = rule.get(f'treatment_{lang}', rule.get('treatment_en', 'Treatment info unavailable.'))
        display_name = rule.get(f'name_{lang}', rule.get('name_en', disease_id))
        
        return {
            "disease": display_name,
            "language": lang,
            "instruction": instruction,
            "dosage_per_acre": "Standard per acre dose recommended.",
            "market_recommendations": []
        }
    
    logger.warning(f"Treatment requested for unknown ID: {disease_id}")
    raise HTTPException(status_code=404, detail="Treatment data unavailable")

@app.post("/history/save")
async def save_history(data: HistorySave):
    try:
        logger.info(f"Saving scan for user {data.user_id}: {data.disease_result}")
        return {
            "status": "success",
            "sync_id": data.user_id,
            "received": data.model_dump()
        }
    except Exception as e:
        logger.error(f"History Save Failure: {e}")
        raise HTTPException(
            status_code=400, 
            detail="Malformed history payload"
        )

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)

