"""
Optimized license plate OCR script for the SUTMS application.
Focused on high accuracy for Nepali license plates.
"""
import sys
import cv2
import numpy as np
import time
import os
import re

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
    """
    if not text:
        return text
    
    # Debugging
    print(f"Post-processing OCR text: '{text}'")
    
    # Remove any special characters, punctuation, or extra whitespace
    text = re.sub(r'[^\w\s]', '', text)
    text = re.sub(r'\s+', ' ', text).strip()
    
    # Sometimes OCR reads the text as one continuous string without spaces
    # Try to detect and split such cases
    if ' ' not in text and len(text) > 4:
        # For format like "BA1PA1234", split into components
        # First, try to identify the pattern
        letter_pattern = re.compile(r'[A-Z]+')
        digit_pattern = re.compile(r'\d+')
        
        letter_matches = letter_pattern.finditer(text)
        digit_matches = digit_pattern.finditer(text)
        
        parts = []
        for match in letter_matches:
            parts.append((match.start(), match.end(), match.group(), 'L'))
        
        for match in digit_matches:
            parts.append((match.start(), match.end(), match.group(), 'D'))
        
        # Sort parts by position
        parts.sort(key=lambda x: x[0])
        
        # Create new text with spaces
        if len(parts) >= 4:
            text = ' '.join(p[2] for p in parts[:4])
    
    # Common OCR errors in license plates (correcting letters to digits)
    digit_replacements = {
        'O': '0',  # Often 'O' is confused with '0'
        'I': '1',  # Often 'I' is confused with '1'
        'Z': '2',  # Often 'Z' is confused with '2'
        'A': '4',  # Sometimes 'A' is confused with '4'
        'S': '5',  # Sometimes 'S' is confused with '5'
        'G': '6',  # Sometimes 'G' is confused with '6'
        'T': '7',  # Sometimes 'T' is confused with '7'
        'B': '8',  # Sometimes 'B' is confused with '8'
    }
    
    # Common OCR errors (correcting digits to letters)
    letter_replacements = {
        '0': 'O',  # 0 might be confused with O
        '1': 'I',  # 1 might be confused with I
        '8': 'B',  # 8 might be confused with B
        '5': 'S',  # 5 might be confused with S
    }
    
    # Try to extract components using regex patterns for Nepali plates
    # Look for several possible patterns
    patterns = [
        # Standard 4-part pattern: XX ## XX ####
        r'([A-Z]{1,2})\s*(\d{1,2})\s*([A-Z]{1,3})\s*(\d{1,4})',
        
        # Merged first parts: XX## XX ####
        r'([A-Z]{1,2})(\d{1,2})\s*([A-Z]{1,3})\s*(\d{1,4})',
        
        # Merged middle parts: XX ##XX ####
        r'([A-Z]{1,2})\s*(\d{1,2})([A-Z]{1,3})\s*(\d{1,4})',
        
        # All merged: XX##XX####
        r'([A-Z]{1,2})(\d{1,2})([A-Z]{1,3})(\d{1,4})'
    ]
    
    for pattern in patterns:
        match = re.search(pattern, text)
        if match:
            province = match.group(1)
            vehicle_class = match.group(2)
            letters = match.group(3)
            numbers = match.group(4)
            
            # Fix common OCR errors in each component
            # Province code (should be letters)
            province = ''.join(letter_replacements.get(c, c) for c in province if c.isalnum())
            
            # Vehicle class (should be digits)
            vehicle_class = ''.join(digit_replacements.get(c, c) for c in vehicle_class if c.isalnum())
            
            # Letters (should be letters)
            letters = ''.join(letter_replacements.get(c, c) for c in letters if c.isalnum())
            
            # Numbers (should be digits)
            numbers = ''.join(digit_replacements.get(c, c) for c in numbers if c.isalnum())
            
            # Format the result correctly
            result = f"{province} {vehicle_class} {letters} {numbers}"
            print(f"Matched pattern: {pattern}, Result: {result}")
            return result
    
    # If regex patterns don't match, try a different approach
    # Split the text into parts and analyze each part separately
    parts = text.split()
    
    # If we have fewer than 4 parts, but a part has mixed characters,
    # try to split it into separate components
    if len(parts) < 4:
        new_parts = []
        for part in parts:
            if len(part) > 2:
                # Try to identify transitions between letters and digits
                prev_is_digit = part[0].isdigit()
                split_indices = []
                
                for i in range(1, len(part)):
                    curr_is_digit = part[i].isdigit()
                    if curr_is_digit != prev_is_digit:
                        split_indices.append(i)
                    prev_is_digit = curr_is_digit
                
                # Split the part at the transition points
                if split_indices:
                    start = 0
                    for idx in split_indices:
                        new_parts.append(part[start:idx])
                        start = idx
                    new_parts.append(part[start:])
                else:
                    new_parts.append(part)
            else:
                new_parts.append(part)
        
        parts = new_parts
    
    # Process each part based on expected position
    result = []
    
    # Most Nepali license plates have 4 parts
    if len(parts) >= 1:
        # First part should be province code (BA, GN, LU, etc)
        p1 = parts[0]
        # Apply corrections for the first part (should be letters)
        p1 = ''.join(letter_replacements.get(c, c) for c in p1 if c.isalnum())
        # Keep only letters for the province code
        p1 = ''.join(c for c in p1 if c.isalpha())
        if len(p1) > 2:
            p1 = p1[:2]  # Limit to 2 letters max
        result.append(p1)
    
    if len(parts) >= 2:
        # Second part should be a number (1-99)
        p2 = parts[1]
        # Apply corrections for the second part (should be digits)
        p2 = ''.join(digit_replacements.get(c, c) for c in p2 if c.isalnum())
        # Keep only digits
        p2 = ''.join(c for c in p2 if c.isdigit())
        if not p2:
            p2 = '1'  # Default if we can't extract a number
        result.append(p2)
    
    if len(parts) >= 3:
        # Third part should be letters (PA, KHA, etc)
        p3 = parts[2]
        # Apply corrections for the third part (should be letters)
        p3 = ''.join(letter_replacements.get(c, c) for c in p3 if c.isalnum())
        # Keep only letters
        p3 = ''.join(c for c in p3 if c.isalpha())
        if len(p3) > 3:  # Nepali can have up to 3 characters here (KHA, GHA, etc)
            p3 = p3[:3]
        result.append(p3)
    
    if len(parts) >= 4:
        # Fourth part should be a 4-digit number
        p4 = parts[3]
        # Apply corrections for the fourth part (should be digits)
        p4 = ''.join(digit_replacements.get(c, c) for c in p4 if c.isalnum())
        # Keep only digits
        p4 = ''.join(c for c in p4 if c.isdigit())
        # Padding to ensure 4 digits
        while len(p4) < 4:
            p4 += '0'
        if len(p4) > 4:
            p4 = p4[:4]  # Limit to 4 digits
        result.append(p4)
    
    # If we couldn't process all 4 parts but have a long string, try to extract components
    if len(result) < 4 and len(text) > 6:
        # Extract likely province code (1-2 letters at start)
        province_match = re.search(r'^([A-Z]{1,2})', text)
        if province_match and not any(p == province_match.group(1) for p in result):
            result.insert(0, province_match.group(1))
        
        # Extract likely vehicle class (1-2 digits after province)
        class_match = re.search(r'[A-Z]{1,2}(\d{1,2})', text)
        if class_match and len(result) >= 1 and len(result) < 2:
            result.append(class_match.group(1))
            
        # Extract likely letters (1-3 letters after vehicle class)
        letters_match = re.search(r'\d{1,2}([A-Z]{1,3})', text)
        if letters_match and len(result) >= 2 and len(result) < 3:
            result.append(letters_match.group(1))
            
        # Extract likely number (4 digits at end)
        number_match = re.search(r'(\d{4})$', text)
        if number_match and len(result) >= 3 and len(result) < 4:
            result.append(number_match.group(1))
    
    # Join the parts with spaces
    final_result = ' '.join(result)
    print(f"Final processed result: {final_result}")
    return final_result

def improve_plate_visibility(img):
    """Apply preprocessing to make the license plate more visible."""
    # Check if we're dealing with a white plate (optimized) or a yellow plate (realistic)
    is_white_plate = True  # Default to white plate processing for now
    
    # Convert to grayscale
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    
    if is_white_plate:
        # For white plates (optimized for OCR), simple processing works better
        # Apply gaussian blur to reduce noise
        blurred = cv2.GaussianBlur(gray, (5, 5), 0)
        
        # Apply Otsu's thresholding
        _, thresh = cv2.threshold(blurred, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
        
        # Clean up with opening operation
        kernel = np.ones((2, 2), np.uint8)
        cleaned = cv2.morphologyEx(thresh, cv2.MORPH_OPEN, kernel)
        
        return cleaned
    else:
        # For yellow plates (realistic), use more complex processing
        # Apply bilateral filter to reduce noise while preserving edges
        filtered = cv2.bilateralFilter(gray, 11, 17, 17)
        
        # Apply adaptive thresholding to binarize the image
        thresh = cv2.adaptiveThreshold(
            filtered, 
            255, 
            cv2.ADAPTIVE_THRESH_GAUSSIAN_C, 
            cv2.THRESH_BINARY_INV, 
            11, 
            2
        )
        
        # Use morphological operations to clean up the image
        kernel = np.ones((2, 2), np.uint8)
        morph = cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, kernel)
        
        return morph
        
def self_detect_plate_type(img):
    """
    Automatically detect if we're dealing with an optimized white plate or realistic yellow plate.
    Returns True for white plate, False for yellow plate.
    """
    # Convert to HSV for better color detection
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    
    # Calculate average hue and saturation in the center region
    h, w = img.shape[:2]
    center_region = hsv[h//4:3*h//4, w//4:3*w//4]
    avg_hue = np.mean(center_region[:,:,0])
    avg_sat = np.mean(center_region[:,:,1])
    
    # Yellow plates have hue around 30 (in OpenCV HSV) and high saturation
    # White plates have low saturation
    if avg_sat < 50:  # Low saturation suggests white background
        return True
    elif 20 <= avg_hue <= 40 and avg_sat > 100:  # Yellow plate characteristics
        return False
    else:
        # Default to optimized processing for unknown plates
        return True

def ocr_license_plate(image_path, save_debug_images=True):
    """
    Perform OCR on a license plate image using optimized techniques.
    
    Args:
        image_path: Path to the license plate image
        save_debug_images: Whether to save intermediate images for debugging
        
    Returns:
        Dictionary with OCR results
    """
    start_time = time.time()
    print(f"Processing license plate: {image_path}")
    
    # Check if image exists
    if not os.path.exists(image_path):
        return {"success": False, "error": "Image file not found"}
    
    # Read the image
    img = cv2.imread(image_path)
    if img is None:
        return {"success": False, "error": "Failed to read image"}
    
    # Record original dimensions
    h, w = img.shape[:2]
    
    # Resize if the image is too small
    MIN_WIDTH = 300
    if w < MIN_WIDTH:
        scale_factor = MIN_WIDTH / w
        img = cv2.resize(img, None, fx=scale_factor, fy=scale_factor, interpolation=cv2.INTER_CUBIC)
    
    # Preprocess the image
    preprocessed = improve_plate_visibility(img)
    
    # Save preprocessed image if requested
    preproc_path = None
    if save_debug_images:
        preproc_path = 'preprocessed_plate.jpg'
        cv2.imwrite(preproc_path, preprocessed)
    
    # Initialize result
    result = {
        "success": TESSERACT_AVAILABLE,
        "processing_time_ms": 0,
        "preprocessed_image": preproc_path
    }
    
    # Perform OCR if Tesseract is available
    if not TESSERACT_AVAILABLE:
        result["error"] = "Tesseract OCR not available"
        return result
    
    try:
        # Try multiple Tesseract configurations and pick the best result
        configs = [
            '--oem 1 --psm 7 -c tessedit_char_whitelist=ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',  # For single line of text
            '--oem 1 --psm 8 -c tessedit_char_whitelist=ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',  # For single word
            '--oem 3 --psm 6 -c tessedit_char_whitelist=ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'   # For sparse text
        ]
        
        best_text = ""
        best_conf = 0
        best_config = configs[0]
        
        # Try each configuration and keep the one with highest confidence
        for config in configs:
            curr_text = pytesseract.image_to_string(preprocessed, config=config).strip()
            
            try:
                ocr_data = pytesseract.image_to_data(
                    preprocessed, 
                    config=config, 
                    output_type=pytesseract.Output.DICT
                )
                
                # Calculate average confidence for words
                confidences = [float(conf) for i, conf in enumerate(ocr_data['conf']) 
                             if ocr_data['text'][i].strip()]
                curr_conf = sum(confidences) / len(confidences) if confidences else 0
                
                # If this config gives better confidence, keep it
                if curr_conf > best_conf:
                    best_conf = curr_conf
                    best_text = curr_text
                    best_config = config
                    
            except Exception as e:
                print(f"Warning: Error with config {config}: {str(e)}")
                continue
        
        # Use the best configuration found
        text = best_text if best_text else pytesseract.image_to_string(preprocessed, config=best_config).strip()
        
        # Post-process to match Nepali plate format
        processed_text = post_process_nepali_plate(text)
        
        # Get confidence
        try:
            ocr_data = pytesseract.image_to_data(
                preprocessed, 
                config=best_config, 
                output_type=pytesseract.Output.DICT
            )
            
            # Calculate average confidence for words
            confidences = [float(conf) for i, conf in enumerate(ocr_data['conf']) 
                         if ocr_data['text'][i].strip()]
            avg_confidence = sum(confidences) / len(confidences) if confidences else 0
        except Exception as e:
            print(f"Warning: Could not calculate confidence: {str(e)}")
            avg_confidence = 0
        
        # Update result
        result["raw_text"] = text
        result["processed_text"] = processed_text
        result["confidence"] = avg_confidence
        
        # Print results
        print(f"Raw OCR text: {text}")
        print(f"Processed text: {processed_text}")
        print(f"Confidence: {avg_confidence:.2f}%")
        
    except Exception as e:
        print(f"OCR Error: {str(e)}")
        result["error"] = str(e)
        result["success"] = False
    
    # Calculate processing time
    result["processing_time_ms"] = (time.time() - start_time) * 1000
    print(f"Processing time: {result['processing_time_ms']:.2f} ms")
    
    return result

def main():
    if len(sys.argv) != 2:
        print("Usage: python optimized_ocr.py <license_plate_image>")
        return
    
    image_path = sys.argv[1]
    result = ocr_license_plate(image_path)
    
    if result["success"]:
        print(f"OCR completed successfully:")
        print(f"  Detected text: {result.get('processed_text', 'None')}")
        print(f"  Confidence: {result.get('confidence', 0):.2f}%")
    else:
        print(f"OCR failed: {result.get('error', 'Unknown error')}")

if __name__ == "__main__":
    main()