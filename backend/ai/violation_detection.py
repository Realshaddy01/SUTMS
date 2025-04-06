import os
import cv2
import numpy as np
import logging
import tensorflow as tf
from datetime import datetime

logger = logging.getLogger(__name__)

# Path to the violation detection model (simulated)
MODEL_PATH = os.path.join(os.path.dirname(__file__), 'models', 'violation_detection_model')

class ViolationDetector:
    def __init__(self):
        self.model = None
        try:
            logger.info("Initializing traffic violation detection model...")
            self._initialize_model()
        except Exception as e:
            logger.error(f"Failed to load violation detection model: {str(e)}")
    
    def _initialize_model(self):
        """Initialize the violation detection model."""
        try:
            # If the model exists, load it
            if os.path.exists(MODEL_PATH):
                self.model = tf.saved_model.load(MODEL_PATH)
                logger.info("Violation detection model loaded successfully")
            else:
                logger.warning("Violation detection model not found, using simulated detection")
        except Exception as e:
            logger.error(f"Error loading violation detection model: {str(e)}")
    
    def preprocess_frame(self, frame):
        """Preprocess video frame for violation detection."""
        try:
            # Resize the frame to the expected input size of the model
            resized_frame = cv2.resize(frame, (640, 480))
            
            # Convert to RGB (if model expects RGB)
            rgb_frame = cv2.cvtColor(resized_frame, cv2.COLOR_BGR2RGB)
            
            # Normalize pixel values to [0, 1]
            normalized_frame = rgb_frame / 255.0
            
            return normalized_frame
        except Exception as e:
            logger.error(f"Error preprocessing frame: {str(e)}")
            return None
    
    def detect_vehicles(self, frame):
        """Detect vehicles in the frame."""
        try:
            # Simulate vehicle detection
            # In a real implementation, this would use the model to detect vehicles
            
            # For simulation, we'll create random bounding boxes
            import random
            
            vehicles = []
            # Generate 1-5 random vehicle detections
            for _ in range(random.randint(1, 5)):
                x = random.randint(50, 550)
                y = random.randint(50, 350)
                w = random.randint(50, 150)
                h = random.randint(50, 100)
                
                confidence = random.uniform(0.7, 0.98)
                vehicle_type = random.choice(['car', 'motorcycle', 'truck', 'bus'])
                
                vehicles.append({
                    'bbox': (x, y, w, h),
                    'confidence': confidence,
                    'type': vehicle_type
                })
            
            return vehicles
        except Exception as e:
            logger.error(f"Error detecting vehicles: {str(e)}")
            return []
    
    def detect_violations(self, frame, vehicles):
        """Detect traffic violations based on vehicle positions and behavior."""
        try:
            # Simulate violation detection
            # In a real implementation, this would analyze vehicle positions, speeds, and behaviors
            
            import random
            
            violations = []
            for vehicle in vehicles:
                # Randomly decide if this vehicle is committing a violation
                if random.random() < 0.3:  # 30% chance of violation
                    violation_types = [
                        'speeding',
                        'red_light',
                        'wrong_way',
                        'illegal_turn',
                        'no_helmet',
                        'triple_riding',
                        'no_parking'
                    ]
                    
                    violation_type = random.choice(violation_types)
                    confidence = random.uniform(0.65, 0.95)
                    
                    violations.append({
                        'vehicle': vehicle,
                        'type': violation_type,
                        'confidence': confidence,
                        'timestamp': datetime.now()
                    })
            
            return violations
        except Exception as e:
            logger.error(f"Error detecting violations: {str(e)}")
            return []
    
    def process_video_frame(self, frame):
        """Process a video frame to detect violations."""
        try:
            # Preprocess the frame
            processed_frame = self.preprocess_frame(frame)
            if processed_frame is None:
                return None
            
            # Detect vehicles
            vehicles = self.detect_vehicles(processed_frame)
            
            # Detect violations
            violations = self.detect_violations(processed_frame, vehicles)
            
            # Create output with annotations
            output_frame = frame.copy()
            
            # Draw bounding boxes for vehicles
            for vehicle in vehicles:
                x, y, w, h = vehicle['bbox']
                cv2.rectangle(output_frame, (x, y), (x+w, y+h), (0, 255, 0), 2)
                cv2.putText(output_frame, f"{vehicle['type']} ({vehicle['confidence']:.2f})", 
                           (x, y-5), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 2)
            
            # Highlight violations
            for violation in violations:
                vehicle = violation['vehicle']
                x, y, w, h = vehicle['bbox']
                cv2.rectangle(output_frame, (x, y), (x+w, y+h), (0, 0, 255), 3)
                cv2.putText(output_frame, f"VIOLATION: {violation['type']}", 
                           (x, y-25), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)
                cv2.putText(output_frame, f"Conf: {violation['confidence']:.2f}", 
                           (x, y-5), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 0, 255), 2)
            
            return {
                'frame': output_frame,
                'vehicles': vehicles,
                'violations': violations
            }
        except Exception as e:
            logger.error(f"Error processing video frame: {str(e)}")
            return None
    
    def extract_violation_image(self, frame, violation):
        """Extract an image of the specific violation from the frame."""
        try:
            vehicle = violation['vehicle']
            x, y, w, h = vehicle['bbox']
            
            # Add some padding around the vehicle
            padding = 20
            x_start = max(0, x - padding)
            y_start = max(0, y - padding)
            x_end = min(frame.shape[1], x + w + padding)
            y_end = min(frame.shape[0], y + h + padding)
            
            # Extract the region
            violation_image = frame[y_start:y_end, x_start:x_end]
            
            return violation_image
        except Exception as e:
            logger.error(f"Error extracting violation image: {str(e)}")
            return None

# Initialize the detector
detector = ViolationDetector()

def detect_violations_in_frame(frame):
    """
    Public function to detect traffic violations in a video frame.
    
    Args:
        frame (numpy.ndarray): Video frame to process
        
    Returns:
        dict: Dictionary containing processed frame with annotations, detected vehicles, and violations
    """
    result = detector.process_video_frame(frame)
    return result

def extract_violation_evidence(frame, violation):
    """
    Extract an image showing the violation evidence.
    
    Args:
        frame (numpy.ndarray): Original video frame
        violation (dict): Violation information
        
    Returns:
        numpy.ndarray: Image showing the violation
    """
    return detector.extract_violation_image(frame, violation)
