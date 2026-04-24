import numpy as np
import tensorflow as tf
import json
from PIL import Image
import io
import os

class RiceInferenceEngine:
    def __init__(self, model_path, labels_path=None, categories=None):
        print("--- RICE INFERENCE ENGINE V2 (MULTI-INPUT) ---")
        
        # 1. Existence Checks
        if not os.path.exists(model_path):
            print(f"ERROR: Model file NOT FOUND at: {model_path}")
            raise FileNotFoundError(f"Model file missing: {model_path}")

        try:
            # 2. Load TFLite Model
            print("Interpreter: Loading TFLite Interpreter...")
            self.interpreter = tf.lite.Interpreter(model_path=model_path)
            self.interpreter.allocate_tensors()
            
            self.input_details = self.interpreter.get_input_details()
            self.output_details = self.interpreter.get_output_details()
            
            # 3. Log Architecture Details
            print(f"SUCCESS: Interpreter Ready.")
            print(f"Detected Inputs: {len(self.input_details)}") 
            # V2 usually shows 2 inputs here
            
            # 4. Load Labels
            if categories:
                self.idx_to_class = {i: cat for i, cat in enumerate(categories)}
            elif labels_path and os.path.exists(labels_path):
                with open(labels_path, 'r') as f:
                    self.class_indices = json.load(f)
                self.idx_to_class = {int(k): v for k, v in self.class_indices.items()}
            else:
                num_classes = self.output_details[0]['shape'][-1]
                self.idx_to_class = {i: f"Class_{i}" for i in range(num_classes)}
            
            print(f"SUCCESS: Loaded {len(self.idx_to_class)} classes.")
            print("---------------------------------------------")

        except Exception as e:
            print(f"CRITICAL LOAD FAILURE: {e}")
            raise RuntimeError(f"Engine initialization failed: {e}")

    def preprocess(self, image_bytes):
        try:
            img = Image.open(io.BytesIO(image_bytes))
            
            # 1. Get expected input shape
            # Determine expected channels from model metadata (look for the RGB input)
            rgb_input = next((d for d in self.input_details if d['shape'][-1] == 3), self.input_details[0])
            expected_channels = rgb_input['shape'][-1]
            
            # 2. Convert image to match expected channels
            if expected_channels == 1:
                img = img.convert('L') # Grayscale
            elif expected_channels == 3:
                img = img.convert('RGB')
            elif expected_channels == 4:
                img = img.convert('RGB')
            
            # 1. Resize and Normalize
            img = img.resize((224, 224))
            img_array = np.array(img, dtype=np.float32)
            img_array = img_array / 255.0

            # 2. Add Batch Dimension (1, 224, 224, 3)
            img_array = np.expand_dims(img_array, axis=0)

               # 3. Handle Grayscale vs Color
            # If the image was grayscale, it would be (1, 224, 224). 
            # We add the 1 at the end to make it (1, 224, 224, 1)
            if len(img_array.shape) == 3: 
                img_array = np.expand_dims(img_array, axis=-1)
                
            return img_array
        except Exception as e:
            print(f"ERROR: Preprocessing Error: {e}")
            raise

    def predict(self, image_bytes):
        # 1. Prepare the Image Data
        input_data = self.preprocess(image_bytes)
        
        # 2. Prepare the Dummy Mask (Required for V2 Model)
        # We use all ones (1.0) to tell the model to pay attention to the whole image
        if len(self.input_details) > 1:
            dummy_shape = self.input_details[1]['shape']
            dummy_mask = np.ones((1, 224, 224, 1), dtype=np.float32)
        else:
            dummy_mask = None

        try:
            # 3. Set Tensors (Dynamic Shape-Based Mapping)
            rgb_index = None
            mask_index = None
            
            for detail in self.input_details:
                if detail['shape'][-1] == 3:
                    rgb_index = detail['index']
                elif detail['shape'][-1] == 1:
                    mask_index = detail['index']

            # --- DIAGNOSTIC LOGS ---
            print(f"DEBUG: Found RGB Index: {rgb_index}, Mask Index: {mask_index}")
            print(f"DEBUG: input_data shape: {input_data.shape}")
            print(f"DEBUG: dummy_mask shape: {dummy_mask.shape if dummy_mask is not None else 'None'}")
            # -----------------------

            # Feed the Image
            if rgb_index is not None:
                self.interpreter.set_tensor(rgb_index, input_data)
            
            # Feed the Mask
            if mask_index is not None:
                self.interpreter.set_tensor(mask_index, dummy_mask)
            
            # 4. Run Inference
            self.interpreter.invoke()
            
            # 5. Get Output
            output = self.interpreter.get_tensor(self.output_details[0]['index'])
            
            predicted_idx = int(np.argmax(output[0]))
            confidence = float(np.max(output[0]))
            class_name = self.idx_to_class.get(predicted_idx, 'Unknown')
            
            print(f"DEBUG: Predicted Index: {predicted_idx} | Confidence: {confidence:.4f} | Class: {class_name}")
            
            return {
                'class_name': class_name,
                'confidence': confidence,
                'predicted_index': predicted_idx
            }
        except Exception as e:
            print(f"ERROR: Inference Runtime Error: {e}")
            raise