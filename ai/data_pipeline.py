import os
import json
import numpy as np
import tensorflow as tf

DATASETS = [r'D:\Plant Pulse FYP\Plant_Village', r'D:\Plant Pulse FYP\Plant_City']

def build_data_pipeline(dataset_paths=DATASETS, img_size=(224, 224), batch_size=32):
    """
    Dual-Path Pipeline. Harmonizes multiple dataset paths strictly by aligning
    them across a unified Global Class Mapping structure before concatenation.
    """
    
    # 1. Discover all unique global classes across all dataset sources
    global_classes = set()
    for ds_path in dataset_paths:
        train_dir = os.path.join(ds_path, 'train')
        if os.path.exists(train_dir):
            global_classes.update([d for d in os.listdir(train_dir) if os.path.isdir(os.path.join(train_dir, d))])
            
    GLOBAL_CLASSES = sorted(list(global_classes))
    num_classes = len(GLOBAL_CLASSES)
    print(f"🌍 HARMONIZATION: Locked in {num_classes} unified classes spanning all datasets.")
    
    # 2. Source Verification Loading loops
    all_train_ds = []
    all_val_ds = []
    
    print("\n--- 🔬 FYP SOURCE VERIFICATION ---")
    for ds_path in dataset_paths:
        ds_name = os.path.basename(ds_path)
        train_dir = os.path.join(ds_path, 'train')
        val_dir = os.path.join(ds_path, 'val')
        
        if not os.path.exists(train_dir):
            print(f"⚠️ Skipping {ds_name}: Directory structure not resolved yet.")
            continue
            
        print(f"Loading matrices from {ds_name}...")
        
        # Load locally first to avoid directory mismatch errors
        train_ds_local = tf.keras.utils.image_dataset_from_directory(
            train_dir, image_size=img_size, batch_size=batch_size, 
            label_mode='int', shuffle=True
        )
        val_ds_local = tf.keras.utils.image_dataset_from_directory(
            val_dir, image_size=img_size, batch_size=batch_size, 
            label_mode='int', shuffle=False
        )
        
        local_classes = train_ds_local.class_names
        
        # Create a mapping from local index to global index
        lookup = np.array([GLOBAL_CLASSES.index(cls) for cls in local_classes])
        
        def map_labels(image, label):
            # Convert integer label to global one-hot categorical label
            global_idx = tf.gather(lookup, label)
            return image, tf.one_hot(global_idx, num_classes)

        train_ds = train_ds_local.map(map_labels, num_parallel_calls=tf.data.AUTOTUNE)
        val_ds = val_ds_local.map(map_labels, num_parallel_calls=tf.data.AUTOTUNE)
        
        all_train_ds.append(train_ds)
        all_val_ds.append(val_ds)
        
    print("----------------------------------\n")
    
    # 3. Concatenate the parallel pipelines
    if not all_train_ds:
        raise ValueError("No valid datasets loaded! Check paths.")
        
    final_train_ds = all_train_ds[0]
    final_val_ds = all_val_ds[0]
    
    for i in range(1, len(all_train_ds)):
        final_train_ds = final_train_ds.concatenate(all_train_ds[i])
        final_val_ds = final_val_ds.concatenate(all_val_ds[i])
    
    # Generate labels.json mapping for the Flutter App
    labels_dict = {str(i): name for i, name in enumerate(GLOBAL_CLASSES)}
    script_dir = os.path.dirname(os.path.abspath(__file__))
    assets_models_dir = os.path.join(script_dir, "../assets/models")
    os.makedirs(assets_models_dir, exist_ok=True)
    
    labels_path = os.path.join(assets_models_dir, "labels.json")
    with open(labels_path, 'w', encoding='utf-8') as f:
        json.dump(labels_dict, f, indent=4)
        
    print(f"✅ Auto-generated unified Flutter mapping at: {labels_path}")

    # 4. Memory Management & Strict Initialization
    AUTOTUNE = tf.data.AUTOTUNE
    
    # Standardization: Forcing Image values explicitly onto the [0, 1] range as requested
    def preprocess(image, label):
        image = tf.cast(image, tf.float32) / 255.0
        return image, label

    final_train_ds = final_train_ds.map(preprocess, num_parallel_calls=AUTOTUNE)
    final_val_ds = final_val_ds.map(preprocess, num_parallel_calls=AUTOTUNE)
    
    final_train_ds = final_train_ds.cache().prefetch(buffer_size=AUTOTUNE)
    final_val_ds = final_val_ds.cache().prefetch(buffer_size=AUTOTUNE)

    return final_train_ds, final_val_ds, GLOBAL_CLASSES

if __name__ == "__main__":
    print("Executing Hybrid Data Pipeline to generate properties...")
    try:
        build_data_pipeline(DATASETS, img_size=(224, 224), batch_size=32)
    except Exception as e:
        print(f"PIPELINE HALTED: {e}")
