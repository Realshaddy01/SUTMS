"""
A simplified script to test license plate detection and OCR functionality directly.
"""
import sys
import cv2
import numpy as np
import time
import os
from pathlib import Path

# Import pytesseract for OCR
try:
    import pytesseract
    TESSERACT_AVAILABLE = True
except ImportError:
    print("Warning: pytesseract not installed. OCR functionality will be limited.")
    TESSERACT_AVAILABLE = False

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
    
    # Convert to grayscale
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    
    # Apply Gaussian blur
    blur = cv2.GaussianBlur(gray, (5, 5), 0)
    
    # Apply Canny edge detection
    edges = cv2.Canny(blur, 50, 150)
    
    # Dilate to connect edges
    kernel = np.ones((3, 3), np.uint8)
    dilated = cv2.dilate(edges, kernel, iterations=2)
    
    # Find contours
    contours, _ = cv2.findContours(dilated, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    
    # Sort by area
    contours = sorted(contours, key=cv2.contourArea, reverse=True)[:10]
    
    plates = []
    boxes = []
    
    # Check each contour for license plate characteristics
    MIN_PLATE_AREA = 2000
    MIN_ASPECT_RATIO = 1.5
    MAX_ASPECT_RATIO = 6.0
    
    for contour in contours:
        x, y, w, h = cv2.boundingRect(contour)
        aspect_ratio = float(w) / h
        
        if (MIN_ASPECT_RATIO <= aspect_ratio <= MAX_ASPECT_RATIO and 
                cv2.contourArea(contour) >= MIN_PLATE_AREA):
            
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
            
            # Apply adaptive thresholding to improve text recognition
            binary = cv2.adaptiveThreshold(
                plate_gray, 
                255, 
                cv2.ADAPTIVE_THRESH_GAUSSIAN_C, 
                cv2.THRESH_BINARY_INV, 
                11, 
                2
            )
            
            # Save the preprocessed image
            preproc_path = 'preprocessed_plate.jpg'
            cv2.imwrite(preproc_path, binary)
            
            # Perform OCR with Tesseract
            config = '--oem 1 --psm 7 -c tessedit_char_whitelist=ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
            text = pytesseract.image_to_string(binary, config=config).strip()
            
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