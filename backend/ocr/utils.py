import os
import time
import cv2
import numpy as np
import pytesseract
import logging
from PIL import Image
from django.conf import settings
from .models import LicensePlateDetection, OCRModel
from vehicles.models import Vehicle
from openai import OpenAI

logger = logging.getLogger('sutms.ocr')

# Configure pytesseract path if specified in settings
if hasattr(settings, 'PYTESSERACT_CMD'):
    pytesseract.pytesseract.tesseract_cmd = settings.PYTESSERACT_CMD


class LicensePlateDetector:
    """Class for detecting Nepali license plates in images"""
    
    def __init__(self, use_haar=True, use_contours=True):
        self.use_haar = use_haar
        self.use_contours = use_contours
        
        # Load Haar cascade classifier if available and requested
        self.cascade = None
        cascade_path = os.path.join(settings.BASE_DIR, 'ocr/data/haarcascade_nepali_license_plate.xml')
        if self.use_haar and os.path.exists(cascade_path):
            self.cascade = cv2.CascadeClassifier(cascade_path)
        
    def detect_plate(self, image_path):
        """
        Detect license plate in an image
        
        Args:
            image_path: Path to the image file
            
        Returns:
            Tuple of (plate_img, plate_text, confidence)
        """
        start_time = time.time()
        
        # Read and preprocess the image
        img = cv2.imread(str(image_path))
        if img is None:
            logger.error(f"Failed to load image: {image_path}")
            return None, "", 0
            
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        plate_img = None
        plate_text = ""
        confidence = 0
        
        # Try Haar cascade detection
        if self.use_haar and self.cascade:
            plate_img = self._detect_with_haar(gray, img)
            
        # If Haar detection failed, try contour detection
        if plate_img is None and self.use_contours:
            plate_img = self._detect_with_contours(gray, img)
            
        # If plate is detected, perform OCR
        if plate_img is not None:
            plate_text, confidence = self._perform_ocr(plate_img)
            
        processing_time = int((time.time() - start_time) * 1000)  # Convert to milliseconds
        logger.info(f"Plate detection completed in {processing_time}ms: {plate_text} (confidence: {confidence:.2f})")
        
        return plate_img, plate_text, confidence, processing_time
    
    def _detect_with_haar(self, gray_img, original_img):
        """Detect license plate using Haar cascade classifier"""
        if self.cascade is None:
            return None
            
        plates = self.cascade.detectMultiScale(gray_img, scaleFactor=1.1, minNeighbors=5, minSize=(100, 30))
        
        if len(plates) == 0:
            return None
            
        # Get the largest plate region
        largest_area = 0
        largest_idx = 0
        
        for i, (x, y, w, h) in enumerate(plates):
            area = w * h
            if area > largest_area:
                largest_area = area
                largest_idx = i
                
        x, y, w, h = plates[largest_idx]
        plate_img = original_img[y:y+h, x:x+w]
        return plate_img
    
    def _detect_with_contours(self, gray_img, original_img):
        """Detect license plate using contour detection"""
        # Apply bilateral filter to reduce noise and preserve edges
        bilateral = cv2.bilateralFilter(gray_img, 11, 17, 17)
        
        # Apply edge detection
        edged = cv2.Canny(bilateral, 30, 200)
        
        # Find contours
        contours, _ = cv2.findContours(edged.copy(), cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)
        contours = sorted(contours, key=cv2.contourArea, reverse=True)[:10]
        
        for contour in contours:
            # Approximate the contour
            peri = cv2.arcLength(contour, True)
            approx = cv2.approxPolyDP(contour, 0.02 * peri, True)
            
            # If the contour has 4 points, it's likely a license plate
            if len(approx) == 4:
                x, y, w, h = cv2.boundingRect(contour)
                aspect_ratio = float(w) / h
                
                # Check aspect ratio (Nepali plates typically have aspect ratio around 2.5-4)
                if 2 <= aspect_ratio <= 6:
                    plate_img = original_img[y:y+h, x:x+w]
                    return plate_img
        
        return None
    
    def _perform_ocr(self, plate_img):
        """Perform OCR on the license plate image"""
        # Preprocess the plate image for better OCR
        gray = cv2.cvtColor(plate_img, cv2.COLOR_BGR2GRAY)
        gray = cv2.resize(gray, None, fx=2, fy=2, interpolation=cv2.INTER_CUBIC)
        
        # Apply thresholding to make text clearer
        _, thresh = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        
        # Use pytesseract to extract text
        config = '--oem 3 --psm 6 -l eng+nep'
        ocr_result = pytesseract.image_to_data(thresh, config=config, output_type=pytesseract.Output.DICT)
        
        # Extract text and confidence
        text_parts = []
        total_confidence = 0
        count = 0
        
        for i in range(len(ocr_result['text'])):
            if float(ocr_result['conf'][i]) > 0:  # Filter out low confidence results
                text_parts.append(ocr_result['text'][i])
                total_confidence += float(ocr_result['conf'][i])
                count += 1
                
        plate_text = ' '.join(text_parts).strip()
        avg_confidence = total_confidence / count if count > 0 else 0
        
        # Clean up the text
        plate_text = self._clean_plate_text(plate_text)
        
        return plate_text, avg_confidence / 100.0  # Normalize confidence to 0-1
    
    def _clean_plate_text(self, text):
        """Clean up the detected text"""
        # Remove non-alphanumeric characters except dash
        import re
        text = re.sub(r'[^a-zA-Z0-9\-]', '', text)
        
        # Convert to uppercase
        text = text.upper()
        
        return text


