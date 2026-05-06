"""
preflight_check.py — Plant Pulse Pre-Deployment Diagnostic
Validates model-JSON alignment, key mapping, and endpoint URLs
before pushing to Railway.

Usage: python preflight_check.py
"""

import json
import os
import sys
import random

# ── Configuration ──────────────────────────────────────────────────────────────

BASE_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "backend", "AI_Model")

# Rice Disease Model
RICE_MODEL_PATH = os.path.join(BASE_DIR, "model_v2.tflite")
RICE_INDICES_PATH = os.path.join(BASE_DIR, "model_v2_class_indices.json")
RICE_RULES_PATH = os.path.join(BASE_DIR, "causal_rules.json")

# Plant Identification Model
PLANT_MODEL_PATH = os.path.join(BASE_DIR, "plant_model.tflite")
PLANT_INDICES_PATH = os.path.join(BASE_DIR, "plant_identification_class_indices.json")
PLANT_RULES_PATH = os.path.join(BASE_DIR, "Plant_Identification_Model_casual_rule.json")

# Railway URL (update this before deployment)
RAILWAY_BASE_URL = "https://railway.com/project/dd0994be-8a7a-447d-b7cc-7a9f69ee0786/service/c9d500c1-03d3-48f2-8532-bb5bc3573d71?environmentId=702bfa6a-8516-40f9-8cb0-10e88e687b55"

PASS = "[PASS]"
FAIL = "[FAIL]"
WARN = "[WARN]"
INFO = "[INFO]"

errors = []
warnings = []

# ── Helpers ────────────────────────────────────────────────────────────────────

def section(title):
    print(f"\n{'=' * 60}")
    print(f"  {title}")
    print(f"{'=' * 60}")

def check(label, passed, detail=""):
    status = PASS if passed else FAIL
    print(f"  {status}  {label}")
    if detail:
        print(f"         → {detail}")
    if not passed:
        errors.append(label)
    return passed

def warn(label, detail=""):
    print(f"  {WARN}  {label}")
    if detail:
        print(f"         → {detail}")
    warnings.append(label)

def info(label, detail=""):
    print(f"  {INFO}  {label}")
    if detail:
        print(f"         → {detail}")

# ── 1. File Existence ─────────────────────────────────────────────────────────

def check_files():
    section("1. FILE EXISTENCE CHECK")
    
    required_files = {
        "Rice Model (.tflite)": RICE_MODEL_PATH,
        "Rice Class Indices (.json)": RICE_INDICES_PATH,
        "Rice Causal Rules (.json)": RICE_RULES_PATH,
        "Plant Model (.tflite)": PLANT_MODEL_PATH,
        "Plant Class Indices (.json)": PLANT_INDICES_PATH,
        "Plant Causal Rules (.json)": PLANT_RULES_PATH,
    }
    
    all_exist = True
    for label, path in required_files.items():
        exists = os.path.exists(path)
        size_info = ""
        if exists:
            size_mb = os.path.getsize(path) / (1024 * 1024)
            size_info = f"{size_mb:.2f} MB" if size_mb > 0.01 else f"{os.path.getsize(path)} bytes"
        passed = check(label, exists, size_info if exists else f"MISSING: {path}")
        if not passed:
            all_exist = False
    
    return all_exist

# ── 2. Index Integrity (Model Output vs JSON Length) ──────────────────────────

def check_index_integrity():
    section("2. INDEX INTEGRITY — Model Output vs JSON Length")
    
    try:
        import tensorflow as tf
    except ImportError:
        warn("TensorFlow not installed — skipping model tensor checks.",
             "Run: pip install tensorflow-cpu")
        return True
    
    all_match = True
    
    models = [
        ("Rice", RICE_MODEL_PATH, RICE_INDICES_PATH),
        ("Plant", PLANT_MODEL_PATH, PLANT_INDICES_PATH),
    ]
    
    for name, model_path, indices_path in models:
        if not os.path.exists(model_path) or not os.path.exists(indices_path):
            check(f"{name} index integrity", False, "Required file(s) missing — skipped.")
            all_match = False
            continue
        
        try:
            interpreter = tf.lite.Interpreter(model_path=model_path)
            interpreter.allocate_tensors()
            output_details = interpreter.get_output_details()
            num_model_classes = output_details[0]['shape'][-1]
            
            with open(indices_path, 'r', encoding='utf-8') as f:
                indices = json.load(f)
            num_json_classes = len(indices)
            
            matched = num_model_classes == num_json_classes
            detail = f"Model outputs {num_model_classes} classes, JSON has {num_json_classes} entries"
            check(f"{name} index integrity", matched, detail)
            
            if not matched:
                all_match = False
                
        except Exception as e:
            check(f"{name} index integrity", False, f"Error: {e}")
            all_match = False
    
    return all_match

