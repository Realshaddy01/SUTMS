import cv2
import pytesseract
import numpy as np
from PIL import Image
import io
import re

def preprocess_image(image_data):
    # Convert bytes to numpy array
    nparr = np.frombuffer(image_data, np.uint8)
    # Decode image
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    
    # Convert to grayscale
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    
    # Apply bilateral filter to remove noise while keeping edges sharp
    gray = cv2.bilateralFilter(gray, 11, 17, 17)
    
    # Apply threshold to get black and white image
    _, thresh = cv2.threshold(gray, 150, 255, cv2.THRESH_BINARY)
    
    return thresh

def extract_license_plate(image_data):
    try:
        # Preprocess image
        processed_img = preprocess_image(image_data)
        
        # Use pytesseract to extract text
        text = pytesseract.image_to_string(processed_img, config='--psm 7')
        
        # Clean and format the extracted text
        text = text.strip().replace(' ', '').replace('\n', '')
        
        # Use regex to extract license plate format (adjust for your country's format)
        # This example looks for common license plate patterns
        license_pattern = re.compile(r'[A-Z]{2}[0-9]{2}[A-Z]{2}[0-9]{4}')  # Example: KA01AB1234
        match = license_pattern.search(text)
        
        if match:
            return match.group(0)
        
        return text
    except Exception as e:
        print(f"Error in OCR processing: {e}")
        return None

def scan_qr_code(image_data):
    try:
        from pyzbar.pyzbar import decode
        
        # Convert bytes to PIL Image
        image = Image.open(io.BytesIO(image_data))
        
        # Decode QR codes in the image
        decoded_objects = decode(image)
        
        if decoded_objects:
            # Return the data from the first QR code found
            return decoded_objects[0].data.decode('utf-8')
        
        return None
    except Exception as e:
        print(f"Error in QR code scanning: {e}")
        return None

