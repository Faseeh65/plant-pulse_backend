import zipfile
import os
import shutil

zip_path = r'd:\Plant Pulse FYP\.temp\Plant Village.zip'
extract_temp = r'd:\Plant_Dataset_Temp'
final_dest = r'd:\Plant_Dataset'

print('Extracting ZIP...')
with zipfile.ZipFile(zip_path, 'r') as zip_ref:
    zip_ref.extractall(extract_temp)

print('Moving folders...')
train_src = os.path.join(extract_temp, 'New Plant Diseases Dataset(Augmented)', 'New Plant Diseases Dataset(Augmented)', 'train')
valid_src = os.path.join(extract_temp, 'New Plant Diseases Dataset(Augmented)', 'New Plant Diseases Dataset(Augmented)', 'valid')

os.makedirs(final_dest, exist_ok=True)
shutil.move(train_src, os.path.join(final_dest, 'train'))
shutil.move(valid_src, os.path.join(final_dest, 'val'))

print('Cleaning up...')
shutil.rmtree(extract_temp)
print('Extract Complete!')
