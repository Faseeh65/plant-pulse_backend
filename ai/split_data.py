import splitfolders

# Replace 'path/to/your/raw_data' with where your dataset is right now
# Based on your input, assuming the dataset is here
input_folder = "C:/Users/LENOVO/Desktop/Plant_Dataset" 
output_folder = "C:/Users/LENOVO/Desktop/PlantPulse_Split"

# Split: 80% Train, 20% Validation
splitfolders.ratio(input_folder, output=output_folder, seed=1337, ratio=(.8, .2), group_prefix=None)

print("✅ Dataset split successfully!")
