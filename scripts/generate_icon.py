#!/usr/bin/env python3
"""Generate Redact1 app icon - blue shield with redaction bars and gold 1"""

from PIL import Image, ImageDraw, ImageFont
import os

def create_shield_path(draw, x, y, width, height):
    """Create shield shape points"""
    # Shield with flat top, angled shoulders, curved bottom
    points = [
        (x + width * 0.1, y + height * 0.05),   # top left
        (x + width * 0.9, y + height * 0.05),   # top right
        (x + width * 0.9, y + height * 0.55),   # right side
        (x + width * 0.5, y + height * 0.95),   # bottom point
        (x + width * 0.1, y + height * 0.55),   # left side
    ]
    return points

def generate_icon(size=1024):
    # Colors matching Police1
    navy_bg = (30, 41, 59)      # Dark navy background
    shield_blue = (59, 130, 246)  # Blue shield
    gold = (234, 179, 8)        # Gold/yellow for "1"
    black = (0, 0, 0)           # Black for redaction bars

    # Create image
    img = Image.new('RGB', (size, size), navy_bg)
    draw = ImageDraw.Draw(img)

    # Draw shield
    margin = size * 0.08
    shield_points = create_shield_path(draw, margin, margin, size - 2*margin, size - 2*margin)
    draw.polygon(shield_points, fill=shield_blue)

    # Draw redaction bars on shield
    bar_height = size * 0.06
    bar_width = size * 0.45
    bar_x = (size - bar_width) / 2

    # Three redaction bars
    bar_y_positions = [size * 0.22, size * 0.32, size * 0.42]
    for bar_y in bar_y_positions:
        draw.rectangle(
            [bar_x, bar_y, bar_x + bar_width, bar_y + bar_height],
            fill=black
        )

    # Draw gold "1"
    try:
        # Try system fonts
        font_size = int(size * 0.35)
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", font_size)
    except:
        font = ImageFont.load_default()

    text = "1"
    # Get text bounding box
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]

    # Position "1" below the redaction bars
    text_x = (size - text_width) / 2
    text_y = size * 0.48

    draw.text((text_x, text_y), text, font=font, fill=gold)

    return img

if __name__ == "__main__":
    # Generate icon
    icon = generate_icon(1024)

    # Save to Assets
    output_path = os.path.join(
        os.path.dirname(os.path.dirname(__file__)),
        "Redact1/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
    )

    icon.save(output_path, "PNG")
    print(f"Icon saved to {output_path}")
