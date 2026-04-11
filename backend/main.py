from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

app = FastAPI(
    title="PlantPulse Inference API",
    description="ML inference server for plant disease detection (EfficientNetB3).",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# TODO: Load EfficientNetB3 model here
# model = tf.keras.models.load_model("model/efficientnetb3_plantpulse.h5")

CLASS_NAMES = [
    "Tomato_Yellow_Leaf_Curl_Virus",
    "Tomato_Healthy",
    # Add remaining 11 classes here
]

FUNGAL_CLASSES = {
    # "ClassName": True/False
    "Tomato_Yellow_Leaf_Curl_Virus": False,
}


@app.get("/health")
async def health_check():
    return {"status": "ok"}


@app.post("/predict")
async def predict(file: UploadFile = File(...)):
    if not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File must be an image.")

    # TODO: Preprocess image and run model inference
    # image_bytes = await file.read()
    # prediction = run_inference(image_bytes)

    # Placeholder response matching API.md spec
    return {
        "crop": "Tomato",
        "disease_class": "Tomato_Yellow_Leaf_Curl_Virus",
        "confidence": 0.98,
        "is_fungal": False,
    }


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
