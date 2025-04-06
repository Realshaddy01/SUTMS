"""
A simplified script to test license plate detection and OCR functionality directly.
"""
import sys
import cv2
import numpy as np
import time
import os
import re
from pathlib import Path

# Import pytesseract for OCR
try:
    import pytesseract
    TESSERACT_AVAILABLE = True
except ImportError:
    print("Warning: pytesseract not installed. OCR functionality will be limited.")
    TESSERACT_AVAILABLE = False

def post_process_nepali_plate(text):
    """
    Apply post-processing corrections for Nepali license plate format.
    Standard format is: Province Code + 1 or 2 Digit Number + 1 or 2 Letters + 4 Digit Number
    Example: BA 1 PA 1234 or LU 11 KHA 5678
    
    Args:
        text: Raw OCR output text
        
    Returns:
        Processed text following the Nepali license plate format
    """
    if not text:
        return text
        
    # Remove any special characters or punctuation
    text = re.sub(r'[^\w\s]', '', text)
    
    # Common OCR errors in license plates (correcting letters to digits)
    replacements = {
        'O': '0',  # Often 'O' is confused with '0'
        'I': '1',  # Often 'I' is confused with '1'
        'Z': '2',  # Often 'Z' is confused with '2'
        'A': '4',  # Sometimes 'A' is confused with '4'
        'S': '5',  # Sometimes 'S' is confused with '5'
        'G': '6',  # Sometimes 'G' is confused with '6'
        'T': '7',  # Sometimes 'T' is confused with '7'
        'B': '8',  # Sometimes 'B' is confused with '8'
    }
    
    # Try to extract components using regex
    # Looking for pattern like "XX 1 XX 1234" where X is a letter and 1 is a digit
    pattern = r'([A-Z]{1,2})\s*(\d{1,2})\s*([A-Z]{1,2})\s*(\d{1,4})'
    match = re.search(pattern, text)
    
    if match:
        province = match.group(1)
        vehicle_class = match.group(2)
        letters = match.group(3)
        numbers = match.group(4)
        
        # Format the result correctly
        return f"{province} {vehicle_class} {letters} {numbers}"
    
    # If the regex doesn't match, try to fix common errors and apply some heuristics
    parts = text.split()
    result = []
    
    # Most Nepali license plates have 4 parts
    if len(parts) >= 1:
        # First part should be province code (BA, LU, etc)
        p1 = parts[0]
        # Keep only letters for the province code
        p1 = ''.join(c for c in p1 if c.isalpha())
        if len(p1) > 2:
            p1 = p1[:2]  # Limit to 2 letters max
        result.append(p1)
    
    if len(parts) >= 2:
        # Second part should be a number (1-99)
        p2 = parts[1]
        # Keep only digits
        p2 = ''.join(c for c in p2 if c.isdigit())
        if not p2:
            # If no digits, try to convert common letter errors
            p2 = ''.join(replacements.get(c, c) for c in parts[1])
            p2 = ''.join(c for c in p2 if c.isdigit())
        if not p2:
            p2 = '1'  # Default if we can't extract a number
        result.append(p2)
    
    if len(parts) >= 3:
        # Third part should be letters (PA, KHA, etc)
        p3 = parts[2]
        # Keep only letters
        p3 = ''.join(c for c in p3 if c.isalpha())
        if len(p3) > 2:
            p3 = p3[:2]  # Limit to 2 letters max
        result.append(p3)
    
    if len(parts) >= 4:
        # Fourth part should be a 4-digit number
        p4 = parts[3]
        # Keep only digits
        p4 = ''.join(c for c in p4 if c.isdigit())
        if not p4:
            # If no digits, try to convert common letter errors
            p4 = ''.join(replacements.get(c, c) for c in parts[3])
            p4 = ''.join(c for c in p4 if c.isdigit())
        # Padding to ensure 4 digits
        while len(p4) < 4:
            p4 += '0'
        if len(p4) > 4:
            p4 = p4[:4]  # Limit to 4 digits
        result.append(p4)
    
    # Join the parts with spaces
    return ' '.join(result)

