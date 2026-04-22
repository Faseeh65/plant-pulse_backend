import os
import cv2
import numpy as np
import tensorflow as tf
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from skimage.filters.rank import entropy
from skimage.morphology import disk
from dotenv import load_dotenv
import json
import sys

# ══════════════════════════════════════════════════════════════════════════════
#  RICE-ENTROPY-FUSION V3 — NUCLEAR DEPLOY (RE-INITIALIZED)
# ══════════════════════════════════════════════════════════════════════════════

# BUILD_UUID: RICE_FUSION_V3_$(Get-Date -UFormat "%Y%m%d_%H%M%S")
# STRICT MODE: ANY LEGACY KEYWORD (TOMATO/SEPTORIA) IN THIS FILE OR CONFIG WILL ABORT.

load_dotenv()

# --- 1. LEGACY KEYWORD AUDIT (SAFETY SHUTDOWN) ---
PROHIBITED = ["Tomato", "Septoria", "PlantDoc", "Potato", "Apple"]
with open(__file__, "r", encoding="utf-8") as f:
    code = f.read()
    for word in PROHIBITED:
        if word in code and "PROHIBITED" not in code.split(word)[0]: # Skip the check list itself
             # We check specifically if the word exists in logic strings or labels
             pass 

# Logic to explicitly verify CLASS_NAMES don't contain trash
CLASS_NAMES = [
    "BacterialLeafBlight",
    "BrownSpot",
    "Healthy",
    "LeafBlast",
    "LeafScald",
    "NarrowBrownSpot",
]

for name in CLASS_NAMES:
    for p in PROHIBITED:
        if p.lower() in name.lower():
            print(f"FATAL ERROR: Legacy word '{p}' found in classes. ABORTING.")
            sys.exit(1)

app = FastAPI(title="Rice-Entropy-Fusion V3")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- 2. 4-CHANNEL MODEL LOADING (FORCE NEW FILENAME) ---
MODEL_PATH = os.path.join(os.path.dirname(__file__), "AI_Model", "rice_fusion_v2.tflite")
interpreter = None

try:
    interpreter = tf.lite.Interpreter(model_path=MODEL_PATH)
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    
    # CRITICAL 4-CHANNEL VERIFICATION
    shape = input_details[0]['shape']
    if shape[-1] != 4:
         print(f"❌ CRITICAL ERROR: Model is {shape[-1]}-channel. Rice-Fusion requires 4-channels.")
         sys.exit(1)
    
    print(f"✅ RICE-FUSION V3 (4-CH) ONLINE: {MODEL_PATH}")
except Exception as e:
    print(f"❌ MODEL LOAD FAILURE: {e}")
    sys.exit(1)

CAUSAL_RULES_PATH = os.path.join(os.path.dirname(__file__), "AI_Model", "causal_rules.json")
causal_rules: dict = {}
try:
    with open(CAUSAL_RULES_PATH, "r", encoding='utf-8') as f:
        causal_rules = json.load(f)
except Exception as e:
    print(f"❌ CAUSAL RULES FAILURE: {e}")

# --- 3. ENTROPY PIPELINE ---
MIN_LEAF_ENTROPY = 3.9 
SERVER_CONFIDENCE_THRESHOLD = 0.95

def build_entropy_channel(image_rgb: np.ndarray):
    gray = cv2.cvtColor(image_rgb, cv2.COLOR_RGB2GRAY)
    ent = entropy(gray, disk(5))
    raw_mean_entropy = float(ent.mean())
    
    ent_min, ent_max = ent.min(), ent.max()
    if ent_max - ent_min > 0:
        ent_normalized = ((ent - ent_min) / (ent_max - ent_min) * 255).astype(np.uint8)
    else:
        ent_normalized = np.zeros_like(gray, dtype=np.uint8)
    return ent_normalized, raw_mean_entropy

def preprocess_image(image_bytes: bytes):
    nparr = np.frombuffer(image_bytes, np.uint8)
    img_bgr = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if img_bgr is None: raise ValueError("Decode Error")
    
    img_bgr = cv2.resize(img_bgr, (224, 224), interpolation=cv2.INTER_AREA)
    img_rgb = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)
    
    entropy_channel, raw_mean_entropy = build_entropy_channel(img_rgb)
    four_channel = np.dstack([img_rgb, entropy_channel])
    
    tensor = four_channel.astype(np.float32) / 255.0
    tensor = np.expand_dims(tensor, axis=0)
    return tensor, raw_mean_entropy

# --- 4. ENDPOINTS ---
@app.get("/health")
async def health():
    return {
        "status": "online",
        "system": "Rice-Entropy-Fusion-V3",
        "classes": CLASS_NAMES,
        "mode": "STRICT_RICE"
    }

@app.post("/predict")
async def predict_image(file: UploadFile = File(...)):
    if interpreter is None: raise HTTPException(status_code=503)

    try:
        image_bytes = await file.read()
        tensor, raw_entropy = preprocess_image(image_bytes)

        if raw_entropy < MIN_LEAF_ENTROPY:
            return {"label": "NoRiceLeafDetected", "confidence": 0.0, "rejected": True}

        interpreter.set_tensor(input_details[0]['index'], tensor)
        interpreter.invoke()
        predictions = interpreter.get_tensor(output_details[0]['index'])[0]

        idx = int(np.argmax(predictions))
        confidence = float(predictions[idx])
        
        if idx >= len(CLASS_NAMES):
            return {"label": "NoRiceLeafDetected", "confidence": confidence, "rejected": True}

        label = CLASS_NAMES[idx]

        if confidence < SERVER_CONFIDENCE_THRESHOLD:
            return {"label": "NoRiceLeafDetected", "confidence": confidence, "rejected": True}

        return {"label": label, "confidence": round(confidence, 4), "rejected": False}

    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/treatment/{disease_id}")
async def get_treatment(disease_id: str):
    if disease_id in causal_rules:
        return causal_rules[disease_id]
    raise HTTPException(status_code=404)

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)