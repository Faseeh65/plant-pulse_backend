# Product Requirement Document (PRD) — PlantPulse

## 1. Executive Summary
PlantPulse is a specialized mobile diagnostic tool designed for Pakistani farmers. It bridges the gap between identifying a leaf symptom and finding the correct pesticide in the local market. Its unique value proposition is the "Causal Chain" linking diseases to their biological insect vectors (pests).

## 2. Problem Statement
Farmers in Pakistan often treat symptoms (diseases) without addressing the cause (pests), leading to recurring crop failure and wasted money on incorrect pesticides. Existing apps often use regional data that fails in local Pakistani field conditions.

## 3. Target Audience
- Small-scale farmers in Punjab and KPK.
- Agricultural students and extension workers.

## 4. Functional Requirements

### 4.1 Disease Detection (AI)
- **Input:** Real-time camera scan or gallery upload.
- **Model:** EfficientNetB3 trained on unified plant health datasets.
- **Scope:** 13 classes (Healthy + Diseases for Tomato, Maize, Potato).

### 4.2 The "Causal Chain" Engine
- **Logic:** For every detected disease, the app must identify the likely insect pest.
- **Interactivity:** A 3-question flow (Duration, Irrigation, Weather) to refine fungal diagnosis.
- **Output:** Pest Name (Urdu/Eng) + Scientific Name.

### 4.3 Treatment & Market Integration
- **Pesticides:** Display 2-3 specific local brands (e.g., Engro, Bayer, Syngenta).
- **Pricing:** Estimated PKR pricing per pack/acre.
- **Language:** Fully bilingual (Urdu and English).

### 4.4 User History (Secure)
- **Storage:** Supabase PostgreSQL.
- **Privacy:** Users must see only their own historical scans via Supabase RLS.

## 5. User Flow
1. **Landing:** Language Selection -> Login (Supabase Auth).
2. **Scan:** User points camera at leaf -> Result displays Disease + Confidence.
3. **Refine:** If fungal, app asks 3 Urdu questions -> Confirms Pest.
4. **Action:** App shows Treatment (Organic + Chemical) with local PKR prices.
5. **History:** Scan is auto-saved to "My History" tab.

## 6. Technical Constraints
- **Platform:** Android (min SDK 21).
- **Network:** Requires internet (Online-only).
- **Database:** Supabase (Relational tables for Crop > Pest > Disease mapping).


- **UX:** 100% of labels available in Urdu.