def detect_license_plate(image_path):
    """
    A simplified version of license plate detection.
    Based on contour detection which works well for high-contrast license plates.
    
    Args:
        image_path: Path to the image file
        
    Returns:
        Dictionary with detection results
    """
    print(f"Processing image: {image_path}")
    start_time = time.time()
    
    # Read the image
    img = cv2.imread(image_path)
    if img is None:
        return {"success": False, "error": "Failed to read image"}
    
    # Convert to HSV for better color segmentation (helps with yellow plates)
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    
    # Define color ranges for yellow license plates (common in Nepal)
    lower_yellow = np.array([15, 100, 100])
    upper_yellow = np.array([35, 255, 255])
    
    # Create mask for yellow regions
    yellow_mask = cv2.inRange(hsv, lower_yellow, upper_yellow)
    
    # Apply morphological operations to clean up the mask
    kernel = np.ones((5, 5), np.uint8)
    yellow_mask = cv2.erode(yellow_mask, kernel, iterations=1)
    yellow_mask = cv2.dilate(yellow_mask, kernel, iterations=2)
    
    # Also try edge detection on grayscale for plates that aren't yellow
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    blur = cv2.GaussianBlur(gray, (5, 5), 0)
    edges = cv2.Canny(blur, 50, 150)
    
    # Combine yellow mask with edge detection
    combined = cv2.bitwise_or(yellow_mask, edges)
    
    # Dilate to connect edges
    kernel = np.ones((3, 3), np.uint8)
    dilated = cv2.dilate(combined, kernel, iterations=2)
    
    # Find contours
    contours, _ = cv2.findContours(dilated, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    
    # Sort by area
    contours = sorted(contours, key=cv2.contourArea, reverse=True)[:10]
    
    plates = []
    boxes = []
    
    # Check each contour for license plate characteristics
    MIN_PLATE_AREA = 1500  # Reduced minimum area to catch smaller plates
    MIN_ASPECT_RATIO = 1.2  # Reduced to catch more square-ish plates
    MAX_ASPECT_RATIO = 8.0  # Increased to catch wider plates
    
    for contour in contours:
        # Get the perimeter and approximate the contour as a polygon
        perimeter = cv2.arcLength(contour, True)
        approx = cv2.approxPolyDP(contour, 0.04 * perimeter, True)
        
        # Check if it's a quadrilateral (4 sides) - typical for license plates
        if len(approx) >= 4 and len(approx) <= 6:  # Allow 4-6 points for imperfect rectangles
            x, y, w, h = cv2.boundingRect(contour)
            aspect_ratio = float(w) / h
            
            # Calculate how rectangular the contour is
            rect_area = w * h
            contour_area = cv2.contourArea(contour)
            rect_similarity = contour_area / rect_area if rect_area > 0 else 0
            
            # License plates are typically rectangular with specific aspect ratios
            if (MIN_ASPECT_RATIO <= aspect_ratio <= MAX_ASPECT_RATIO and 
                    contour_area >= MIN_PLATE_AREA and rect_similarity > 0.7):
                
                # Extract the plate region
                plate_img = img[y:y+h, x:x+w]
                plates.append(plate_img)
                boxes.append((x, y, w, h))
    
    # For demonstration, draw bounding boxes on the image
    result_img = img.copy()
    for x, y, w, h in boxes:
        cv2.rectangle(result_img, (x, y), (x+w, y+h), (0, 255, 0), 2)
    
    # Save the result image
    result_path = 'detected_plate.jpg'
    cv2.imwrite(result_path, result_img)
    
    # Save the cropped plate if found
    plate_path = None
    if plates:
        plate_path = 'cropped_plate.jpg'
        cv2.imwrite(plate_path, plates[0])
    
    processing_time = (time.time() - start_time) * 1000
    
    result = {
        "success": len(plates) > 0,
        "num_plates_detected": len(plates),
        "processing_time_ms": processing_time,
        "result_image_path": result_path,
        "plate_image_path": plate_path,
    }
    
    # Perform OCR if a plate was detected
    if result["success"] and TESSERACT_AVAILABLE:
        try:
            # Get the first plate
            plate_img = plates[0]
            
            # Convert to grayscale if not already
            if len(plate_img.shape) > 2:
                plate_gray = cv2.cvtColor(plate_img, cv2.COLOR_BGR2GRAY)
            else:
                plate_gray = plate_img
            
            # Resize image to enhance OCR (scaling up can help with small text)
            scale_factor = 2
            plate_gray = cv2.resize(plate_gray, None, fx=scale_factor, fy=scale_factor, interpolation=cv2.INTER_CUBIC)
            
            # Apply histogram equalization to enhance contrast
            equalized = cv2.equalizeHist(plate_gray)
            
            # Apply bilateral filtering to remove noise while preserving edges
            filtered = cv2.bilateralFilter(equalized, 11, 17, 17)
            
            # Apply adaptive thresholding to improve text recognition
            binary = cv2.adaptiveThreshold(
                filtered, 
                255, 
                cv2.ADAPTIVE_THRESH_GAUSSIAN_C, 
                cv2.THRESH_BINARY_INV, 
                11, 
                2
            )
            
            # Morphological operations to remove noise and connect broken characters
            kernel = np.ones((2, 2), np.uint8)
            binary = cv2.morphologyEx(binary, cv2.MORPH_CLOSE, kernel)
            
            # Save the preprocessed image
            preproc_path = 'preprocessed_plate.jpg'
            cv2.imwrite(preproc_path, binary)
            
            # Try multiple configurations to find the best result
            configs = [
                # Single line config 
                '--oem 1 --psm 7 -c tessedit_char_whitelist=ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -c tessedit_do_invert=0',
                # Single word config
                '--oem 1 --psm 8 -c tessedit_char_whitelist=ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -c tessedit_do_invert=0',
                # Sparse text config
                '--oem 1 --psm 11 -c tessedit_char_whitelist=ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -c tessedit_do_invert=0',
                # Legacy engine without LSTM
                '--oem 0 --psm 7 -c tessedit_char_whitelist=ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -c tessedit_do_invert=0',
            ]
            
            # Try all configs and keep the best result
            best_text = ""
            best_conf = 0
            best_config = ""
            
            for config in configs:
                try:
                    # Try this configuration
                    temp_text = pytesseract.image_to_string(binary, config=config).strip()
                    
                    # Get confidence for this config
                    ocr_data = pytesseract.image_to_data(
                        binary, 
                        config=config, 
                        output_type=pytesseract.Output.DICT
                    )
                    
                    confidences = [float(conf) for i, conf in enumerate(ocr_data['conf']) 
                                  if ocr_data['text'][i].strip()]
                    avg_conf = sum(confidences) / len(confidences) if confidences else 0
                    
                    print(f"Config: {config}")
                    print(f"  Text: {temp_text}")
                    print(f"  Confidence: {avg_conf:.2f}%")
                    
                    # Keep if better
                    if avg_conf > best_conf and temp_text.strip():
                        best_text = temp_text
                        best_conf = avg_conf
                        best_config = config
                        
                except Exception as e:
                    print(f"  Error with config: {str(e)}")
                    
            # Use the best detected text
            text = best_text
            config = best_config  # Keep the best config for later confidence calculation
            
            print(f"Best config: {best_config}")
            print(f"Best text: {text}")
            print(f"Best confidence: {best_conf:.2f}%")
            
            # Post-process the text to better match Nepali license plate format
            # Generally in format: "BA 1 PA 1234" (province, vehicle class, serial letters, number)
            text = ' '.join(text.split())
            text = post_process_nepali_plate(text)
            
            # Get confidence values if available
            try:
                ocr_data = pytesseract.image_to_data(
                    binary, 
                    config=config, 
                    output_type=pytesseract.Output.DICT
                )
                
                # Calculate average confidence for non-empty text
                confidences = [float(conf) for i, conf in enumerate(ocr_data['conf']) 
                             if ocr_data['text'][i].strip()]
                avg_confidence = sum(confidences) / len(confidences) if confidences else 0
            except Exception as e:
                print(f"Warning: Could not get confidence values: {str(e)}")
                avg_confidence = 0
            
            result["ocr_text"] = text
            result["ocr_confidence"] = avg_confidence
            result["preprocessed_image"] = preproc_path
            
            print(f"OCR Text: {text}")
            print(f"OCR Confidence: {avg_confidence:.2f}%")
        except Exception as e:
            print(f"OCR Error: {str(e)}")
            result["ocr_error"] = str(e)
    
    return result

def main():
    if len(sys.argv) != 2:
        print("Usage: python simple_ocr_test.py <image_path>")
        return
    
    image_path = sys.argv[1]
    result = detect_license_plate(image_path)
    
    if result["success"]:
        print(f"Detection successful! Found {result['num_plates_detected']} potential license plates.")
        print(f"Processing time: {result['processing_time_ms']:.2f} ms")
        print(f"Result image saved to: {result['result_image_path']}")
        
        if result["plate_image_path"]:
            print(f"Cropped plate saved to: {result['plate_image_path']}")
    else:
        print("Detection failed.")
        if "error" in result:
            print(f"Error: {result['error']}")

if __name__ == "__main__":
    main()