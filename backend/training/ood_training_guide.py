"""
PlantPulse — Out-of-Distribution (OOD) Rejection Training Guide
================================================================
Phase 2 ML Fix: Teach the model to explicitly reject non-plant images
by adding a "0_Background / Not_A_Leaf" class to the training dataset.

Author  : Senior ML Engineer — PlantPulse FYP
Python  : 3.10+
Framework: TensorFlow 2.x / Keras
Dataset  : PlantVillage (38 classes)

Usage
-----
1.  Collect background images (see BACKGROUND SOURCES below).
2.  Run `python ood_training_guide.py --mode=prepare` to
    organize the dataset.
3.  Run `python ood_training_guide.py --mode=train` to fine-tune.
4.  Run `python ood_training_guide.py --mode=evaluate` to verify OOD rejection.
5.  Convert the best checkpoint to TFLite for mobile deployment.
"""

import os
import shutil
import argparse
import pathlib
import random
import numpy as np
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers


# ─── CONFIG ───────────────────────────────────────────────────────────────────

DATA_ROOT       = pathlib.Path("dataset")           # PlantVillage root
BG_SOURCE_DIR   = pathlib.Path("background_images") # your OOD images
TRAIN_DIR       = DATA_ROOT / "train"
VAL_DIR         = DATA_ROOT / "val"
BACKGROUND_CLS  = "0_Background"  # sorts first alphabetically → index 0

IMG_SIZE    = (224, 224)
BATCH_SIZE  = 32
EPOCHS      = 15
LR          = 1e-4
CONFIDENCE_THRESHOLD = 0.85         # must match ScanGuard.kConfidenceThreshold
TFLITE_PATH = pathlib.Path("plantpulse_model.tflite")


# ─── STEP 1: BACKGROUND DATASET PREPARATION ───────────────────────────────────

"""
BACKGROUND SOURCES (collect ~1,000–2,000 images):
  ▸ Dirt / soil close-ups          → prevents soil confusion
  ▸ Human hands (plain + gloved)   → prevents hand photos
  ▸ Indoor rooms / walls           → prevents selfie-environment shots
  ▸ Plain paper / cardboard        → prevents white background traps
  ▸ Rocks and gravel               → prevents stone confusion
  ▸ Random ImageNet 'n01440764'    → diverse synthetic negatives
  ▸ COCO dataset random samples    → wide variety of non-plant scenes

WHY THIS WORKS:
  The model currently outputs the closest disease class for ANY input
  because it was never shown a "none of the above" example.
  By adding 0_Background, you give it an explicit escape hatch.
  At inference time, if the softmax confidence for 0_Background is the
  highest, the ScanGuard layer on the device also blocks it.
"""

def prepare_background_class(n_train: int = 1600, n_val: int = 400):
    """
    Copies background images into the training structure so Keras 
    ImageDataGenerator / tf.data treats it as a normal class.
    """
    bg_train = TRAIN_DIR / BACKGROUND_CLS
    bg_val   = VAL_DIR   / BACKGROUND_CLS
    bg_train.mkdir(parents=True, exist_ok=True)
    bg_val.mkdir(parents=True, exist_ok=True)

    all_imgs = sorted(BG_SOURCE_DIR.glob("**/*.jpg")) + \
               sorted(BG_SOURCE_DIR.glob("**/*.png"))

    random.shuffle(all_imgs)

    if len(all_imgs) < n_train + n_val:
        raise RuntimeError(
            f"Need at least {n_train + n_val} background images, "
            f"found {len(all_imgs)}. Collect more via the sources above."
        )

    for i, src in enumerate(all_imgs[:n_train]):
        shutil.copy(src, bg_train / f"bg_{i:05d}.jpg")

    for i, src in enumerate(all_imgs[n_train:n_train + n_val]):
        shutil.copy(src, bg_val / f"bg_{i:05d}.jpg")

    print(f"✅ Background class ready: {n_train} train | {n_val} val images.")


# ─── STEP 2: DATA PIPELINE ────────────────────────────────────────────────────