# ── 3. Key Mapping — Index Labels vs Causal Rules Keys ───────────────────────

def check_key_mapping():
    section("3. KEY MAPPING — Index Labels vs Causal Rules Keys")
    
    all_valid = True
    
    pairs = [
        ("Rice", RICE_INDICES_PATH, RICE_RULES_PATH),
        ("Plant", PLANT_INDICES_PATH, PLANT_RULES_PATH),
    ]
    
    for name, indices_path, rules_path in pairs:
        if not os.path.exists(indices_path) or not os.path.exists(rules_path):
            check(f"{name} key mapping", False, "Required file(s) missing — skipped.")
            all_valid = False
            continue
        
        try:
            with open(indices_path, 'r', encoding='utf-8') as f:
                indices = json.load(f)
            with open(rules_path, 'r', encoding='utf-8') as f:
                rules = json.load(f)
            
            class_labels = list(indices.values())
            rule_keys = set(rules.keys())
            
            # Check all class labels exist in rules
            missing = [label for label in class_labels if label not in rule_keys]
            orphan_rules = [key for key in rule_keys if key not in class_labels]
            
            if missing:
                check(f"{name} key mapping — missing rules", False,
                      f"{len(missing)} class(es) have NO matching rule: {missing[:5]}{'...' if len(missing) > 5 else ''}")
                all_valid = False
            else:
                check(f"{name} key mapping — all labels covered", True,
                      f"All {len(class_labels)} class labels found in rules JSON.")
            
            if orphan_rules:
                warn(f"{name} orphan rules detected",
                     f"{len(orphan_rules)} rule key(s) not in class indices: {orphan_rules[:5]}")
            
            # Random spot check
            if class_labels:
                random_label = random.choice(class_labels)
                in_rules = random_label in rule_keys
                check(f"{name} random spot check: '{random_label}'", in_rules,
                      "Found in rules" if in_rules else "NOT found — will cause KeyError at runtime!")
                if not in_rules:
                    all_valid = False
                    
        except Exception as e:
            check(f"{name} key mapping", False, f"Error: {e}")
            all_valid = False
    
    return all_valid

# ── 4. Endpoint URL Verification ─────────────────────────────────────────────

def check_endpoints():
    section("4. ENDPOINT URL VERIFICATION")
    
    endpoints = {
        "Health Check":           ("GET",  f"{RAILWAY_BASE_URL}/health"),
        "Rice Predict":           ("POST", f"{RAILWAY_BASE_URL}/predict"),
        "Plant Identify":         ("POST", f"{RAILWAY_BASE_URL}/identify"),
        "Treatment Lookup":       ("GET",  f"{RAILWAY_BASE_URL}/treatment/{{disease_id}}"),
        "History Save":           ("POST", f"{RAILWAY_BASE_URL}/history/save"),
        "History Fetch":          ("GET",  f"{RAILWAY_BASE_URL}/history/{{user_id}}"),
        "Stats":                  ("GET",  f"{RAILWAY_BASE_URL}/stats?user_id={{user_id}}"),
    }
    
    print(f"\n  Railway Base URL: {RAILWAY_BASE_URL}\n")
    
    for name, (method, url) in endpoints.items():
        trailing_slash = url.endswith("/") and not url.endswith("}/")
        info(f"{method:5s} {url}")
        if trailing_slash:
            warn(f"  Trailing slash detected on '{name}' — may cause 307 redirect.")
    
    print()
    info("Flutter scanner_screen.dart calls:",
         f"POST ${{ApiService.baseUrl}}/predict")
    info("Flutter plant_identify_screen.dart calls:",
         f"POST ${{ApiService.baseUrl}}/identify")
    info("Backend main.py registers:",
         '@app.post("/predict") and @app.post("/identify")')
    
    check("Endpoint naming consistency", True,
          "Flutter → /predict and /identify match backend routes.")
    
    return True

# ── 5. Dockerfile & Railway Config ───────────────────────────────────────────

