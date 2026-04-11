import zipfile
zip_path = r'D:\Plant Pulse FYP\.temp\Plant City.zip'
with zipfile.ZipFile(zip_path, 'r') as zip_ref:
    for name in zip_ref.namelist()[::5000]:
        print(name)
