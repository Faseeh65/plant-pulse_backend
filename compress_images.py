import os
from PIL import Image

image_dir = r"d:\Plant Pulse FYP\assets\images"
for filename in os.listdir(image_dir):
    if filename.lower().endswith(('.png', '.jpg', '.jpeg')):
        filepath = os.path.join(image_dir, filename)
        filesize = os.path.getsize(filepath)
        if filesize > 500 * 1024: # > 500KB
            print(f"Compressing {filename} ({filesize/1024:.2f} KB)...")
            img = Image.open(filepath)
            
            # Convert to WebP
            name, _ = os.path.splitext(filename)
            webp_path = os.path.join(image_dir, name + ".webp")
            
            # Save as webp
            img.save(webp_path, "webp", quality=80, method=6)
            
            # Check size after compression
            new_size = os.path.getsize(webp_path)
            print(f"-> Saved as {name}.webp ({new_size/1024:.2f} KB)")
            
            # If successfully compressed and it's much smaller, remove original
            if new_size < filesize:
                os.remove(filepath)
                print(f"-> Removed original {filename}")
print("Compression complete.")
