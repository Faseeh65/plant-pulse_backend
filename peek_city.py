import zipfile

zip_path = r'd:\Plant Pulse FYP\.temp\Plant City.zip'
city_classes = set()

with zipfile.ZipFile(zip_path, 'r') as zip_ref:
    for name in zip_ref.namelist():
        # Typically looks like 'PlantCity/train/Tomato_Blight/IMG_1.jpg'
        parts = name.split('/')
        if len(parts) > 2 and parts[1] in ('train', 'valid', 'val') and parts[2]:
            city_classes.add(parts[2])

print("Classes in Plant City:")
for c in sorted(city_classes):
    print(c)