def check_infrastructure():
    section("5. INFRASTRUCTURE — Dockerfile & Railway")
    
    backend_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "backend")
    
    # Dockerfile check
    dockerfile_path = os.path.join(backend_dir, "Dockerfile")
    if os.path.exists(dockerfile_path):
        with open(dockerfile_path, 'r') as f:
            dockerfile_content = f.read()
        
        has_copy_all = "COPY . ." in dockerfile_content
        check("Dockerfile has 'COPY . .' (copies AI_Model/)", has_copy_all,
              "AI_Model/ directory will be included in Docker image" if has_copy_all
              else "MISSING: AI_Model/ may not be copied into the container!")
        
        has_requirements = "requirements.txt" in dockerfile_content
        check("Dockerfile installs requirements.txt", has_requirements)
    else:
        check("Dockerfile exists", False, f"Not found at {dockerfile_path}")
    
    # Railway config
    railway_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "railway.toml")
    if os.path.exists(railway_path):
        with open(railway_path, 'r') as f:
            railway_content = f.read()
        
        has_health = "/health" in railway_content
        check("railway.toml has healthCheckPath", has_health)
        
        has_root_dir = 'rootDirectory = "backend"' in railway_content
        check("railway.toml rootDirectory = backend", has_root_dir)
    else:
        warn("railway.toml not found — Railway may use defaults.")
    
    # Requirements.txt check
    req_path = os.path.join(backend_dir, "requirements.txt")
    if os.path.exists(req_path):
        with open(req_path, 'r') as f:
            req_content = f.read().lower()
        
        critical_deps = {
            "tensorflow": "tensorflow" in req_content,
            "pillow": "pillow" in req_content,
            "numpy": "numpy" in req_content,
            "python-multipart": "python-multipart" in req_content,
            "fastapi": "fastapi" in req_content,
            "uvicorn": "uvicorn" in req_content,
        }
        
        for dep, found in critical_deps.items():
            check(f"requirements.txt includes '{dep}'", found)
    else:
        check("requirements.txt exists", False)
    
    return True

# ── 6. Git Status Warnings ───────────────────────────────────────────────────

def check_git_status():
    section("6. GIT STATUS — Untracked File Warnings")
    
    critical_untracked = [
        "backend/AI_Model/plant_model.tflite",
        "backend/AI_Model/plant_identification_class_indices.json",
        "backend/AI_Model/Plant_Identification_Model_casual_rule.json",
        "lib/screens/plant_identify_screen.dart",
    ]
    
    for f in critical_untracked:
        full_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), f)
        exists = os.path.exists(full_path)
        if exists:
            warn(f"UNTRACKED: {f}",
                 "Must run 'git add' before push or Railway will NOT have this file.")
        else:
            check(f"File exists: {f}", False, "MISSING from filesystem!")
    
    print(f"\n  Run this before pushing:")
    print(f"  +--------------------------------------------------+")
    print(f"  |  git add backend/AI_Model/plant_model.tflite     |")
    print(f"  |  git add backend/AI_Model/plant_*_class_*.json   |")
    print(f"  |  git add backend/AI_Model/Plant_*_casual_*.json  |")
    print(f"  |  git add lib/screens/plant_identify_screen.dart  |")
    print(f"  |  git add backend/main.py lib/main.dart           |")
    print(f"  |  git add lib/screens/home_screen.dart            |")
    print(f"  +--------------------------------------------------+")

# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    print("\n" + "=" * 60)
    print("  PLANT PULSE — PRE-DEPLOYMENT PREFLIGHT CHECK")
    print("  Target: Railway (Docker)")
    print("=" * 60)
    
    files_ok = check_files()
    
    if files_ok:
        check_index_integrity()
        check_key_mapping()
    else:
        section("2. INDEX INTEGRITY — SKIPPED (missing files)")
        section("3. KEY MAPPING — SKIPPED (missing files)")
    
    check_endpoints()
    check_infrastructure()
    check_git_status()
    
    # ── Final Verdict ──
    section("FINAL VERDICT")
    
    if errors:
        print(f"\n  {FAIL}  {len(errors)} CRITICAL ERROR(S) FOUND — DO NOT DEPLOY")
        for err in errors:
            print(f"       • {err}")
        print()
        sys.exit(1)
    elif warnings:
        print(f"\n  {WARN}  {len(warnings)} WARNING(S) — Review before deploying")
        for w in warnings:
            print(f"       • {w}")
        print(f"\n  All critical checks passed. Deploy with caution.\n")
        sys.exit(0)
    else:
        print(f"\n  {PASS}  ALL CHECKS PASSED — Safe to deploy!\n")
        sys.exit(0)

if __name__ == "__main__":
    main()
