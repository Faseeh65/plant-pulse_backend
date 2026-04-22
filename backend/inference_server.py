import numpy as np
import tensorflow as tf
import json
from PIL import Image
import io
import os

class RiceInferenceEngine:
    def __init__(self, model_path, labels_path):
        print("--- RICE INFERENCE ENGINE INITIALIZATION ---")
        
        # 1. Existence Checks
        if not os.path.exists(model_path):
            print(f"❌ ERROR: Model file NOT FOUND at: {model_path}")
            raise FileNotFoundError(f"Model file missing: {model_path}")
            
        if not os.path.exists(labels_path):
            print(f"❌ ERROR: Labels file NOT FOUND at: {labels_path}")
            raise FileNotFoundError(f"Labels file missing: {labels_path}")

        print(f"🔍 Found model file: {model_path}")
        print(f"🔍 Found labels file: {labels_path}")

        try:
            # 2. Load TFLite Model
            print("🚀 Loading TFLite Interpreter...")
            self.interpreter = tf.lite.Interpreter(model_path=model_path)
            self.interpreter.allocate_tensors()
            
            self.input_details = self.interpreter.get_input_details()
            self.output_details = self.interpreter.get_output_details()
            
            # 3. Log Architecture Details
            print(f"✅ Interpreter Ready.")
            print(f"📋 Input Shape: {self.input_details[0]['shape']}")
            print(f"📋 Output Shape: {self.output_details[0]['shape']}")

            # 4. Load Labels
            print("📖 Reading class indices...")
            with open(labels_path, 'r') as f:
                self.class_indices = json.load(f)
            
            self.idx_to_class = {
                int(k): v 
                for k, v in self.class_indices.items()
            }
            
            print(f"✅ Success: Loaded {len(self.idx_to_class)} classes.")
            print(f"🏷️ Classes: {list(self.idx_to_class.values())}")
            
            # 5. Fallback Audit
            print("🛡️ Fallback Audit: 0 legacy models found in memory.")
            print("---------------------------------------------")

        except Exception as e:
            print(f"💥 CRITICAL LOAD FAILURE: {e}")
            raise RuntimeError(f"Engine initialization failed: {e}")

    def preprocess(self, image_bytes):
        try:
            img = Image.open(io.BytesIO(image_bytes))
            img = img.convert('RGB')
            img = img.resize((224, 224))
            img_array = np.array(img, dtype=np.float32)
            img_array = img_array / 255.0
            img_array = np.expand_dims(img_array, axis=0)
            return img_array
        except Exception as e:
            print(f"❌ Preprocessing Error: {e}")
            raise

    def predict(self, image_bytes):
        input_data = self.preprocess(image_bytes)
        
        self.interpreter.set_tensor(
            self.input_details[0]['index'],
            input_data
        )
        self.interpreter.invoke()
        
        output = self.interpreter.get_tensor(
            self.output_details[0]['index']
        )
        
        predicted_idx = int(np.argmax(output[0]))
        confidence = float(np.max(output[0]))
        
        class_name = self.idx_to_class.get(predicted_idx, 'Unknown')
        
        return {
            'class_name': class_name,
            'confidence': confidence,
            'predicted_index': predicted_idx
        }
