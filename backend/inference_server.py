import numpy as np
import tensorflow as tf
import json
from PIL import Image
import io

class RiceInferenceEngine:
    def __init__(self, model_path, labels_path):
        print("Loading model: rice_fusion_v2.tflite")
        self.interpreter = tf.lite.Interpreter(
            model_path=model_path)
        self.interpreter.allocate_tensors()
        self.input_details = \
            self.interpreter.get_input_details()
        self.output_details = \
            self.interpreter.get_output_details()
        with open(labels_path, 'r') as f:
            self.class_indices = json.load(f)
        self.idx_to_class = {
            int(k): v 
            for k, v in self.class_indices.items()
        }
        print(f"Model loaded with "
              f"{len(self.idx_to_class)} classes")
        print(f"Classes: {list(self.idx_to_class.values())}")

    def preprocess(self, image_bytes):
        img = Image.open(io.BytesIO(image_bytes))
        img = img.convert('RGB')
        img = img.resize((224, 224))
        img_array = np.array(img, dtype=np.float32)
        img_array = img_array / 255.0
        img_array = np.expand_dims(img_array, axis=0)
        return img_array

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
        class_name = self.idx_to_class.get(
            predicted_idx, 'Unknown')
        return {
            'class_name': class_name,
            'confidence': confidence,
            'predicted_index': predicted_idx
        }