def build_datasets():
    """
    Builds tf.data pipelines with heavy augmentation on the background class
    to maximise OOD coverage diversity.
    """
    augment = keras.Sequential([
        layers.RandomFlip("horizontal_and_vertical"),
        layers.RandomRotation(0.3),
        layers.RandomZoom(0.2),
        layers.RandomBrightness(0.3),
        layers.RandomContrast(0.3),
    ], name="augmentation")

    def preprocess(img, label):
        img = tf.cast(img, tf.float32) / 255.0
        return img, label

    train_ds = keras.utils.image_dataset_from_directory(
        TRAIN_DIR,
        image_size=IMG_SIZE,
        batch_size=BATCH_SIZE,
        label_mode="categorical",
        shuffle=True,
        seed=42,
    )
    val_ds = keras.utils.image_dataset_from_directory(
        VAL_DIR,
        image_size=IMG_SIZE,
        batch_size=BATCH_SIZE,
        label_mode="categorical",
        shuffle=False,
    )

    class_names = train_ds.class_names
    num_classes = len(class_names)
    print(f"Classes ({num_classes}): {class_names}")
    assert BACKGROUND_CLS in class_names, \
        f"'{BACKGROUND_CLS}' not found in {TRAIN_DIR}. Run --mode=prepare first."

    train_ds = (
        train_ds
        .map(preprocess, num_parallel_calls=tf.data.AUTOTUNE)
        .map(lambda x, y: (augment(x, training=True), y),
             num_parallel_calls=tf.data.AUTOTUNE)
        .prefetch(tf.data.AUTOTUNE)
    )
    val_ds = (
        val_ds
        .map(preprocess, num_parallel_calls=tf.data.AUTOTUNE)
        .prefetch(tf.data.AUTOTUNE)
    )

    return train_ds, val_ds, class_names, num_classes


# ─── STEP 3: MODEL ARCHITECTURE ───────────────────────────────────────────────

def build_model(num_classes: int) -> keras.Model:
    """
    MobileNetV2 backbone (pretrained on ImageNet) + new classification head.
    Num_classes includes the new 0_Background class (i.e. 38 + 1 = 39).
    """
    base = keras.applications.MobileNetV2(
        input_shape=(*IMG_SIZE, 3),
        include_top=False,
        weights="imagenet",
    )
    # Freeze all but the last 30 layers for fine-tuning
    for layer in base.layers[:-30]:
        layer.trainable = False

    inputs  = keras.Input(shape=(*IMG_SIZE, 3))
    x       = base(inputs, training=False)
    x       = layers.GlobalAveragePooling2D()(x)
    x       = layers.Dropout(0.3)(x)
    # Label smoothing in loss helps calibrate overconfident predictions
    outputs = layers.Dense(num_classes, activation="softmax")(x)

    model = keras.Model(inputs, outputs)
    model.compile(
        optimizer=keras.optimizers.Adam(LR),
        loss=keras.losses.CategoricalCrossentropy(label_smoothing=0.1),
        metrics=["accuracy"],
    )
    return model


# ─── STEP 4: TRAINING ─────────────────────────────────────────────────────────

def train():
    train_ds, val_ds, class_names, num_classes = build_datasets()
    model = build_model(num_classes)
    model.summary()

    callbacks = [
        keras.callbacks.ModelCheckpoint(
            "best_plantpulse.keras",
            monitor="val_accuracy",
            save_best_only=True,
            verbose=1,
        ),
        keras.callbacks.EarlyStopping(
            monitor="val_accuracy",
            patience=4,
            restore_best_weights=True,
        ),
        keras.callbacks.ReduceLROnPlateau(
            monitor="val_loss",
            factor=0.5,
            patience=2,
            min_lr=1e-6,
            verbose=1,
        ),
    ]

    history = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=EPOCHS,
        callbacks=callbacks,
    )

    # Save class names alongside model for label mapping
    with open("class_names.txt", "w") as f:
        f.write("\n".join(class_names))

    print("✅ Training complete — best model saved to best_plantpulse.keras")
    return model, class_names


# ─── STEP 5: OOD EVALUATION ───────────────────────────────────────────────────

