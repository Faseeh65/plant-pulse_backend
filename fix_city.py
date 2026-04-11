import zipfile
import os
import shutil

zip_path = r'D:\Plant Pulse FYP\.temp\Plant City.zip'
extract_temp = r'D:\Plant_City_Temp'
final_dest = r'D:\Plant Pulse FYP\Plant_City'

# Quick dictionary to force alignment specifically to bypass the Label Mess
KNOWN_MAP = {
    "Apple Normal": "Apple___healthy",
    "Apple black_spot": "Apple___Black_rot",
    "Apple Brown_spot": "Apple___Brown_spot",
    "tomato_healthy_leaf": "Tomato___healthy",
    "tomato_early_blight": "Tomato___Early_blight",
    "tomato_late_blight": "Tomato___Late_blight",
    "tomato_septoria_leaf": "Tomato___Septoria_leaf_spot",
    "tomato_leaf_mold": "Tomato___Leaf_Mold",
    "tomato_bacterial_spot": "Tomato___Bacterial_spot",
    "tomato_leaf_miner": "Tomato___Leaf_Miner",
    "tomato_leaf_curl": "Tomato___Tomato_Yellow_Leaf_Curl_Virus",
    "tomato spider mites": "Tomato___Spider_mites Two-spotted_spider_mite",
    "tomato verticillium wilt": "Tomato___Verticillium_wilt",
    "tomato Fusarium Wilt": "Tomato___Fusarium_wilt",
    
    "Corn Normal leaf": "Corn_(maize)___healthy",
    "Corn gray leaf spot": "Corn_(maize)___Cercospora_leaf_spot Gray_leaf_spot",
    "Corn Fungal leaf": "Corn_(maize)___Fungal_leaf",
    "Corn holcus_ leaf spot": "Corn_(maize)___Holcus_leaf_spot",
    
    "Grape Normal_leaf": "Grape___healthy",
    "Grape Anthracnose leaf": "Grape___Anthracnose",
    "Grape Brown spot leaf": "Grape___Brown_spot",
    "Grape Downy mildew leaf": "Grape___Downy_mildew",
    "Grape Powdery_mildew leaf": "Grape___Powdery_mildew",
    "Grape Mites_leaf disease": "Grape___Mites",
    "Grape shot hole leaf disease": "Grape___Shot_hole",
    
    "Cherry Normal leaf": "Cherry_(including_sour)___healthy",
    "Cherry Leaf Scorch": "Cherry_(including_sour)___Leaf_Scorch",
    "Cherry brown_spot": "Cherry_(including_sour)___Brown_spot",
    "Cherry purple leaf spot": "Cherry_(including_sour)___Purple_leaf_spot",
    "Cherry_shot hole disease": "Cherry_(including_sour)___Shot_hole",
}

print('Extracting City ZIP (This might take a minute)...')
with zipfile.ZipFile(zip_path, 'r') as zip_ref:
    zip_ref.extractall(extract_temp)

print('Restructuring logic...')
# The inner folder inside the zip is 'PlantCity'
train_src = os.path.join(extract_temp, 'PlantCity', 'train')
valid_src = os.path.join(extract_temp, 'PlantCity', 'valid')

os.makedirs(os.path.join(final_dest, 'train'), exist_ok=True)
os.makedirs(os.path.join(final_dest, 'val'), exist_ok=True)

def harmonize_folders(src_dir, dest_dir):
    if not os.path.exists(src_dir): 
        print(f"Source dir {src_dir} not found")
        return
    for folder in os.listdir(src_dir):
        mapped_name = KNOWN_MAP.get(folder)
        if not mapped_name:
            # Fallback alignment (e.g., "Apricot shot_hole" -> "Apricot___shot_hole")
            parts = folder.split(' ', 1)
            if len(parts) == 2:
                mapped_name = f"{parts[0].capitalize()}___{parts[1].replace(' ', '_')}"
            else:
                mapped_name = folder.capitalize()
        
        src_path = os.path.join(src_dir, folder)
        dest_path = os.path.join(dest_dir, mapped_name)
        
        if not os.path.exists(dest_path):
            os.makedirs(dest_path)
            
        for file in os.listdir(src_path):
            shutil.move(os.path.join(src_path, file), os.path.join(dest_path, file))

harmonize_folders(train_src, os.path.join(final_dest, 'train'))
harmonize_folders(valid_src, os.path.join(final_dest, 'val'))

print('Cleaning temps...')
try:
    shutil.rmtree(extract_temp)
except:
    pass

print('Harmonization Extractor Complete.')
