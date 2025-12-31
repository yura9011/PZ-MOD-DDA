"""
Generate radiation overlay textures for ChargedStrike mod.
Creates simple solid color PNG files that will be tinted by the overlay system.
"""

from PIL import Image
import os

# Output directory (same as this script)
OUTPUT_DIR = os.path.dirname(os.path.abspath(__file__))

# Texture size (will be scaled to screen size in-game)
WIDTH = 1920
HEIGHT = 1080

# Radiation colors (RGB)
COLORS = {
    "radiation_green": (0, 255, 0),
    "radiation_violet": (128, 0, 255),
    "radiation_red": (255, 0, 0),
}

def create_solid_overlay(name, color):
    """Create a solid color overlay texture."""
    # Create RGBA image with full opacity
    img = Image.new("RGBA", (WIDTH, HEIGHT), (*color, 255))
    
    # Save as PNG
    filepath = os.path.join(OUTPUT_DIR, f"{name}.png")
    img.save(filepath, "PNG")
    print(f"Created: {filepath}")

def create_vignette_overlay(name, color):
    """Create a vignette-style overlay texture (darker at edges)."""
    img = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    pixels = img.load()
    
    center_x = WIDTH // 2
    center_y = HEIGHT // 2
    max_dist = ((center_x ** 2) + (center_y ** 2)) ** 0.5
    
    for y in range(HEIGHT):
        for x in range(WIDTH):
            # Calculate distance from center
            dist = ((x - center_x) ** 2 + (y - center_y) ** 2) ** 0.5
            # Normalize and create vignette effect
            intensity = min(1.0, dist / max_dist)
            alpha = int(255 * intensity * 0.8)  # Max 80% opacity at edges
            pixels[x, y] = (*color, alpha)
    
    filepath = os.path.join(OUTPUT_DIR, f"{name}.png")
    img.save(filepath, "PNG")
    print(f"Created (vignette): {filepath}")

def main():
    print("Generating radiation overlay textures...")
    print(f"Output directory: {OUTPUT_DIR}")
    print(f"Size: {WIDTH}x{HEIGHT}")
    print()
    
    for name, color in COLORS.items():
        create_solid_overlay(name, color)
    
    print()
    print("Done! Textures created successfully.")
    print("The overlay system will control transparency via alpha parameter.")

if __name__ == "__main__":
    main()
