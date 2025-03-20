import cv2
import numpy as np
import tensorflow as tf
import os
from django.conf import settings
import pytesseract
from PIL import Image
import io

# Load models
def load_model(model_path):
    """Load a TensorFlow Lite model"""
    interpreter = tf.lite.Interpreter(model_path=model_path)
    interpreter.allocate_tensors()
    return interpreter

# Number plate detection
def detect_number_plate(image_data, model_path):
    """Detect number plate in image"""
    # Convert bytes to numpy array
    nparr = np.frombuffer(image_data, np.uint8)
    # Decode image
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    
    # Preprocess image
    img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    img_resized = cv2.resize(img_rgb, (300, 300))
    img_normalized = img_resized / 255.0
    img_normalized = img_normalized.astype(np.float32)
    img_expanded = np.expand_dims(img_normalized, axis=0)
    
    # Load model
    interpreter = load_model(model_path)
    
    # Get input and output tensors
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    
    # Set input tensor
    interpreter.set_tensor(input_details[0]['index'], img_expanded)
    
    # Run inference
    interpreter.invoke()
    
    # Get output tensor
    boxes = interpreter.get_tensor(output_details[0]['index'])[0]
    classes = interpreter.get_tensor(output_details[1]['index'])[0]
    scores = interpreter.get_tensor(output_details[2]['index'])[0]
    
    # Filter results
    threshold = 0.5
    valid_detections = []
    
    for i in range(len(scores)):
        if scores[i] > threshold and classes[i] == 0:  # Assuming class 0 is license plate
            y1, x1, y2, x2 = boxes[i]
            y1 = int(y1 * img.shape[0])
            x1 = int(x1 * img.shape[1])
            y2 = int(y2 * img.shape[0])
            x2 = int(x2 * img.shape[1])
            
            # Extract license plate region
            plate_img = img[y1:y2, x1:x2]
            
            # OCR to extract text
            plate_text = extract_text_from_plate(plate_img)
            
            valid_detections.append({
                'box': [x1, y1, x2, y2],
                'confidence': float(scores[i]),
                'plate_text': plate_text
            })
    
    return valid_detections

def extract_text_from_plate(plate_img):
    """Extract text from license plate image using OCR"""
    # Convert to grayscale
    gray = cv2.cvtColor(plate_img, cv2.COLOR_BGR2GRAY)
    
    # Apply bilateral filter to remove noise while keeping edges sharp
    gray = cv2.bilateralFilter(gray, 11, 17, 17)
    
    # Apply threshold to get black and white image
    _, thresh = cv2.threshold(gray, 150, 255, cv2.THRESH_BINARY)
    
    # Convert to PIL Image for pytesseract
    pil_img = Image.fromarray(thresh)
    
    # Use pytesseract to extract text
    text = pytesseract.image_to_string(pil_img, config='--psm 7')
    
    # Clean and format the extracted text
    text = text.strip().replace(' ', '').replace('\n', '')
    
    return text

# Speed violation detection
def detect_speed_violation(video_path, model_path):
    """Detect speed violations in video"""
    # Load video
    cap = cv2.VideoCapture(video_path)
    fps = cap.get(cv2.CAP_PROP_FPS)
    
    # Load model
    interpreter = load_model(model_path)
    
    # Get input and output tensors
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    
    # Initialize variables
    frame_count = 0
    vehicle_tracks = {}
    speed_violations = []
    
    # Process video frames
    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break
        
        # Process every 5th frame for efficiency
        if frame_count % 5 == 0:
            # Preprocess frame
            frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            frame_resized = cv2.resize(frame_rgb, (300, 300))
            frame_normalized = frame_resized / 255.0
            frame_normalized = frame_normalized.astype(np.float32)
            frame_expanded = np.expand_dims(frame_normalized, axis=0)
            
            # Set input tensor
            interpreter.set_tensor(input_details[0]['index'], frame_expanded)
            
            # Run inference
            interpreter.invoke()
            
            # Get output tensor
            boxes = interpreter.get_tensor(output_details[0]['index'])[0]
            classes = interpreter.get_tensor(output_details[1]['index'])[0]
            scores = interpreter.get_tensor(output_details[2]['index'])[0]
            
            # Filter results
            threshold = 0.5
            
            for i in range(len(scores)):
                if scores[i] > threshold and classes[i] == 0:  # Assuming class 0 is vehicle
                    y1, x1, y2, x2 = boxes[i]
                    y1 = int(y1 * frame.shape[0])
                    x1 = int(x1 * frame.shape[1])
                    y2 = int(y2 * frame.shape[0])
                    x2 = int(x2 * frame.shape[1])
                    
                    # Calculate center of box
                    center_x = (x1 + x2) / 2
                    center_y = (y1 + y2) / 2
                    
                    # Track vehicle
                    vehicle_id = None
                    min_distance = float('inf')
                    
                    for vid, track in vehicle_tracks.items():
                        if len(track) > 0:
                            last_x, last_y, last_frame = track[-1]
                            distance = ((center_x - last_x) ** 2 + (center_y - last_y) ** 2) ** 0.5
                            
                            if distance < min_distance and distance < 50:  # Threshold for same vehicle
                                min_distance = distance
                                vehicle_id = vid
                    
                    if vehicle_id is None:
                        vehicle_id = len(vehicle_tracks)
                        vehicle_tracks[vehicle_id] = []
                    
                    vehicle_tracks[vehicle_id].append((center_x, center_y, frame_count))
                    
                    # Calculate speed if we have enough tracking points
                    if len(vehicle_tracks[vehicle_id]) >= 5:
                        # Get first and last tracking points
                        first_x, first_y, first_frame = vehicle_tracks[vehicle_id][0]
                        last_x, last_y, last_frame = vehicle_tracks[vehicle_id][-1]
                        
                        # Calculate distance in pixels
                        distance_px = ((last_x - first_x) ** 2 + (last_y - first_y) ** 2) ** 0.5
                        
                        # Calculate time in seconds
                        time_sec = (last_frame - first_frame) / fps
                        
                        # Convert pixels to meters (assuming 1 pixel = 0.1 meters)
                        distance_m = distance_px * 0.1
                        
                        # Calculate speed in km/h
                        speed = (distance_m / time_sec) * 3.6
                        
                        # Check if speed exceeds limit (e.g., 50 km/h)
                        if speed > 50:
                            # Extract license plate
                            plate_img = frame[y1:y2, x1:x2]
                            plate_text = extract_text_from_plate(plate_img)
                            
                            # Save violation
                            speed_violations.append({
                                'frame': frame_count,
                                'timestamp': frame_count / fps,
                                'speed': speed,
                                'box': [x1, y1, x2, y2],
                                'plate_text': plate_text,
                                'confidence': float(scores[i])
                            })
        
        frame_count += 1
    
    cap.release()
    return speed_violations

# Signal violation detection
def detect_signal_violation(video_path, model_path):
    """Detect signal violations in video"""
    # Implementation similar to speed violation detection
    # but focusing on vehicles crossing red lights
    pass

# Parking violation detection
def detect_parking_violation(video_path, model_path):
    """Detect parking violations in video"""
    # Implementation for detecting vehicles in no-parking zones
    pass

# Over capacity detection
def detect_over_capacity(video_path, model_path):
    """Detect vehicles with over capacity"""
    # Implementation for detecting vehicles with too many passengers
    pass

# Foreign vehicle detection
def detect_foreign_vehicle(video_path, model_path):
    """Detect unauthorized foreign vehicles"""
    # Implementation for detecting vehicles with foreign license plates
    pass

