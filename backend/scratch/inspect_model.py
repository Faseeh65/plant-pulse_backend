import tensorflow as tf

interpreter = tf.lite.Interpreter(model_path="d:\\Plant Pulse FYP\\backend\\AI_Model\\model_v2.tflite")
interpreter.allocate_tensors()

input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

print("--- INPUT DETAILS ---")
for i, detail in enumerate(input_details):
    print(f"Input {i}: Name={detail['name']}, Shape={detail['shape']}, Type={detail['dtype']}, Index={detail['index']}")

print("\n--- OUTPUT DETAILS ---")
for i, detail in enumerate(output_details):
    print(f"Output {i}: Name={detail['name']}, Shape={detail['shape']}, Type={detail['dtype']}, Index={detail['index']}")
