import os
import json
import tensorflow as tf

def verify_plant_classes():
    # Paths (relative to the script location)
    base_path = os.path.join(os.path.dirname(__file__), "AI_Model")
    model_path = os.path.join(base_path, "plant_model.tflite")
    json_path = os.path.join(base_path, "plant_id_class_indices.json")

    print("-" * 60)
    print("PLANT PULSE: MODEL CLASS DIAGNOSTIC")
    print("-" * 60)

    # 1. Model Inspection
    try:
        if not os.path.exists(model_path):
            raise FileNotFoundError(f"Model file not found at: {model_path}")
        
        interpreter = tf.lite.Interpreter(model_path=model_path)
        interpreter.allocate_tensors()

        # Get output details
        output_details = interpreter.get_output_details()
        # Typically the output shape is [1, num_classes]
        output_shape = output_details[0]['shape']
        num_classes_model = output_shape[-1]

        print(f"[OK] MODEL LOADED: {os.path.basename(model_path)}")
        print(f"[INFO] MODEL OUTPUT SHAPE: {output_shape}")
        print(f"[INFO] MODEL CLASSES DETECTED: {num_classes_model}")

    except Exception as e:
        print(f"[FAIL] FATAL ERROR (Model): {e}")
        return

    # 2. JSON Validation
    try:
        if not os.path.exists(json_path):
            raise FileNotFoundError(f"JSON indices not found at: {json_path}")
        
        with open(json_path, 'r', encoding='utf-8') as f:
            class_indices = json.load(f)
        
        num_classes_json = len(class_indices)
        print(f"[OK] JSON LOADED: {os.path.basename(json_path)}")
        print(f"[INFO] JSON CLASSES DETECTED: {num_classes_json}")

    except Exception as e:
        print(f"[FAIL] FATAL ERROR (JSON): {e}")
        return

    print("-" * 60)

    # 3. Comparison Logic
    if num_classes_model == num_classes_json:
        print("[SUCCESS] Model output layer matches JSON class count.")
    else:
        print("[FATAL ERROR] MISMATCH DETECTED!")
        print(f"   Model expects {num_classes_model} classes, but JSON has {num_classes_json}.")

    print("-" * 60)

    # 4. Data Preview
    print("[INFO] DATA PREVIEW (First 10 Class Mappings):")
    # Sort by key (index) to ensure order
    try:
        sorted_indices = sorted(class_indices.items(), key=lambda x: int(x[0]))
        for idx, label in sorted_indices[:10]:
            print(f"   Index {idx} -> {label}")
        
        if num_classes_json > 10:
            print(f"   ... ({num_classes_json - 10} more classes)")
    except Exception as e:
        print(f"[WARN] Could not preview data (check JSON format): {e}")

    print("-" * 60)

if __name__ == "__main__":
    verify_plant_classes()
