"""
License plate detector module.
This module handles the detection of license plates in images.
"""
import logging
import os
import time
from pathlib import Path
from typing import Dict, Tuple, Optional, Any, Union

import cv2
import numpy as np
from django.conf import settings

# Configure logging
logger = logging.getLogger(__name__)

# Constants for detection
MIN_PLATE_AREA = 2000  # Minimum area of license plate
MIN_ASPECT_RATIO = 1.5  # Minimum aspect ratio of license plate (width/height)
MAX_ASPECT_RATIO = 6.0  # Maximum aspect ratio of license plate (width/height)


class LicensePlateDetector:
    """
    Class for detecting license plates in images.
    Uses a combination of image processing techniques to locate license plates.
    """
    
    def __init__(self):
        # Load haar cascade classifier if available
        cascade_path = Path(__file__).parent / 'models' / 'haarcascade_license_plate.xml'
        self.use_cascade = False
        
        if cascade_path.exists():
            self.plate_cascade = cv2.CascadeClassifier(str(cascade_path))
            self.use_cascade = True
            logger.info("Loaded license plate cascade classifier")
        else:
            logger.warning(
                "Haar cascade classifier not found at %s. Using fallback detection method.",
                cascade_path
            )
    
    def detect(self, image_path: Union[str, Path]) -> Dict[str, Any]:
        """
        Detect license plates in the given image.
        
        Args:
            image_path: Path to the image file
            
        Returns:
            Dict containing detection results:
                - success: Boolean indicating if detection was successful
                - plates: List of detected plate regions (cropped images)
                - bbox: List of bounding boxes for detected plates
                - processing_time_ms: Processing time in milliseconds
        """
        start_time = time.time()
        
        try:
            # Load image
            img = cv2.imread(str(image_path))
            if img is None:
                logger.error("Failed to load image: %s", image_path)
                return {
                    'success': False,
                    'plates': [],
                    'bbox': [],
                    'processing_time_ms': 0,
                    'error': 'Failed to load image'
                }
            
            # Try multiple detection methods
            if self.use_cascade:
                plates, boxes = self._detect_with_cascade(img)
            
            # If no plates found or cascade not available, use contour-based method
            if not self.use_cascade or not plates:
                plates, boxes = self._detect_with_contours(img)
            
            processing_time = int((time.time() - start_time) * 1000)
            
            return {
                'success': len(plates) > 0,
                'plates': plates,
                'bbox': boxes,
                'processing_time_ms': processing_time
            }
        
        except Exception as e:
            logger.exception("Error in license plate detection: %s", str(e))
            processing_time = int((time.time() - start_time) * 1000)
            
            return {
                'success': False,
                'plates': [],
                'bbox': [],
                'processing_time_ms': processing_time,
                'error': str(e)
            }
    
    def _detect_with_cascade(self, img: np.ndarray) -> Tuple[list, list]:
        """Detect license plates using Haar cascade classifier."""
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        plates = []
        boxes = []
        
        # Detect plates with cascade
        plate_rects = self.plate_cascade.detectMultiScale(
            gray,
            scaleFactor=1.1,
            minNeighbors=5,
            minSize=(30, 10)
        )
        
        for (x, y, w, h) in plate_rects:
            # Extract the plate
            plate_img = img[y:y+h, x:x+w]
            plates.append(plate_img)
            boxes.append((x, y, w, h))
        
        return plates, boxes
    
    def _detect_with_contours(self, img: np.ndarray) -> Tuple[list, list]:
        """Detect license plates using contour-based approach."""
        # Convert to grayscale
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        
        # Apply Gaussian blur to reduce noise
        blur = cv2.GaussianBlur(gray, (5, 5), 0)
        
        # Apply Canny edge detection
        edges = cv2.Canny(blur, 50, 150)
        
        # Dilate the edges to connect broken contours
        kernel = np.ones((3, 3), np.uint8)
        dilated = cv2.dilate(edges, kernel, iterations=2)
        
        # Find contours in the image
        contours, _ = cv2.findContours(dilated, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        
        # Sort contours by area (largest first)
        contours = sorted(contours, key=cv2.contourArea, reverse=True)[:10]
        
        plates = []
        boxes = []
        
        # Check each contour
        for contour in contours:
            # Get the rectangle bounding the contour
            x, y, w, h = cv2.boundingRect(contour)
            
            # Calculate aspect ratio
            aspect_ratio = float(w) / h
            
            # Check if the contour could be a license plate
            if (MIN_ASPECT_RATIO <= aspect_ratio <= MAX_ASPECT_RATIO and 
                    cv2.contourArea(contour) >= MIN_PLATE_AREA):
                
                # Extract the plate
                plate_img = img[y:y+h, x:x+w]
                plates.append(plate_img)
                boxes.append((x, y, w, h))
        
        return plates, boxes
    
    def enhance_plate_image(self, plate_img: np.ndarray) -> np.ndarray:
        """
        Enhance the plate image for better OCR accuracy.
        
        Args:
            plate_img: The cropped plate image
            
        Returns:
            Enhanced plate image
        """
        try:
            # Convert to grayscale if not already
            if len(plate_img.shape) > 2 and plate_img.shape[2] == 3:
                gray = cv2.cvtColor(plate_img, cv2.COLOR_BGR2GRAY)
            else:
                gray = plate_img
            
            # Apply bilateral filter to remove noise while preserving edges
            filtered = cv2.bilateralFilter(gray, 11, 17, 17)
            
            # Apply adaptive thresholding to handle varying lighting conditions
            binary = cv2.adaptiveThreshold(
                filtered,
                255,
                cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
                cv2.THRESH_BINARY_INV,
                11,
                2
            )
            
            # Optional: Noise removal
            kernel = np.ones((1, 1), np.uint8)
            opening = cv2.morphologyEx(binary, cv2.MORPH_OPEN, kernel)
            
            return opening
        
        except Exception as e:
            logger.exception("Error enhancing plate image: %s", str(e))
            return plate_img  # Return original image if enhancement fails


# Singleton instance
detector = LicensePlateDetector()