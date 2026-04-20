
import json
import os

root = r"d:\Plant Pulse FYP"
indices_path = os.path.join(root, "AI_Model", "class_indices.json")
rules_path = os.path.join(root, "assets/models/causal_rules.json")

with open(indices_path, "r", encoding="utf-8") as f:
    indices = json.load(f)

with open(rules_path, "r", encoding="utf-8") as f:
    rules = json.load(f)

model_labels = set(indices.keys())
rules_keys = set(rules.keys())

missing_in_rules = model_labels - rules_keys
extra_in_rules = rules_keys - model_labels

print("--- FINAL UNIFIED SYNC REPORT ---")
print(f"Total Model Classes: {len(model_labels)}")
print(f"Total Expert Rules: {len(rules_keys)}")

if not missing_in_rules:
    print("\nSUCCESS: All 18 model classes are fully mapped to the expert system.")
else:
    print(f"\nALERT: {len(missing_in_rules)} model labels are missing expert rules!")
    for m in sorted(list(missing_in_rules)):
        print(f"  - {m}")

if extra_in_rules:
    print(f"\nNOTE: Found {len(extra_in_rules)} rules that are NOT in the 18-class model (Legacy):")
    for e in sorted(list(extra_in_rules)):
        print(f"  - {e}")
