import os
import numpy as np
import tensorflow as tf
from sklearn.metrics import classification_report, confusion_matrix

from data_pipeline import build_data_pipeline, DATASETS

# -------------------------------------------------------------
# Configuration
# -------------------------------------------------------------
# Hardcoded to Dual Dataset Hybrid Architecture
IMG_SIZE = (224, 224)
BATCH_SIZE = 32
EPOCHS = 1  # SANITY CHECK: Set to 1 Epoch as requested by User

def compute_weights_fast(dataset_paths):
    """
    Computes class weights instantly by scanning directory contents
    across multiple datasets and merging their raw counts.
    """
    global_classes = set()
    for ds_path in dataset_paths:
        train_dir = os.path.join(ds_path, 'train')
        if os.path.exists(train_dir):
            global_classes.update([d for d in os.listdir(train_dir) if os.path.isdir(os.path.join(train_dir, d))])
            
    GLOBAL_CLASSES = sorted(list(global_classes))
    y_train_counts = [0] * len(GLOBAL_CLASSES)
    
    for ds_path in dataset_paths:
        train_dir = os.path.join(ds_path, 'train')
        if not os.path.exists(train_dir): continue
        
        for i, cls_name in enumerate(GLOBAL_CLASSES):
            folder_path = os.path.join(train_dir, cls_name)
            if os.path.exists(folder_path):
                y_train_counts[i] += len([f for f in os.listdir(folder_path) if f.lower().endswith(('.png', '.jpg', '.jpeg'))])
                
    total_samples = sum(y_train_counts)
    num_classes = len(y_train_counts)
    
    class_weight_dict = {}
    for i, count in enumerate(y_train_counts):
        class_weight_dict[i] = total_samples / (num_classes * count) if count > 0 else 1.0
            
    return class_weight_dict

def main():
    print("🚀 Starting MobileNetV2 Transfer Learning Pipeline...")
    
    # 1. Pipeline & Disk Streaming
    train_ds, val_ds, class_names = build_data_pipeline(DATASETS, img_size=IMG_SIZE, batch_size=BATCH_SIZE)
    num_classes = len(class_names)
    
    # 2. Mitigating Class Imbalance (A-Grade Feature)
    print("⚖️ Calculating Class Weights to handle hybrid dataset imbalance...")
    class_weight_dict = compute_weights_fast(DATASETS)
    print(f"✅ Generated Class Weights mapping for {num_classes} classes.")
    
    # 3. Model Architecture Construction
    print("🧠 Building MobileNetV2 Model (Transfer Learning)...")
    
    # Data Augmentation strictly active ONLY during training (prevents validation data leakage)
    data_augmentation = tf.keras.Sequential([
        tf.keras.layers.RandomFlip("horizontal_and_vertical"),
        tf.keras.layers.RandomRotation(0.2),
        tf.keras.layers.RandomZoom(0.2),
    ])
    
    base_model = tf.keras.applications.MobileNetV2(
        input_shape=(224, 224, 3),
        include_top=False,
        weights='imagenet'
    )
    base_model.trainable = False # Freeze base layers initially
    
    model = tf.keras.Sequential([
        tf.keras.layers.InputLayer(shape=(224, 224, 3)),
        data_augmentation,
        base_model,
        tf.keras.layers.GlobalAveragePooling2D(),
        tf.keras.layers.Dense(128, activation='relu'),
        tf.keras.layers.Dropout(0.3),
        tf.keras.layers.Dense(num_classes, activation='softmax')
    ])
    
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=0.001),
        loss='categorical_crossentropy',
        metrics=['accuracy']
    )
    
    # 4. Training Callbacks (EarlyStopping & ModelCheckpoint)
    script_dir = os.path.dirname(os.path.abspath(__file__))
    assets_models_dir = os.path.join(script_dir, "../assets/models")
    os.makedirs(assets_models_dir, exist_ok=True)
    
    best_model_h5 = os.path.join(assets_models_dir, "plant_pulse_model.h5")
    
    callbacks = [
        tf.keras.callbacks.EarlyStopping(
            monitor='val_loss',
            patience=3, # Halt if no val_loss improvement for 3 epochs
            restore_best_weights=True,
            verbose=1
        ),
        tf.keras.callbacks.ModelCheckpoint(
            filepath=best_model_h5,
            monitor='val_accuracy',
            save_best_only=True,
            verbose=1
        )
    ]
    
    # 5. Execute Training
    print("🕒 Initiating training sequence. Go grab some Chai...")
    history = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=EPOCHS,
        class_weight=class_weight_dict,
        callbacks=callbacks
    )
    
    print(f"✅ Training completed. Best .h5 model saved to {best_model_h5}")
    
    # 6. Evaluation & The "Confusion Matrix" (A-Grade Feature)
    print("📊 Evaluating Validation Set performance...")
    
    # Unbatch the validation set once to extract true labels and generate predictions seamlessly
    y_true = []
    try:
        # Get true labels from validation stream
        for images, labels in val_ds.unbatch():
            y_true.append(tf.argmax(labels).numpy())
            
        print("🧠 Running inference on validation matrices...")
        predictions = model.predict(val_ds)
        y_pred = np.argmax(predictions, axis=-1)
        
        # Classification Report
        print("\n" + "="*60)
        print("              CLASSIFICATION REPORT")
        print("="*60)
        report = classification_report(y_true, y_pred, target_names=class_names)
        print(report)
        
        # Confusion Matrix Printout
        print("\n" + "="*60)
        print("                CONFUSION MATRIX")
        print("="*60)
        cm = confusion_matrix(y_true, y_pred)
        print(cm)
        print("\n💡 NOTE: Use this confusion matrix for your FYP Defense documentation.")
    except Exception as e:
        print(f"⚠️ Could not generate confusion matrix. (Usually happens if the path is invalid or dataset is empty). Error: {e}")
    
    # 7. Float16 Quantization TFLite Conversion (A-Grade Feature for Oppo F21 Pro)
    print("\n📦 Initializing TFLite Float16 Quantization for Mobile Inference...")
    try:
        converter = tf.lite.TFLiteConverter.from_keras_model(model)
        
        # Target float16 quantization to cut model size by 50% without dropping core accuracy
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.target_spec.supported_types = [tf.float16]
        
        tflite_model = converter.convert()
        
        tflite_path = os.path.join(assets_models_dir, "plant_pulse_model.tflite")
        with open(tflite_path, "wb") as f:
            f.write(tflite_model)
            
        print(f"🎉 SUCCESS! Quantized Float16 .tflite model deployed locally to: {tflite_path}")
        print("Your Phase 2C pipeline is fully established and optimized for mobile distribution.")
    except Exception as e:
        print(f"⚠️ Quantization failed. (Ensure you have run the training at least once). Error: {e}")
    
if __name__ == "__main__":
    main()
