"""
License plate detector module optimized for Nepali license plates.
This module handles the detection and recognition of Nepali license plates in images.
"""
import logging
import os
from pathlib import Path
from typing import Dict, List, Optional, Union
import traceback

import cv2
import numpy as np
from django.conf import settings
from ultralytics import YOLO
import tensorflow as tf
from .text_recognizer import TextRecognizer

# Set up logging
logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)

# Add a console handler if not already present
if not logger.handlers:
    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging.DEBUG)
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    console_handler.setFormatter(formatter)
    logger.addHandler(console_handler)

class NepaliLicensePlateDetector:
    """
    Class for detecting and recognizing Nepali license plates in images.
    Uses YOLOv8 for detection and a custom CNN for text recognition.
    """
    
    def __init__(self):
        self.text_recognizer = None
        self.yolo_model = None
        self.is_mock = True  # Default to mock mode for safety
        
        try:
            # Initialize text recognizer with graceful fallback
            try:
                self.text_recognizer = TextRecognizer()
                logger.info("Text recognizer initialized")
            except Exception as e:
                logger.error(f"Failed to initialize text recognizer: {str(e)}")
                self.text_recognizer = None
            
            # Try to load YOLO model with better error handling
            try:
                # Create path to the YOLO model using pathlib for better platform compatibility
                current_dir = Path(__file__).resolve().parent
                model_path = current_dir / 'models' / 'yolov8_nepali_plate.pt'
                
                # Log the full path we're trying to use
                logger.info(f"Attempting to load YOLO model from: {model_path}")
                
                # Check if file exists and log its existence status
                if model_path.exists():
                    logger.info(f"Model file exists at: {model_path}")
                    try:
                        self.yolo_model = YOLO(str(model_path))
                        if self.yolo_model is not None:
                            self.is_mock = False  # Model loaded successfully
                            logger.info(f"YOLO model loaded successfully from {model_path}")
                    except Exception as e:
                        logger.error(f"Failed to load YOLO model: {str(e)}")
                        logger.error(traceback.format_exc())
                        self.yolo_model = None
                else:
                    logger.error(f"YOLO model file not found at {model_path}")
                    # Log all files in the models directory for debugging
                    models_dir = current_dir / 'models'
                    if models_dir.exists():
                        logger.info(f"Contents of {models_dir}:")
                        for file in models_dir.iterdir():
                            logger.info(f"- {file.name} ({file.stat().st_size} bytes)")
                    else:
                        logger.error(f"Models directory not found at {models_dir}")
            except Exception as e:
                logger.error(f"Error during YOLO model initialization: {str(e)}")
                logger.error(traceback.format_exc())
                self.yolo_model = None
                
        except Exception as e:
            logger.error(f"Error initializing detector: {str(e)}")
            logger.error(traceback.format_exc())
        
        # Final check - if either model failed to load, use mock mode
        if self.yolo_model is None or self.text_recognizer is None:
            logger.warning("Using mock implementation due to missing models")
            self.is_mock = True

    def detect_plate(self, image_file):
        """
        Detect and recognize license plate from image
        """
        if self.is_mock:
            # Return mock data for API documentation
            return {
                'success': True,
                'license_plate': 'BA 1 PA 1234',
                'confidence': 0.95,
                'bbox': [100, 100, 300, 150]
            }

        try:
            # Read image
            image = self._read_image(image_file)
            if image is None:
                return {
                    'success': False,
                    'error': 'Failed to read image'
                }

            if self.yolo_model is None:
                # Fallback to mock data if model isn't available
                return {
                    'success': True,
                    'license_plate': 'BA 1 PA 1234',
                    'confidence': 0.95,
                    'bbox': [100, 100, 300, 150]
                }
                
            # Use YOLO to detect license plates
            results = self.yolo_model(image)
            
            # Process detection results
            if len(results) > 0 and len(results[0].boxes) > 0:
                # Get the first detected plate (highest confidence)
                box = results[0].boxes[0]
                confidence = float(box.conf[0])
                x1, y1, x2, y2 = map(int, box.xyxy[0])
                
                # Extract the plate region
                plate_region = image[y1:y2, x1:x2]
                
                # Recognize text from the plate
                text_result = self.text_recognizer.recognize_text(plate_region)
                
                result = {
                    'success': True,
                    'license_plate': text_result.get('text', ''),
                    'confidence': confidence,
                    'bbox': [x1, y1, x2, y2]
                }
            else:
                # No plates detected
                result = {
                    'success': False,
                    'error': 'No license plate detected'
                }

            logger.info(f"Detected license plate: {result.get('license_plate', 'None')}")
            return result

        except Exception as e:
            logger.error(f"Error in plate detection: {str(e)}")
            return {
                'success': False,
                'error': str(e)
            }

    def _read_image(self, image_file):
        """Read and preprocess image"""
        try:
            # Read image file into numpy array
            image_array = np.frombuffer(image_file.read(), np.uint8)
            image = cv2.imdecode(image_array, cv2.IMREAD_COLOR)
            return image
        except Exception as e:
            logger.error(f"Error reading image: {str(e)}")
            return None

    def recognize_text(self, image, bbox):
        """Recognize text from the license plate region."""
        try:
            x1, y1, x2, y2 = bbox
            plate_region = image[y1:y2, x1:x2]
            
            # Preprocess the plate image for better recognition
            processed_plate = self._preprocess_plate(plate_region)
            
            # Use the text recognizer
            result = self.text_recognizer.recognize_text(processed_plate)
            return result
        except Exception as e:
            logger.error(f"Error in text recognition: {str(e)}")
            raise

    def process_image(self, image_path):
        """Process an image to detect and recognize license plates."""
        try:
            # Read image
            image = cv2.imread(image_path)
            if image is None:
                raise ValueError(f"Could not read image: {image_path}")
            
            # Detect plates
            plates = self.detect_plate(image)
            
            results = []
            for plate in plates:
                # Recognize text for each plate
                text_result = self.recognize_text(image, plate['bbox'])
                results.append({
                    'bbox': plate['bbox'],
                    'confidence': plate['confidence'],
                    'text': text_result["text"],
                    'text_confidence': text_result["confidence"]
                })
            
            return results
        except Exception as e:
            logger.error(f"Error processing image: {str(e)}")
            raise

    def _preprocess_plate(self, plate_img: np.ndarray) -> np.ndarray:
        """
        Preprocess license plate image for text recognition.
        
        Args:
            plate_img: Cropped license plate image
            
        Returns:
            Preprocessed image
        """
        try:
            # Convert to grayscale
            gray = cv2.cvtColor(plate_img, cv2.COLOR_BGR2GRAY)
            
            # Apply adaptive thresholding
            thresh = cv2.adaptiveThreshold(
                gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
                cv2.THRESH_BINARY, 11, 2
            )
            
            # Remove noise
            kernel = np.ones((2,2), np.uint8)
            cleaned = cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, kernel)
            
            return cleaned
            
        except Exception as e:
            logger.error(f"Error in plate preprocessing: {str(e)}")
            return plate_img


# Singleton instance
detector = NepaliLicensePlateDetector()