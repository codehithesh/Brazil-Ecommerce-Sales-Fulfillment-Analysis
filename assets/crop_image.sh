#!/bin/bash

"""
chmod +x crop_image.sh

./crop_image.sh \
  --input banner_img.jpg \
  --output banner.jpg \
  --width 900 \
  --height 339 \
  --position bottom-left

Positions: top-left, top-right, bottom-left, bottom-right  
"""

# Default values
WIDTH=900
HEIGHT=339
POSITION="center"
INPUT_IMAGE=""
OUTPUT_IMAGE=""

# Parse named parameters
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -i|--input) INPUT_IMAGE="$2"; shift ;;
        -o|--output) OUTPUT_IMAGE="$2"; shift ;;
        -w|--width) WIDTH="$2"; shift ;;
        -h|--height) HEIGHT="$2"; shift ;;
        -p|--position) POSITION="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

# Validate required arguments
if [ -z "$INPUT_IMAGE" ] || [ -z "$OUTPUT_IMAGE" ]; then
    echo "Error: Missing required arguments."
    echo "Usage: $0 -i <input_image> -o <output_image> [-w width] [-h height] [-p position]"
    echo "Positions: center, top-left, top-right, bottom-left, bottom-right"
    exit 1
fi

echo "==> Checking for Python3..."
if ! command -v python3 &> /dev/null; then
    echo "Error: python3 is required but not installed."
    exit 1
fi

echo "==> Ensuring Pillow is installed..."
python3 -m pip install Pillow --quiet

echo "==> Cropping $INPUT_IMAGE -> $OUTPUT_IMAGE (${WIDTH}x${HEIGHT}) from [$POSITION]"

# Run the inline Python script with passed parameters
python3 - <<EOF
from PIL import Image
import sys

input_path = "$INPUT_IMAGE"
output_path = "$OUTPUT_IMAGE"
width = int("$WIDTH")
height = int("$HEIGHT")
position = "$POSITION".lower()

try:
    with Image.open(input_path) as img:
        img_w, img_h = img.size
        
        # Validate that image is large enough for the crop
        if width > img_w or height > img_h:
            print(f"Error: Target size ({width}x{height}) is larger than image size ({img_w}x{img_h}).")
            sys.exit(1)
        
        # Calculate bounding box (left, upper, right, lower) based on position
        if position == "center":
            left = (img_w - width) // 2
            upper = (img_h - height) // 2
            right = left + width
            lower = upper + height
            box = (left, upper, right, lower)
        elif position == "top-left":
            box = (0, 0, width, height)
        elif position == "top-right":
            box = (img_w - width, 0, img_w, height)
        elif position == "bottom-left":
            box = (0, img_h - height, width, img_h)
        elif position == "bottom-right":
            box = (img_w - width, img_h - height, img_w, img_h)
        else:
            print(f"Error: Invalid position '{position}'. Choose from center, top-left, top-right, bottom-left, bottom-right.")
            sys.exit(1)
            
        cropped_img = img.crop(box)
        cropped_img.save(output_path)
        print(f"Successfully cropped and saved to: {output_path}")
        
except FileNotFoundError:
    print(f"Error: The file '{input_path}' was not found.")
    sys.exit(1)
except Exception as e:
    print(f"An error occurred: {e}")
    sys.exit(1)
EOF