def detect_license_plate(image_path, user=None, save_detection=True, location_data=None):
    """
    Detect license plate in an image and save the detection if requested
    
    Args:
        image_path: Path to the image file
        user: User who performed the detection
        save_detection: Whether to save the detection to database
        location_data: Dictionary with 'latitude', 'longitude', and 'location_name' (optional)
        
    Returns:
        Tuple of (license_plate_text, confidence, vehicle_object)
    """
    detector = LicensePlateDetector()
    plate_img, plate_text, confidence, processing_time = detector.detect_plate(image_path)
    
    vehicle = None
    if plate_text:
        # Try to find the vehicle with this license plate
        try:
            vehicle = Vehicle.objects.get(license_plate__iexact=plate_text)
        except Vehicle.DoesNotExist:
            vehicle = None
    
    # Save the detection to database if requested
    if save_detection and user:
        detection = LicensePlateDetection(
            user=user,
            original_image=image_path,
            detected_text=plate_text,
            confidence_score=confidence,
            matched_vehicle=vehicle,
            processing_time_ms=processing_time,
            detection_method='hybrid'
        )
        
        # Save the cropped plate image if available
        if plate_img is not None:
            # Get the original image filename and create a new filename for the crop
            original_filename = os.path.basename(image_path)
            base_name, ext = os.path.splitext(original_filename)
            crop_filename = f"{base_name}_plate{ext}"
            
            # Create a temporary file path for the cropped image
            crop_path = os.path.join(settings.MEDIA_ROOT, 'temp', crop_filename)
            os.makedirs(os.path.dirname(crop_path), exist_ok=True)
            
            # Save the cropped image
            cv2.imwrite(crop_path, plate_img)
            
            # Open the saved image with PIL and save it to the detection model
            with open(crop_path, 'rb') as f:
                from django.core.files.images import ImageFile
                detection.detected_plate_image.save(crop_filename, ImageFile(f))
                
            # Remove the temporary file
            os.remove(crop_path)
            
        # Add location data if provided
        if location_data:
            detection.latitude = location_data.get('latitude')
            detection.longitude = location_data.get('longitude')
            detection.location_name = location_data.get('location_name')
            
        detection.save()
    
    return plate_text, confidence, vehicle


def enhance_license_plate_detection(image_path):
    client = OpenAI(api_key=os.environ.get('OPENAI_API_KEY'))
    # Process image and improve OCR accuracy
    # Return enhanced results