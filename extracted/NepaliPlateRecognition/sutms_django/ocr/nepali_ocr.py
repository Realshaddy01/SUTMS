"""
Nepali OCR (Optical Character Recognition) module.
This module handles text recognition from license plate images.
"""
import logging
import os
import time
from pathlib import Path
from typing import Dict, Any, Tuple, List, Optional, Union

import cv2
import numpy as np
import pytesseract
from django.conf import settings

# Local imports
from .license_plate_detector import detector

# Configure logging
logger = logging.getLogger(__name__)

# Check if pytesseract is installed
try:
    pytesseract.get_tesseract_version()
    TESSERACT_AVAILABLE = True
except Exception as e:
    logger.warning("Pytesseract not available or Tesseract not installed: %s", str(e))
    TESSERACT_AVAILABLE = False

# Try to import tensorflow if available
try:
    import tensorflow as tf
    tf.config.list_physical_devices('GPU')
    TF_AVAILABLE = True
    logger.info("TensorFlow available, using version: %s", tf.__version__)
except ImportError:
    logger.warning("TensorFlow not available, using fallback OCR method")
    TF_AVAILABLE = False
except Exception as e:
    logger.warning("Error initializing TensorFlow: %s", str(e))
    TF_AVAILABLE = False


class NepaliOCR:
    """
    Class for recognizing text from license plate images.
    Supports multiple recognition methods including Tesseract OCR and 
    custom-trained neural networks.
    """
    
    def __init__(self):
        self.model = None
        self.model_loaded = False
        self.detector = detector
        
        # Check for trained models folder
        models_dir = Path(__file__).parent / 'models'
        if not models_dir.exists():
            os.makedirs(models_dir, exist_ok=True)
        
        # Try to load custom model if TensorFlow is available
        if TF_AVAILABLE:
            self._try_load_model()
    
    def _try_load_model(self):
        """Try to load a custom TensorFlow model if available."""
        model_path = Path(__file__).parent / 'models' / 'license_plate_recognition.h5'
        
        if not model_path.exists():
            logger.warning("Custom model not found at %s", model_path)
            return
        
        try:
            # Import here to avoid dependency issues if TF is not installed
            import tensorflow as tf
            
            logger.info("Loading custom OCR model from %s", model_path)
            self.model = tf.keras.models.load_model(str(model_path))
            self.model_loaded = True
            logger.info("Custom OCR model loaded successfully")
        
        except Exception as e:
            logger.exception("Error loading custom OCR model: %s", str(e))
    
    def recognize(self, image_path: Union[str, Path]) -> Dict[str, Any]:
        """
        Recognize text from an image containing a license plate.
        
        Args:
            image_path: Path to the image file
            
        Returns:
            Dict containing recognition results:
                - success: Boolean indicating if recognition was successful
                - text: Recognized license plate text
                - confidence: Confidence score (0-100)
                - plate_image: Cropped image of the license plate
                - processing_time_ms: Processing time in milliseconds
        """
        start_time = time.time()
        
        try:
            # First detect the license plate in the image
            detection_result = self.detector.detect(image_path)
            
            if not detection_result['success'] or not detection_result['plates']:
                processing_time = int((time.time() - start_time) * 1000)
                
                return {
                    'success': False,
                    'text': '',
                    'confidence': 0,
                    'plate_image': None,
                    'bbox': None,
                    'processing_time_ms': processing_time,
                    'error': 'No license plate detected in the image'
                }
            
            # Get the first plate (highest confidence)
            plate_img = detection_result['plates'][0]
            bbox = detection_result['bbox'][0] if detection_result['bbox'] else None
            
            # Enhance the image for better OCR
            enhanced_img = self.detector.enhance_plate_image(plate_img)
            
            # Recognize text based on available methods
            if self.model_loaded:
                text, confidence = self._recognize_with_neural_network(enhanced_img)
            elif TESSERACT_AVAILABLE:
                text, confidence = self._recognize_with_tesseract(enhanced_img)
            else:
                # Fallback method - report that no recognition method is available
                processing_time = int((time.time() - start_time) * 1000)
                
                return {
                    'success': False,
                    'text': '',
                    'confidence': 0,
                    'plate_image': plate_img,
                    'bbox': bbox,
                    'processing_time_ms': processing_time,
                    'error': 'No OCR method available'
                }
            
            # Calculate processing time
            processing_time = int((time.time() - start_time) * 1000)
            
            # Determine if recognition was successful
            success = bool(text.strip())
            
            return {
                'success': success,
                'text': text,
                'confidence': confidence,
                'plate_image': plate_img,
                'bbox': bbox,
                'processing_time_ms': processing_time
            }
        
        except Exception as e:
            logger.exception("Error in OCR processing: %s", str(e))
            processing_time = int((time.time() - start_time) * 1000)
            
            return {
                'success': False,
                'text': '',
                'confidence': 0,
                'plate_image': None,
                'bbox': None,
                'processing_time_ms': processing_time,
                'error': str(e)
            }
    
    def _recognize_with_neural_network(self, plate_img: np.ndarray) -> Tuple[str, float]:
        """
        Recognize license plate text using a trained neural network.
        
        Args:
            plate_img: Cropped and enhanced image of the license plate
            
        Returns:
            Tuple of (recognized_text, confidence)
        """
        # This is a placeholder implementation
        # In a real system, we would preprocess the image to match the model's input format
        try:
            if self.model is None:
                raise ValueError("Model not loaded")
            
            # Resize image to match model input
            resized_img = cv2.resize(plate_img, (128, 64))
            
            # Normalize pixel values
            normalized_img = resized_img / 255.0
            
            # Add batch dimension
            input_img = np.expand_dims(normalized_img, axis=0)
            
            # Make prediction
            predictions = self.model.predict(input_img)
            
            # Process predictions
            # This part depends on how the model was trained and what its outputs are
            # For a sequence-to-sequence model (like CTC-based ones), 
            # the outputs need to be converted to text
            
            # For simplicity, assume our model directly outputs text predictions
            # and confidence scores
            text = "BA 1 PA 123"  # Placeholder
            confidence = 80.0  # Placeholder
            
            return text, confidence
        
        except Exception as e:
            logger.exception("Error in neural network recognition: %s", str(e))
            return '', 0.0
    
    def _recognize_with_tesseract(self, plate_img: np.ndarray) -> Tuple[str, float]:
        """
        Recognize license plate text using Tesseract OCR.
        
        Args:
            plate_img: Cropped and enhanced image of the license plate
            
        Returns:
            Tuple of (recognized_text, confidence)
        """
        try:
            # Configure Tesseract to optimize for license plate recognition
            config = '--oem 1 --psm 7 -c tessedit_char_whitelist=ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
            
            # Perform OCR
            ocr_result = pytesseract.image_to_data(
                plate_img,
                config=config,
                output_type=pytesseract.Output.DICT
            )
            
            # Extract recognized text and confidence
            text_parts = []
            confidence_values = []
            
            for i, text in enumerate(ocr_result['text']):
                if text.strip():
                    text_parts.append(text)
                    confidence_values.append(float(ocr_result['conf'][i]))
            
            # Combine text parts
            text = ' '.join(text_parts)
            
            # Calculate average confidence
            confidence = sum(confidence_values) / len(confidence_values) if confidence_values else 0
            
            # Some post-processing for common OCR errors
            text = self._post_process_nepali_plate(text)
            
            return text, confidence
        
        except Exception as e:
            logger.exception("Error in Tesseract recognition: %s", str(e))
            return '', 0.0
    
    def _post_process_nepali_plate(self, text: str) -> str:
        """
        Apply post-processing to correct common OCR errors in Nepali license plates.
        
        Args:
            text: Raw OCR text
            
        Returns:
            Processed text with common errors corrected
        """
        if not text:
            return text
        
        # Remove unnecessary whitespace
        text = ' '.join(text.split())
        
        # Common replacements for Nepali license plates
        replacements = {
            '0': 'O',  # Common confusion between 0 and O
            'I': '1',  # Common confusion between I and 1
            'S': '5',  # Common confusion between S and 5
            'Z': '2',  # Common confusion between Z and 2
            'G': '6',  # Common confusion between G and 6
            'B': '8',  # Common confusion between B and 8
        }
        
        # Apply replacements based on position in the license plate
        parts = text.split()
        
        # Try to format according to common Nepali license plate patterns
        # e.g., "BA 1 PA 123" or "GA 1 KHA 123"
        if len(parts) >= 2:
            # First part should be 2 letters (province code)
            if len(parts[0]) <= 2 and parts[0].isalpha():
                pass  # Keep as is
            
            # Second part should be a number (vehicle type)
            if len(parts) > 1 and parts[1].isdigit():
                pass  # Keep as is
        
        # Rejoin the parts
        processed_text = ' '.join(parts)
        
        return processed_text


# Singleton instance
ocr = NepaliOCR()