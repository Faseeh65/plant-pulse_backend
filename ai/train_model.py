import os
import tensorflow as tf
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from tensorflow.keras.applications import MobileNetV2
from tensorflow.keras import layers, models

# 1. Setup paths (Use the output_folder from Step 2)
train_dir = "C:/Users/LENOVO/Desktop/PlantPulse_Split/train"
val_dir = "C:/Users/LENOVO/Desktop/PlantPulse_Split/val"

# 2. Data Augmentation (Making the AI "Stronger")
train_datagen = ImageDataGenerator(
    rescale=1./255,
    rotation_range=20,
    horizontal_flip=True,
    zoom_range=0.2
)
val_datagen = ImageDataGenerator(rescale=1./255)

train_gen = train_datagen.flow_from_directory(train_dir, target_size=(224, 224), batch_size=32, class_mode='categorical')
val_gen = val_datagen.flow_from_directory(val_dir, target_size=(224, 224), batch_size=32, class_mode='categorical')

# 3. Build the Brain (MobileNetV2)
base_model = MobileNetV2(input_shape=(224, 224, 3), include_top=False, weights='imagenet')
base_model.trainable = False # Freeze the base

model = models.Sequential([
    base_model,
    layers.GlobalAveragePooling2D(),
    layers.Dense(128, activation='relu'),
    layers.Dense(train_gen.num_classes, activation='softmax') # Output layer
])

model.compile(optimizer='adam', loss='categorical_crossentropy', metrics=['accuracy'])

# 4. Train!
print("🚀 Training starting... Go grab some chai, this will take a while.")
model.fit(train_gen, validation_data=val_gen, epochs=10)

# 5. Save the result
script_dir = os.path.dirname(os.path.abspath(__file__))
model_path = os.path.join(script_dir, "../assets/models/plant_pulse_model.h5")
model.save(model_path)
print(f"✅ Model saved as {model_path}")
