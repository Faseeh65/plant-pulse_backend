import json
import os
import tensorflow as tf

def verify_model_classes():
    # Paths (relative to project root)
    model_path = os.path.join('backend', 'AI_Model', 'plant_model.tflite')
    json_path = os.path.join('backend', 'AI_Model', 'plant_id_class_indices.json')

    print("--- Plant Pulse Model Diagnostic ---")
    
    try:
        # 1. Model Inspection
        if not os.path.exists(model_path):
            raise FileNotFoundError(f"Model file not found at: {model_path}")
            
        interpreter = tf.lite.Interpreter(model_path=model_path)
        interpreter.allocate_tensors()
        
        output_details = interpreter.get_output_details()
        # The output shape is usually [1, num_classes]
        output_shape = output_details[0]['shape']
        num_classes_model = output_shape[-1]
        
        print(f"[INFO] Model loaded successfully.")
        print(f"[INFO] Model output classes detected: {num_classes_model}")

        # 2. JSON Validation
        if not os.path.exists(json_path):
            raise FileNotFoundError(f"JSON indices file not found at: {json_path}")
            
        with open(json_path, 'r') as f:
            class_indices = json.load(f)
            
        num_classes_json = len(class_indices)
        print(f"[INFO] JSON indices loaded successfully.")
        print(f"[INFO] JSON classes detected: {num_classes_json}")

        # 3. Comparison Logic
        print("-" * 37)
        if num_classes_model == num_classes_json:
            print(">>> SUCCESS: Model and JSON indices match.")
        else:
            print(f">>> FATAL ERROR: Mismatch detected!")
            print(f"    Model: {num_classes_model} vs JSON: {num_classes_json}")
        print("-" * 37)

        # 4. Data Preview
        print("\n[PREVIEW] First 10 Class Mappings:")
        # Sort by key (index) if they are numeric strings, otherwise just take first 10
        sorted_indices = sorted(class_indices.items(), key=lambda x: int(x[0]) if x[0].isdigit() else x[0])
        
        for i, (idx, label) in enumerate(sorted_indices[:10]):
            print(f"  Index {idx:2}: {label}")

    except FileNotFoundError as e:
        print(f"[ERROR] {e}")
    except Exception as e:
        print(f"[ERROR] An unexpected error occurred: {e}")

if __name__ == "__main__":
    verify_model_classes()
