# API Specification — PlantPulse (FastAPI & Supabase)

## 1. Overview
The PlantPulse backend follows a hybrid architecture:
- **Supabase API:** Handles Auth, User Profiles, and Scan History (Auto-generated).
- **FastAPI (Inference Server):** Handles image processing and ML model prediction.

## 2. ML Inference API (FastAPI)
**Base URL:** `https://your-fastapi-url.com`

### 2.1 Predict Disease
*Analyzes an image and returns the disease class.*
- **Endpoint:** `POST /predict`
- **Request Body:** `multipart/form-data` (Key: `file`, Value: Image File)
- **Response:**
```json
{
  "crop": "Tomato",
  "disease_class": "Tomato_Yellow_Leaf_Curl_Virus",
  "confidence": 0.98,
  "is_fungal": false
}