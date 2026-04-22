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

# ══════════════════════════════════════════════════════════════════════════════
#  RICE-ENTROPY-FUSION V2 — PRODUCTION CONFIG (STRICTLY RICE ONLY)
# ══════════════════════════════════════════════════════════════════════════════

# Load Build Version
try:
    with open("VERSION", "r") as f:
        VERSION = f.read().strip()
except:
    VERSION = "DEV_UNKNOWN"

# DEPLOY_ID: 2026_04_22_TOTAL_WIPE_RICE_V2
# This build COMPLETELY REMOVES legacy PlantDoc/Tomato data.

load_dotenv()

app = FastAPI(title="Plant Pulse AI - Rice Entropy-Fusion")

# Enable CORS for Mobile App
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── STRICT RICE CLASSES (ANYTHING ELSE REJECTED) ──────────────────────────
CLASS_NAMES = [
    "BacterialLeafBlight",
    "BrownSpot",
    "Healthy",
    "LeafBlast",
    "LeafScald",
    "NarrowBrownSpot",
]

# ─── LOAD 4-CHANNEL MODEL (STRICTLY RICE) ──────────────────────────────────
MODEL_PATH = os.path.join(os.path.dirname(__file__), "AI_Model", "rice_fusion_v2.tflite")
interpreter = None

try:
    interpreter = tf.lite.Interpreter(model_path=MODEL_PATH)
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    
    # CRITICAL CHECK: ENSURE 4-CHANNEL INPUT (RGB + ENTROPY)
    shape = input_details[0]['shape']
    if shape[-1] != 4:
         print(f"❌ ERROR: Model input shape {shape} is NOT 4-channel. Build sequence failed.")
         interpreter = None
    else:
        print(f"✅ Rice-Entropy-Fusion (4-CH) loaded successfully: {MODEL_PATH}")
except Exception as e:
    print(f"❌ CRITICAL LOAD FAILURE: {e}")
    interpreter = None

# ─── LOAD EXPERT SYSTEM DATA ──────────────────────────────────────────────
CAUSAL_RULES_PATH = os.path.join(os.path.dirname(__file__), "AI_Model", "causal_rules.json")
causal_rules: dict = {}
try:
    with open(CAUSAL_RULES_PATH, "r", encoding='utf-8') as f:
        causal_rules = json.load(f)
    print(f"✅ Rice causal rules loaded. ({len(causal_rules)} classes)")
except Exception as e:
    print(f"❌ Failed to load causal rules: {e}")

# ══════════════════════════════════════════════════════════════════════════════
#  STRICT 4-CHANNEL ENTROPY PIPELINE
# ══════════════════════════════════════════════════════════════════════════════

MIN_LEAF_ENTROPY = 3.8 # Slightly stricter to reject high-gloss objects like laptops
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
    if img_bgr is None: raise ValueError("Invalid Image Buffer")
    
    img_bgr = cv2.resize(img_bgr, (224, 224), interpolation=cv2.INTER_AREA)
    img_rgb = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)
    
    entropy_channel, raw_mean_entropy = build_entropy_channel(img_rgb)
    four_channel = np.dstack([img_rgb, entropy_channel])
    
    tensor = four_channel.astype(np.float32) / 255.0
    tensor = np.expand_dims(tensor, axis=0) # (1, 224, 224, 4)
    return tensor, raw_mean_entropy

# ══════════════════════════════════════════════════════════════════════════════
#  ENDPOINTS
# ══════════════════════════════════════════════════════════════════════════════

@app.get("/health")
async def health():
    return {
        "status": "online",
        "deploy_id": "2026_04_22_TOTAL_WIPE_RICE_V2",
        "version": VERSION,
        "model_version": "Rice-Entropy-Fusion (4-Channel)",
        "accuracy": "97.9%",
        "classes": CLASS_NAMES,
        "is_strict_rice": True
    }

@app.post("/predict")
async def predict_image(file: UploadFile = File(...)):
    if interpreter is None:
        raise HTTPException(status_code=503, detail="Model Unavailable")

    try:
        image_bytes = await file.read()
        tensor, raw_mean_entropy = preprocess_image(image_bytes)

        # 1. Texture Check (Rejects Laptops/Bottles)
        if raw_mean_entropy < MIN_LEAF_ENTROPY:
            return {
                "label": "NoRiceLeafDetected",
                "confidence": 0.0,
                "rejected": True,
                "reason": "Not a leaf (Flat Entropy)"
            }

        # 2. Model Inference
        interpreter.set_tensor(input_details[0]['index'], tensor)
        interpreter.invoke()
        predictions = interpreter.get_tensor(output_details[0]['index'])[0]

        # 3. Strict Probability Check
        predicted_index = int(np.argmax(predictions))
        confidence = float(predictions[predicted_index])
        
        # 4. Out-of-Vocabulary Safety (CRASH PREVENTION)
        if predicted_index >= len(CLASS_NAMES):
            return {
                "label": "NoRiceLeafDetected",
                "confidence": confidence,
                "rejected": True,
                "reason": "System mismatch (OOD prediction)"
            }

        label = CLASS_NAMES[predicted_index]

        # 5. Confidence Gate (95% for Rice)
        if confidence < SERVER_CONFIDENCE_THRESHOLD:
            return {
                "label": "NoRiceLeafDetected",
                "confidence": round(confidence, 4),
                "rejected": True,
                "reason": "Uncertain Prediction"
            }

        return {
            "label": label,
            "confidence": round(confidence, 4),
            "rejected": False
        }

    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Inference Error: {str(e)}")

@app.get("/treatment/{disease_id}")
async def get_treatment(disease_id: str):
    # Strictly check if disease exists in Rice rules
    if disease_id in causal_rules:
        return causal_rules[disease_id]
    
    raise HTTPException(status_code=404, detail="Disease not in Rice database")

if __name__ == "__main__":
    import uvicorn
    # Use PORT env variable for Railway compatibility
    port = int(os.getenv("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)