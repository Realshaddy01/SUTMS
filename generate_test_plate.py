"""
Generate a test license plate image for testing the OCR system.
"""
import cv2
import numpy as np
import argparse
import os

def generate_nepali_plate(text="BA 1 PA 1234", output_path="test_plate.jpg"):
    """
    Generate a simple Nepali-style license plate image.
    
    Args:
        text: The license plate text
        output_path: Path to save the generated image
        
    Returns:
        Path to the generated image
    """
    # Create a blank white image (plate background)
    plate_width = 440
    plate_height = 140
    plate = np.ones((plate_height, plate_width, 3), dtype=np.uint8) * 255
    
    # Add black border
    border_thickness = 4
    cv2.rectangle(
        plate,
        (border_thickness, border_thickness),
        (plate_width - border_thickness, plate_height - border_thickness),
        (0, 0, 0),
        border_thickness
    )
    
    # Add text
    font = cv2.FONT_HERSHEY_SIMPLEX
    font_scale = 2.0
    font_thickness = 3
    text_color = (0, 0, 0)
    text_position = (20, 90)
    
    cv2.putText(
        plate,
        text,
        text_position,
        font,
        font_scale,
        text_color,
        font_thickness,
        cv2.LINE_AA
    )
    
    # Optional: Add some noise and blur to make it more realistic
    noise = np.random.normal(0, 5, plate.shape).astype(np.uint8)
    plate = cv2.add(plate, noise)
    plate = cv2.GaussianBlur(plate, (3, 3), 0)
    
    # Save the image
    cv2.imwrite(output_path, plate)
    print(f"Generated test license plate image at {output_path}")
    
    return output_path

def main():
    parser = argparse.ArgumentParser(description='Generate test license plate image')
    parser.add_argument('--text', default="BA 1 PA 1234", help='License plate text')
    parser.add_argument('--output', default="test_plate.jpg", help='Output image path')
    
    args = parser.parse_args()
    generate_nepali_plate(args.text, args.output)

if __name__ == '__main__':
    main()