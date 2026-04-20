from PIL import Image

def optimize_flutter_icon(input_path, output_path, margin=30, target_size=(1024, 1024)):
    # Open the image
    img = Image.open(input_path).convert("RGBA")

    # Get the bounding box of the actual logo (crops out transparent/black space)
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)

    # Calculate the maximum size the logo can be while respecting the margins
    target_content_size = (target_size[0] - (2 * margin), target_size[1] - (2 * margin))

    # Resize the logo to fit this new bounded area (maintaining aspect ratio)
    img.thumbnail(target_content_size, Image.Resampling.LANCZOS)

    # Create the final 1024x1024 canvas with a transparent background
    final_img = Image.new("RGBA", target_size, (0, 0, 0, 0))

    # Calculate exactly where to paste the logo so it remains perfectly centered
    paste_x = (target_size[0] - img.width) // 2
    paste_y = (target_size[1] - img.height) // 2
    final_img.paste(img, (paste_x, paste_y), img)

    # Save the properly formatted icon
    final_img.save(output_path, "PNG")
    print(f"Icon perfectly scaled and saved to: {output_path}")

# Run the function on your file
optimize_flutter_icon('Logo.jpeg', 'flutter_icon_1024.png')
