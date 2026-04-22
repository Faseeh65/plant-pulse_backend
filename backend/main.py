import os
import cv2
import numpy as np
import tensorflow as tf
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
import json
import sys

# ══════════════════════════════════════════════════════════════════════════════
#  PLANT PULSE RICE-H5 — PRODUCTION PIPELINE
# ══════════════════════════════════════════════════════════════════════════════

load_dotenv()

app = FastAPI(title="Plant Pulse AI - Rice H5")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- 1. MODEL & MAPPING PATHS ---
MODEL_DIR = os.path.join(os.path.dirname(__file__), "model")
MODEL_PATH = os.path.join(MODEL_DIR, "plantpulse_rice_best.h5")
INDICES_PATH = os.path.join(MODEL_DIR, "class_indices.json")

# --- 2. LOAD MODEL & LABELS ---
model = None
class_indices = {}

try:
    if os.path.exists(MODEL_PATH):
        # We use tensorflow-cpu for production stability
        model = tf.keras.models.load_model(MODEL_PATH)
        print(f"✅ Rice Keras Model loaded successfully: {MODEL_PATH}")
    else:
        print(f"⚠️ WARNING: Model not found at {MODEL_PATH}. Prediction will fail.")

    if os.path.exists(INDICES_PATH):
        with open(INDICES_PATH, "r") as f:
            raw_indices = json.load(f)
            # Standardize index-to-label mapping
            class_indices = {int(k): v for k, v in raw_indices.items()}
        print(f"✅ Class indices loaded: {len(class_indices)} categories")
    else:
        print(f"⚠️ WARNING: Indices not found at {INDICES_PATH}")

except Exception as e:
    print(f"❌ LOAD ERROR: {e}")

# Load Expert System rules
CAUSAL_RULES_PATH = os.path.join(os.path.dirname(__file__), "AI_Model", "causal_rules.json")
causal_rules: dict = {}
try:
    if os.path.exists(CAUSAL_RULES_PATH):
        with open(CAUSAL_RULES_PATH, "r", encoding='utf-8') as f:
            causal_rules = json.load(f)
except: pass

# --- 3. PREPROCESSING ---
CONFIDENCE_THRESHOLD = 0.90 # Set to 90% as requested

def preprocess_image(image_bytes: bytes):
    nparr = np.frombuffer(image_bytes, np.uint8)
    img_bgr = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if img_bgr is None: raise ValueError("Invalid image")
    
    # 3-Channel RGB Pipeline (Standard for Best H5 Model)
    img_bgr = cv2.resize(img_bgr, (224, 224), interpolation=cv2.INTER_AREA)
    img_rgb = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)
    
    tensor = img_rgb.astype(np.float32) / 255.0
    tensor = np.expand_dims(tensor, axis=0) # (1, 224, 224, 3)
    return tensor

# --- 4. ENDPOINTS ---

@app.get("/health")
async def health():
    return {
        "status": "online",
        "model_loaded": model is not None,
        "indices_loaded": len(class_indices) > 0,
        "classes": list(class_indices.values()),
        "architecture": "Keras H5 (3-Channel)"
    }

@app.post("/predict")
async def predict_image(file: UploadFile = File(...)):
    if model is None:
        raise HTTPException(status_code=503, detail="Model file missing on server")

    try:
        image_bytes = await file.read()
        tensor = preprocess_image(image_bytes)

        # Live Inference
        predictions = model.predict(tensor, verbose=0)[0]
        predicted_idx = int(np.argmax(predictions))
        confidence = float(predictions[predicted_idx])
        
        # Mapping back to class name
        label = class_indices.get(predicted_idx, "Unknown")

        # Validation Logic
        if confidence < CONFIDENCE_THRESHOLD or label == "Unknown":
            return {
                "label": "NoRiceLeafDetected",
                "error": "No Rice Leaf Detected",
                "confidence": round(confidence, 4),
                "rejected": True
            }

        return {
            "label": label,
            "confidence": round(confidence, 4),
            "rejected": False
        }

    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/treatment/{disease_id}")
async def get_treatment(disease_id: str):
    if disease_id in causal_rules:
        return causal_rules[disease_id]
    raise HTTPException(status_code=404, detail="Treatment data unavailable for this disease")

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)
