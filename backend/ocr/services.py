import os
import cv2
import numpy as np
import time
import tensorflow as tf
import easyocr
from django.conf import settings
from pathlib import Path
import requests
import json
import logging

logger = logging.getLogger(__name__)

class LicensePlateOCR:
    """License plate detection and OCR service."""
    
    def __init__(self):
        # Initialize EasyOCR reader for Nepali language
        self.reader = easyocr.Reader(['ne', 'en'], gpu=False)
        
        # Load TensorFlow model
        try:
            model_path = os.path.join(settings.BASE_DIR, 'models', 'nepali_license_plate_model.h5')
            if os.path.exists(model_path):
                self.local_model = tf.keras.models.load_model(model_path)
                self.character_mapping = self._load_character_mapping()
                logger.info("Local TensorFlow model loaded successfully")
            else:
                self.local_model = None
                logger.warning(f"Model file not found at {model_path}")
        except Exception as e:
            self.local_model = None
            logger.error(f"Failed to load TensorFlow model: {str(e)}")
    
    def _load_character_mapping(self):
        """Load character mapping for model predictions."""
        # Replace with your actual character set
        nepali_chars = ['०', '१', '२', '३', '४', '५', '६', '७', '८', '९', 
                       'क', 'ख', 'ग', 'घ', 'ङ', 'च', 'छ', 'ज', 'झ', 'ञ', 'ट', 
                       'ठ', 'ड', 'ढ', 'ण', 'त', 'थ', 'द', 'ध', 'न', 'प', 'फ', 'ब', 'भ']
        return dict(enumerate(nepali_chars))
    
    def preprocess_image(self, img):
        """Preprocess image for better OCR results."""
        # Convert to grayscale
        if len(img.shape) == 3:
            gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        else:
            gray = img
            
        # Apply adaptive histogram equalization
        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8,8))
        equalized = clahe.apply(gray)
        
        # Apply thresholding
        _, thresh = cv2.threshold(equalized, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        
        # Noise removal (optional)
        kernel = np.ones((1, 1), np.uint8)
        opening = cv2.morphologyEx(thresh, cv2.MORPH_OPEN, kernel, iterations=1)
        
        return opening
    
    def detect_license_plate(self, img):
        """Detect license plate in the image."""
        # Convert to grayscale
        if len(img.shape) == 3:
            gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        else:
            gray = img
            
        # Apply GaussianBlur to reduce noise
        blur = cv2.GaussianBlur(gray, (5, 5), 0)
        
        # Perform Canny edge detection
        edges = cv2.Canny(blur, 50, 150)
        
        # Find contours
        contours, _ = cv2.findContours(edges.copy(), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        
        # Sort contours by area, largest first
        contours = sorted(contours, key=cv2.contourArea, reverse=True)[:10]
        
        license_plate_contour = None
        
        # Iterate through contours to find rectangle-like shapes
        for contour in contours:
            perimeter = cv2.arcLength(contour, True)
            approx = cv2.approxPolyDP(contour, 0.02 * perimeter, True)
            
            # If the contour has 4 vertices, it's likely a rectangle
            if len(approx) == 4:
                license_plate_contour = approx
                x, y, w, h = cv2.boundingRect(contour)
                
                # Check aspect ratio
                aspect_ratio = w / float(h)
                if 2.0 < aspect_ratio < 6.0:  # Typical license plate aspect ratios
                    # Extract the license plate
                    plate = gray[y:y+h, x:x+w]
                    return plate, (x, y, w, h)
        
        # If no plate found, return the whole image
        return gray, None
    
    def segment_characters(self, plate_img):
        """Segment characters from license plate."""
        # Preprocess
        processed = self.preprocess_image(plate_img)
        
        # Find contours
        contours, _ = cv2.findContours(processed, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        
        # Filter and sort contours (left to right)
        char_contours = []
        for contour in contours:
            x, y, w, h = cv2.boundingRect(contour)
            if h > 10 and w > 5 and h/plate_img.shape[0] > 0.4:  # Filter out small contours
                char_contours.append((x, y, w, h))
        
        # Sort contours from left to right
        char_contours.sort(key=lambda x: x[0])
        
        # Extract character images
        char_images = []
        for x, y, w, h in char_contours:
            char_img = plate_img[y:y+h, x:x+w]
            # Resize to match model input
            resized = cv2.resize(char_img, (32, 32))
            char_images.append(resized)
            
        return char_images if char_images else None
    
    def process_with_local_model(self, char_images):
        """Process character images with local TensorFlow model."""
        if not self.local_model or not char_images:
            return None
            
        results = []
        for char_img in char_images:
            # Convert to RGB if grayscale
            if len(char_img.shape) == 2:
                char_img = cv2.cvtColor(char_img, cv2.COLOR_GRAY2RGB)
                
            # Prepare input for model
            img_array = np.expand_dims(char_img, axis=0)
            
            # Predict
            predictions = self.local_model.predict(img_array, verbose=0)
            class_idx = np.argmax(predictions, axis=1)[0]
            confidence = np.max(predictions)
            
            # Get character
            if class_idx in self.character_mapping:
                char = self.character_mapping[class_idx]
                results.append((char, confidence))
                
        # Combine characters
        if results:
            text = ''.join([char for char, _ in results])
            avg_confidence = sum([conf for _, conf in results]) / len(results)
            return text, avg_confidence
            
        return None
    
    def process_with_easyocr(self, img):
        """Process image with EasyOCR."""
        # Detect text using EasyOCR
        results = self.reader.readtext(img)
        
        if not results:
            return None
            
        # Combine all detected text
        text = ' '.join([result[1] for result in results])
        confidence = sum([result[2] for result in results]) / len(results)
        
        return text, confidence
    
    def process_with_ai_api(self, img_path, internet_available=True):
        """Process image with AI API (Claude or OpenAI) if internet is available."""
        if not internet_available:
            return None
            
        try:
            # Use Claude API for OCR
            if hasattr(settings, 'ANTHROPIC_API_KEY') and settings.ANTHROPIC_API_KEY:
                return self._process_with_claude(img_path)
            # Use OpenAI API for OCR
            elif hasattr(settings, 'OPENAI_API_KEY') and settings.OPENAI_API_KEY:
                return self._process_with_openai(img_path)
            else:
                logger.warning("No AI API keys configured")
                return None
        except Exception as e:
            logger.error(f"Error in AI API processing: {str(e)}")
            return None
    
    def _process_with_claude(self, img_path):
        """Process image with Claude API."""
        import base64
        from anthropic import Anthropic
        
        # Read image and encode as base64
        with open(img_path, "rb") as image_file:
            base64_image = base64.b64encode(image_file.read()).decode('utf-8')
            
        # Initialize Claude client
        client = Anthropic(api_key=settings.ANTHROPIC_API_KEY)
        
        # Create message
        message = client.messages.create(
            model="claude-3-opus-20240229",
            max_tokens=1000,
            messages=[
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": "This is an image of a Nepali license plate. Please extract the license plate number. Return ONLY the license plate text, nothing else."
                        },
                        {
                            "type": "image",
                            "source": {
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": base64_image
                            }
                        }
                    ]
                }
            ]
        )
        
        # Extract the text from the response
        license_plate_text = message.content[0].text.strip()
        
        return license_plate_text, 0.98  # Assuming high confidence
    
    def _process_with_openai(self, img_path):
        """Process image with OpenAI API."""
        import base64
        from openai import OpenAI
        
        # Read image and encode as base64
        with open(img_path, "rb") as image_file:
            base64_image = base64.b64encode(image_file.read()).decode('utf-8')
            
        # Initialize OpenAI client
        client = OpenAI(api_key=settings.OPENAI_API_KEY)
        
        # Create response
        response = client.chat.completions.create(
            model="gpt-4-vision-preview",
            messages=[
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": "This is an image of a Nepali license plate. Please extract the license plate number. Return ONLY the license plate text, nothing else."
                        },
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:image/jpeg;base64,{base64_image}"
                            }
                        }
                    ]
                }
            ],
            max_tokens=300
        )
        
        # Extract the text from the response
        license_plate_text = response.choices[0].message.content.strip()
        
        return license_plate_text, 0.95  # Assuming high confidence
    
    def extract_license_plate(self, img_path, internet_available=True):
        """Main method to extract license plate from image."""
        # Check if file exists
        if not os.path.exists(img_path):
            logger.error(f"Image file not found: {img_path}")
            return None, 0
        
        # Read image
        img = cv2.imread(img_path)
        if img is None:
            logger.error(f"Failed to read image: {img_path}")
            return None, 0
        
        # First try AI API if internet is available
        if internet_available:
            logger.info("Attempting license plate extraction with AI API")
            ai_result = self.process_with_ai_api(img_path, internet_available)
            if ai_result and self._validate_license_format(ai_result[0]):
                logger.info(f"AI API successfully extracted license plate: {ai_result[0]}")
                return ai_result
        
        # Detect license plate in image
        plate_img, bbox = self.detect_license_plate(img)
        if plate_img is None:
            logger.warning("Failed to detect license plate")
            return None, 0
        
        # Try EasyOCR on the full plate
        logger.info("Attempting license plate extraction with EasyOCR")
        easyocr_result = self.process_with_easyocr(plate_img)
        if easyocr_result and self._validate_license_format(easyocr_result[0]):
            logger.info(f"EasyOCR successfully extracted license plate: {easyocr_result[0]}")
            return easyocr_result
        
        # If EasyOCR fails, try segmenting characters and using local model
        if self.local_model:
            logger.info("Attempting license plate extraction with local model")
            char_images = self.segment_characters(plate_img)
            if char_images:
                model_result = self.process_with_local_model(char_images)
                if model_result and self._validate_license_format(model_result[0]):
                    logger.info(f"Local model successfully extracted license plate: {model_result[0]}")
                    return model_result
        
        # If all methods fail, return best guess from EasyOCR
        return easyocr_result or (None, 0)
    
    def _validate_license_format(self, text):
        """Validate if the text follows Nepali license plate format."""
        import re
        # Simplified pattern for Nepali license plates (customize as needed)
        # Format examples: बा २ च १२३४, ज ४ प ७८९०
        pattern = r'[^\W\d_]{1,2}\s*\d{1,2}\s*[^\W\d_]{1,3}\s*\d{1,4}'
        return bool(re.match(pattern, text, re.UNICODE)) 