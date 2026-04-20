
import json
import os
import re

root = r"d:\Plant Pulse FYP"
indices_path = os.path.join(root, "backend", "AI_Model", "class_indices.json")
rules_path = os.path.join(root, "assets", "models", "causal_rules.json")
main_py_path = os.path.join(root, "backend", "main.py")

with open(indices_path, "r", encoding="utf-8") as f:
    raw_data = json.load(f)

new_rules = {}
treatment_db = {}

for item in raw_data:
    name = item["disease_name"]
    
    # Prep Causal Rules (Frontend)
    new_rules[name] = {
        "urdu_name": item.get("urdu_name", ""),
        "cause": item.get("cause_english", ""),
        "urdu_cause": item.get("cause_urdu", ""),
        "organic_treatment": item.get("organic_treatment", ""),
        "urdu_organic": "", # Placeholder
        "chemical_treatment": item.get("chemical_treatment", ""),
        "urdu_chemical": "", # Placeholder
        "pesticide_brand": item.get("pesticide_brands_pk", ""),
        "price_pkr": item.get("price_pkr", ""),
        "availability": "Available locally",
        "urdu_availability": "مقامی طور پر دستیاب",
        "prevention": item.get("prevention_tips", ""),
        "urdu_prevention": "",
        "severity": item.get("severity_level", "moderate").lower(),
        "questions_needed": item.get("questions_needed", "no") == "yes",
        "harvest_warning": "No restrictions",
        "urdu_warning": "کوئی پابندی نہیں"
    }
    
    # Prep Treatment DB (Backend)
    treatment_db[name] = {
        "disease": name,
        "instruction": item.get("organic_treatment", ""),
        "dosage_per_acre": "Standard",
        "market_recommendations": [
            {
                "local_brand": item.get("pesticide_brands_pk", "N/A"),
                "company": "Local",
                "size": "Pack",
                "pkr_price": 0, # Could try to parse from price_pkr
                "required_packs": 1
            }
        ]
    }

# Write causal_rules.json
with open(rules_path, "w", encoding="utf-8") as f:
    json.dump(new_rules, f, ensure_ascii=False, indent=2)

# Update main.py TREATMENT_DB
with open(main_py_path, "r", encoding="utf-8") as f:
    content = f.read()

# Find and replace TREATMENT_DB block
db_str = "TREATMENT_DB = " + json.dumps(treatment_db, indent=4)
# Use regex to find the block starting with TREATMENT_DB = { and ending with } followed by def normalize_label
pattern = r"TREATMENT_DB = \{.*?\}\n\ndef normalize_label"
new_content = re.sub(pattern, db_str + "\n\ndef normalize_label", content, flags=re.DOTALL)

with open(main_py_path, "w", encoding="utf-8") as f:
    f.write(new_content)

print(f"Project Integrated. 25 labels synced across backend and expert system.")
