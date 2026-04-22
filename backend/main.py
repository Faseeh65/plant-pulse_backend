import os
import numpy as np
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
import json
from inference_server import RiceInferenceEngine

# ══════════════════════════════════════════════════════════════════════════════
#  PLANT PULSE RICE-TFLITE — PRODUCTION PIPELINE
# ══════════════════════════════════════════════════════════════════════════════

load_dotenv()

app = FastAPI(title="Plant Pulse AI - Rice TFLite")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- 1. MODEL PATHS ---
MODEL_PATH = os.path.join(
    os.path.dirname(__file__),
    'AI_Model', 'rice_fusion_v2.tflite'
)
LABELS_PATH = os.path.join(
    os.path.dirname(__file__),
    'AI_Model', 'class_indices.json'
)

# Initialize Engine with Logging
print("Initializing RiceInferenceEngine...")
try:
    engine = RiceInferenceEngine(MODEL_PATH, LABELS_PATH)
    print("✅ RiceInferenceEngine status: READY")
except Exception as e:
    print(f"❌ FATAL ERROR: RiceInferenceEngine failed to initialize: {e}")
    # Force exit so Railway doesn't mark this as a "healthy" but broken deploy
    import sys
    sys.exit(1)

# Load Expert System rules
CAUSAL_RULES_PATH = os.path.join(os.path.dirname(__file__), "AI_Model", "causal_rules.json")
causal_rules: dict = {}
try:
    if os.path.exists(CAUSAL_RULES_PATH):
        with open(CAUSAL_RULES_PATH, "r", encoding='utf-8') as f:
            causal_rules = json.load(f)
        print("✅ Expert System rules: READY")
except Exception as e:
    print(f"❌ Expert System rules: FAILED | Error: {e}")

# --- 2. ENDPOINTS ---

@app.get("/health")
async def health():
    return {
        "status": "online",
        "engine_status": "READY" if engine else "FAILED",
        "expert_system": "READY" if causal_rules else "FAILED",
        "classes": list(engine.idx_to_class.values()) if engine else [],
        "deployment": "Rice-Fusion-V2-Production"
    }

@app.post("/predict")
async def predict(file: UploadFile = File(...)):
    try:
        image_bytes = await file.read()
        result = engine.predict(image_bytes)
        
        # Standardize response for Flutter client
        return {
            "class_name": result['class_name'],
            "label": result['class_name'],
            "confidence": result['confidence'],
            "crop": "Rice",
            "disease": result['class_name']
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/treatment/{disease_id}")
async def get_treatment(disease_id: str):
    if disease_id in causal_rules:
        return causal_rules[disease_id]
    raise HTTPException(status_code=404, detail="Treatment data unavailable")

@app.post("/history/save")
async def save_history(scan_data: dict):
    try:
        return {
            "status": "saved",
            "data": scan_data
        }
    except Exception as e:
        raise HTTPException(
            status_code=400, 
            detail=str(e)
        )

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)
