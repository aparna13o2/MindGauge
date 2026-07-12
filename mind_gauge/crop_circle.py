from PIL import Image, ImageDraw

def create_circular_image(input_path, output_path):
    # Open the image
    img = Image.open(input_path).convert("RGBA")
    
    # Create a mask of the same size
    mask = Image.new("L", img.size, 0)
    draw = ImageDraw.Draw(mask)
    
    # Draw a white circle on the mask (zoomed in slightly to avoid black edges)
    # The image is 512x512. Let's crop it slightly inward by 8% (as we did in Flutter)
    width, height = img.size
    margin_x = int(width * 0.04)
    margin_y = int(height * 0.04)
    
    draw.ellipse((margin_x, margin_y, width - margin_x, height - margin_y), fill=255)
    
    # Apply the mask to the image
    circular_img = Image.new("RGBA", img.size, (0, 0, 0, 0))
    circular_img.paste(img, (0, 0), mask)
    
    # Crop the image to the bounding box of the circle to remove the extra transparent padding
    circular_img = circular_img.crop((margin_x, margin_y, width - margin_x, height - margin_y))
    
    # Save the result
    circular_img.save(output_path, "PNG")
    print(f"Saved circular image to {output_path}")

create_circular_image('assets/mind_gauge_logo.jpg', 'assets/mind_gauge_logo_circle.png')
