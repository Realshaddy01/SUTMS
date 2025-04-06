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
    # Create a blank high-contrast background - optimized for OCR readability
    plate_width = 600
    plate_height = 180
    # White background works best for OCR
    plate = np.ones((plate_height, plate_width, 3), dtype=np.uint8) * 255
    
    # Add black border
    border_thickness = 5
    cv2.rectangle(
        plate,
        (border_thickness, border_thickness),
        (plate_width - border_thickness, plate_height - border_thickness),
        (0, 0, 0),
        border_thickness
    )
    
    # Split the text to position components better
    parts = text.split()
    
    # Font settings for better OCR readability - using even more OCR-friendly font
    font = cv2.FONT_HERSHEY_SIMPLEX
    text_color = (0, 0, 0)
    
    # Calculate text width for better positioning
    def get_text_width(text, font_face, font_scale, thickness):
        return cv2.getTextSize(text, font_face, font_scale, thickness)[0][0]
    
    # Draw each part of the license plate text with optimal spacing
    if len(parts) == 4:  # Format: BA 1 PA 1234
        # Get total width of all parts
        p1_width = get_text_width(parts[0], font, 2.5, 4)
        p2_width = get_text_width(parts[1], font, 2.5, 4)
        p3_width = get_text_width(parts[2], font, 2.5, 4)
        p4_width = get_text_width(parts[3], font, 2.5, 5)
        
        # Calculate spacing for even distribution
        total_width = p1_width + p2_width + p3_width + p4_width
        spacing = (plate_width - 60 - total_width) / 3  # 30px padding on each side
        
        # Start position for first part
        x_pos = 30
        
        # Province code (e.g., BA)
        cv2.putText(
            plate,
            parts[0],
            (x_pos, 100),
            font,
            2.5,
            text_color,
            4,
            cv2.LINE_AA
        )
        x_pos += p1_width + int(spacing)
        
        # Vehicle class (e.g., 1)
        cv2.putText(
            plate,
            parts[1],
            (x_pos, 100),
            font,
            2.5,
            text_color,
            4,
            cv2.LINE_AA
        )
        x_pos += p2_width + int(spacing)
        
        # Serial letters (e.g., PA)
        cv2.putText(
            plate,
            parts[2],
            (x_pos, 100),
            font,
            2.5,
            text_color,
            4,
            cv2.LINE_AA
        )
        x_pos += p3_width + int(spacing)
        
        # Number (e.g., 1234)
        cv2.putText(
            plate,
            parts[3],
            (x_pos, 100),
            font,
            2.5,
            text_color,
            5,  # Thicker for numbers
            cv2.LINE_AA
        )
    else:
        # Fallback if text format is different
        cv2.putText(
            plate,
            text,
            (30, 100),
            font,
            2.5,
            text_color,
            4,
            cv2.LINE_AA
        )
    
    # Skip adding noise for maximum OCR readability
    # Clean images work better with OCR than realistic ones
    
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