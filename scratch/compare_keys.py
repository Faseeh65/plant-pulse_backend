
import json
import os

root = r"d:\Plant Pulse FYP"
indices_path = os.path.join(root, "AI_Model", "class_indices.json")
rules_path = os.path.join(root, "assets", "models", "causal_rules.json")

with open(indices_path, "r", encoding="utf-8") as f:
    indices = json.load(f)

with open(rules_path, "r", encoding="utf-8") as f:
    rules = json.load(f)

indices_values = set(indices.values())
rules_keys = set(rules.keys())

missing_in_rules = indices_values - rules_keys
extra_in_rules = rules_keys - indices_values

print("--- DATASET SYNC REPORT ---")
print(f"Total Model Classes: {len(indices_values)}")
print(f"Total Expert Rules: {len(rules_keys)}")

if not missing_in_rules:
    print("\nSUCCESS: All model classes have expert system rules.")
else:
    print(f"\nALERT: {len(missing_in_rules)} classes are missing rules!")
    for m in sorted(list(missing_in_rules)):
        print(f"  - {m}")

if extra_in_rules:
    print(f"\nNOTE: There are {len(extra_in_rules)} rules in rules.json that are NOT in the model indices (Legacy labels):")
    # Limit display if too many
    for e in sorted(list(extra_in_rules))[:10]:
        print(f"  - {e}")
    if len(extra_in_rules) > 10:
        print(f"  ... and {len(extra_in_rules)-10} more.")

print("\n--- NAMING CONVENTION CHECK ---")
has_legacy_in_indices = any("___" in v for v in indices_values)
if has_legacy_in_indices:
    print("WARNING: Your class_indices.json still contains legacy '___' delimiters.")
else:
    print("Patterns: No '___' found in model indices. Clean dataset confirmed.")