def evaluate_ood(model: keras.Model, class_names: list[str]):
    """
    Critical verification step.

    Tests the model on held-out background images it has never seen
    and reports the rejection rate at the CONFIDENCE_THRESHOLD.
    A production-ready model should reject ≥ 95% of OOD images.
    """
    bg_idx = class_names.index(BACKGROUND_CLS)

    # Load a random sample of held-out OOD images (not in train/val)
    ood_dir = pathlib.Path("ood_test_images")  # keep separate from training!
    if not ood_dir.exists():
        print(f"⚠️  {ood_dir} not found. Skipping OOD evaluation.")
        print("   Create this directory with images not used in training.")
        return

    ood_images = list(ood_dir.glob("**/*.jpg")) + list(ood_dir.glob("**/*.png"))
    if not ood_images:
        print("⚠️  No OOD test images found. Skipping.")
        return

    rejected = 0
    false_positives = []

    for img_path in ood_images:
        img = keras.utils.load_img(img_path, target_size=IMG_SIZE)
        arr = keras.utils.img_to_array(img) / 255.0
        arr = np.expand_dims(arr, 0)

        preds       = model.predict(arr, verbose=0)[0]
        top_idx     = int(np.argmax(preds))
        top_label   = class_names[top_idx]
        top_conf    = float(preds[top_idx])
        bg_conf     = float(preds[bg_idx])

        # Reject if: top class is Background OR confidence < threshold
        is_background = (top_idx == bg_idx)
        is_low_conf   = (top_conf < CONFIDENCE_THRESHOLD)

        if is_background or is_low_conf:
            rejected += 1
        else:
            false_positives.append({
                "file" :       img_path.name,
                "top_label":   top_label,
                "top_conf":    f"{top_conf:.1%}",
                "bg_conf":     f"{bg_conf:.1%}",
            })

    total        = len(ood_images)
    rejection_pct = (rejected / total) * 100

    print(f"\n{'='*60}")
    print(f"OOD REJECTION EVALUATION RESULTS")
    print(f"{'='*60}")
    print(f"Total OOD images tested : {total}")
    print(f"Correctly rejected      : {rejected} ({rejection_pct:.1f}%)")
    print(f"False positives         : {len(false_positives)}")
    print(f"Threshold used          : {CONFIDENCE_THRESHOLD:.0%}")
    print(f"{'─'*60}")

    if rejection_pct >= 95:
        print(f"✅ PASS — Model rejects {rejection_pct:.1f}% of OOD images (target ≥ 95%).")
    else:
        print(f"❌ FAIL — Only {rejection_pct:.1f}% rejected. Collect more background data.")

    if false_positives:
        print(f"\nFalse Positives (top {min(5, len(false_positives))}):")
        for fp in false_positives[:5]:
            print(f"  {fp['file']}: predicted '{fp['top_label']}' "
                  f"@ {fp['top_conf']} (bg={fp['bg_conf']})")


# ─── STEP 6: TFLITE CONVERSION ────────────────────────────────────────────────

def convert_to_tflite(model: keras.Model):
    """
    Converts the trained Keras model to Float16 TFLite for mobile deployment.
    Float16 halves model size with negligible accuracy loss on MobileNetV2.
    """
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_types = [tf.float16]

    tflite_model = converter.convert()
    TFLITE_PATH.write_bytes(tflite_model)
    size_mb = TFLITE_PATH.stat().st_size / (1024 * 1024)
    print(f"✅ TFLite model saved → {TFLITE_PATH} ({size_mb:.1f} MB)")


# ─── CLI ──────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="PlantPulse OOD Training Pipeline")
    parser.add_argument(
        "--mode",
        choices=["prepare", "train", "evaluate", "convert", "all"],
        default="all",
        help="Pipeline stage to run.",
    )
    args = parser.parse_args()

    if args.mode in ("prepare", "all"):
        print("\n[1/4] Preparing background class dataset...")
        prepare_background_class()

    if args.mode in ("train", "all"):
        print("\n[2/4] Training model with OOD class...")
        model, class_names = train()

    if args.mode in ("evaluate", "all"):
        if args.mode == "evaluate":
            # Load saved model for standalone evaluation
            model = keras.models.load_model("best_plantpulse.keras")
            with open("class_names.txt") as f:
                class_names = f.read().splitlines()
        print("\n[3/4] Evaluating OOD rejection rate...")
        evaluate_ood(model, class_names)

    if args.mode in ("convert", "all"):
        if args.mode == "convert":
            model = keras.models.load_model("best_plantpulse.keras")
        print("\n[4/4] Converting to TFLite (Float16)...")
        convert_to_tflite(model)

    print("\n✅ Pipeline complete.")
