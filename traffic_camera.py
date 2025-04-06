"""
Traffic Camera Integration for Smart Urban Traffic Management System.
This module provides functionality to connect to and retrieve images from traffic cameras.
"""

import cv2
import numpy as np
import time
import os
import urllib.request
import threading
import queue
from datetime import datetime
import json
import requests
from enum import Enum

# Local imports for OCR processing
from optimized_ocr import ocr_license_plate
from animated_progress import LicensePlateProgressIndicator

class CameraStatus(Enum):
    """Status of a traffic camera connection."""
    OFFLINE = 0
    CONNECTING = 1
    ONLINE = 2
    ERROR = 3

class TrafficCamera:
    """Class for handling a single traffic camera."""
    
    def __init__(self, camera_id, name, location, url=None, capture_interval=5, 
                 auth_token=None, coordinates=None):
        """
        Initialize a traffic camera object.
        
        Args:
            camera_id: Unique identifier for the camera
            name: Display name for the camera
            location: Textual description of camera location
            url: URL to access the camera feed (RTSP, HTTP, or local file path)
            capture_interval: Interval between image captures in seconds
            auth_token: Authentication token for accessing the camera (if applicable)
            coordinates: Tuple of (latitude, longitude) for the camera location
        """
        self.camera_id = camera_id
        self.name = name
        self.location = location
        self.url = url
        self.capture_interval = capture_interval
        self.auth_token = auth_token
        self.coordinates = coordinates or (0.0, 0.0)
        
        # Runtime attributes
        self.status = CameraStatus.OFFLINE
        self.last_capture_time = None
        self.last_image = None
        self.error_message = None
        self.video_capture = None
        self.is_streaming = False
        self._stream_thread = None
        self._frame_queue = queue.Queue(maxsize=5)  # Limit queue size to avoid memory issues
        
        # Storage for captured images
        self.image_dir = os.path.join("camera_captures", f"camera_{self.camera_id}")
        os.makedirs(self.image_dir, exist_ok=True)
    
    def connect(self):
        """Connect to the camera source."""
        if self.status == CameraStatus.ONLINE:
            return True
            
        self.status = CameraStatus.CONNECTING
        
        try:
            # Handle different camera source types
            if self.url:
                if self.url.startswith("rtsp://") or self.url.startswith("http://") or self.url.startswith("https://"):
                    # For network streams
                    self.video_capture = cv2.VideoCapture(self.url)
                elif os.path.exists(self.url):
                    # For local video files
                    self.video_capture = cv2.VideoCapture(self.url)
                else:
                    raise ValueError(f"Invalid camera URL: {self.url}")
                    
                if not self.video_capture.isOpened():
                    raise ConnectionError(f"Failed to connect to camera at {self.url}")
                    
                self.status = CameraStatus.ONLINE
                return True
            else:
                # Default to the first available camera if no URL provided
                self.video_capture = cv2.VideoCapture(0)
                if not self.video_capture.isOpened():
                    raise ConnectionError("Failed to connect to default camera")
                    
                self.status = CameraStatus.ONLINE
                return True
                
        except Exception as e:
            self.status = CameraStatus.ERROR
            self.error_message = str(e)
            print(f"Error connecting to camera {self.camera_id}: {str(e)}")
            return False
    
    def disconnect(self):
        """Disconnect from the camera source."""
        self.stop_streaming()
        
        if self.video_capture:
            self.video_capture.release()
            self.video_capture = None
            
        self.status = CameraStatus.OFFLINE
    
    def capture_frame(self):
        """
        Capture a single frame from the camera.
        
        Returns:
            The captured frame as a numpy array, or None if capture failed
        """
        if self.status != CameraStatus.ONLINE:
            if not self.connect():
                return None
        
        try:
            ret, frame = self.video_capture.read()
            if not ret:
                self.status = CameraStatus.ERROR
                self.error_message = "Failed to read frame from camera"
                return None
                
            self.last_capture_time = datetime.now()
            self.last_image = frame.copy()
            return frame
            
        except Exception as e:
            self.status = CameraStatus.ERROR
            self.error_message = str(e)
            print(f"Error capturing frame from camera {self.camera_id}: {str(e)}")
            return None
    
    def _streaming_worker(self, stop_event):
        """Worker function for the streaming thread."""
        while not stop_event.is_set():
            if self.status != CameraStatus.ONLINE:
                if not self.connect():
                    time.sleep(1)  # Wait before retry
                    continue
            
            try:
                ret, frame = self.video_capture.read()
                if not ret:
                    self.status = CameraStatus.ERROR
                    self.error_message = "Failed to read frame from camera"
                    time.sleep(0.5)  # Short delay before retry
                    continue
                    
                # Update last_image and timestamp
                self.last_capture_time = datetime.now()
                self.last_image = frame.copy()
                
                # Add to queue, replacing oldest frame if full
                if self._frame_queue.full():
                    try:
                        self._frame_queue.get_nowait()  # Discard oldest frame
                    except queue.Empty:
                        pass  # Queue was emptied by another thread
                
                try:
                    self._frame_queue.put_nowait(frame)
                except queue.Full:
                    pass  # Queue is full again after all
                
                # Short sleep to control frame rate
                time.sleep(0.1)
                
            except Exception as e:
                self.status = CameraStatus.ERROR
                self.error_message = str(e)
                print(f"Error in streaming from camera {self.camera_id}: {str(e)}")
                time.sleep(1)  # Wait before retry
    
    def start_streaming(self):
        """Start streaming from the camera in a background thread."""
        if self.is_streaming:
            return
            
        if self.status != CameraStatus.ONLINE:
            if not self.connect():
                return
        
        # Create stop event and worker thread
        self._stop_event = threading.Event()
        self._stream_thread = threading.Thread(
            target=self._streaming_worker,
            args=(self._stop_event,),
            daemon=True
        )
        
        self.is_streaming = True
        self._stream_thread.start()
    
    def stop_streaming(self):
        """Stop streaming from the camera."""
        if not self.is_streaming:
            return
            
        if self._stop_event:
            self._stop_event.set()
            
        if self._stream_thread:
            self._stream_thread.join(timeout=2.0)
            
        self.is_streaming = False
        self._stream_thread = None
        
        # Clear the queue
        while not self._frame_queue.empty():
            try:
                self._frame_queue.get_nowait()
            except queue.Empty:
                break
    
    def get_latest_frame(self):
        """
        Get the latest frame from the streaming queue.
        
        Returns:
            The latest frame, or None if no frames are available
        """
        if not self.is_streaming:
            # If not streaming, capture a single frame
            return self.capture_frame()
            
        try:
            return self._frame_queue.get_nowait()
        except queue.Empty:
            return None
    
    def save_frame(self, frame=None, filename=None):
        """
        Save a frame to disk.
        
        Args:
            frame: The frame to save, or None to use the latest captured frame
            filename: Custom filename, or None to generate automatically
            
        Returns:
            Path to the saved image file
        """
        if frame is None:
            frame = self.last_image
            
        if frame is None:
            print(f"No frame available to save for camera {self.camera_id}")
            return None
            
        if filename is None:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"camera_{self.camera_id}_{timestamp}.jpg"
            
        filepath = os.path.join(self.image_dir, filename)
        
        try:
            cv2.imwrite(filepath, frame)
            print(f"Saved frame to {filepath}")
            return filepath
        except Exception as e:
            print(f"Error saving frame for camera {self.camera_id}: {str(e)}")
            return None
    
    def to_dict(self):
        """Convert the camera object to a dictionary for serialization."""
        return {
            "camera_id": self.camera_id,
            "name": self.name,
            "location": self.location,
            "url": self.url,
            "capture_interval": self.capture_interval,
            "coordinates": self.coordinates,
            "status": self.status.name,
            "last_capture_time": str(self.last_capture_time) if self.last_capture_time else None,
            "is_streaming": self.is_streaming,
            "error_message": self.error_message,
        }
    
    def __str__(self):
        """String representation of the camera."""
        status_str = self.status.name
        if self.error_message:
            status_str += f" ({self.error_message})"
            
        return f"Camera {self.camera_id}: {self.name} at {self.location} - {status_str}"

class TrafficCameraManager:
    """Class for managing multiple traffic cameras."""
    
    def __init__(self, config_file=None):
        """
        Initialize the traffic camera manager.
        
        Args:
            config_file: Path to a JSON configuration file with camera definitions
        """
        self.cameras = {}
        self.config_file = config_file
        
        if config_file and os.path.exists(config_file):
            self.load_config(config_file)
    
    def add_camera(self, camera):
        """
        Add a camera to the manager.
        
        Args:
            camera: A TrafficCamera object
            
        Returns:
            The added camera
        """
        self.cameras[camera.camera_id] = camera
        return camera
    
    def remove_camera(self, camera_id):
        """
        Remove a camera from the manager.
        
        Args:
            camera_id: ID of the camera to remove
            
        Returns:
            True if camera was removed, False if not found
        """
        if camera_id in self.cameras:
            camera = self.cameras[camera_id]
            camera.disconnect()
            del self.cameras[camera_id]
            return True
        return False
    
    def get_camera(self, camera_id):
        """
        Get a camera by ID.
        
        Args:
            camera_id: ID of the camera to retrieve
            
        Returns:
            The TrafficCamera object, or None if not found
        """
        return self.cameras.get(camera_id)
    
    def list_cameras(self):
        """
        Get a list of all cameras.
        
        Returns:
            List of camera objects
        """
        return list(self.cameras.values())
    
    def connect_all(self):
        """
        Connect to all cameras.
        
        Returns:
            Dictionary mapping camera_id to connection success (True/False)
        """
        results = {}
        for camera_id, camera in self.cameras.items():
            results[camera_id] = camera.connect()
        return results
    
    def disconnect_all(self):
        """Disconnect from all cameras."""
        for camera in self.cameras.values():
            camera.disconnect()
    
    def save_config(self, config_file=None):
        """
        Save the camera configuration to a JSON file.
        
        Args:
            config_file: Path to save the configuration, or None to use the default
            
        Returns:
            Path to the saved configuration file
        """
        config_file = config_file or self.config_file
        if not config_file:
            config_file = "camera_config.json"
            
        camera_configs = {}
        for camera_id, camera in self.cameras.items():
            # Only save essential configuration, not runtime state
            camera_configs[camera_id] = {
                "camera_id": camera.camera_id,
                "name": camera.name,
                "location": camera.location,
                "url": camera.url,
                "capture_interval": camera.capture_interval,
                "coordinates": camera.coordinates,
            }
            
        try:
            with open(config_file, 'w') as f:
                json.dump(camera_configs, f, indent=2)
            print(f"Saved camera configuration to {config_file}")
            return config_file
        except Exception as e:
            print(f"Error saving camera configuration: {str(e)}")
            return None
    
    def load_config(self, config_file=None):
        """
        Load camera configuration from a JSON file.
        
        Args:
            config_file: Path to the configuration file, or None to use the default
            
        Returns:
            Number of cameras loaded
        """
        config_file = config_file or self.config_file
        if not config_file or not os.path.exists(config_file):
            print(f"Configuration file not found: {config_file}")
            return 0
            
        try:
            with open(config_file, 'r') as f:
                camera_configs = json.load(f)
                
            # Remove existing cameras
            for camera_id in list(self.cameras.keys()):
                self.remove_camera(camera_id)
                
            # Add cameras from config
            for camera_id, config in camera_configs.items():
                camera = TrafficCamera(
                    camera_id=config["camera_id"],
                    name=config["name"],
                    location=config["location"],
                    url=config.get("url"),
                    capture_interval=config.get("capture_interval", 5),
                    coordinates=config.get("coordinates", (0.0, 0.0))
                )
                self.add_camera(camera)
                
            print(f"Loaded {len(self.cameras)} cameras from {config_file}")
            return len(self.cameras)
        except Exception as e:
            print(f"Error loading camera configuration: {str(e)}")
            return 0
    
    def capture_from_all(self, save_frames=False):
        """
        Capture frames from all cameras.
        
        Args:
            save_frames: Whether to save the captured frames to disk
            
        Returns:
            Dictionary mapping camera_id to the captured frame (or None if capture failed)
        """
        results = {}
        for camera_id, camera in self.cameras.items():
            frame = camera.capture_frame()
            if frame is not None and save_frames:
                camera.save_frame(frame)
            results[camera_id] = frame
        return results
    
    def start_streaming_all(self):
        """Start streaming from all cameras."""
        for camera in self.cameras.values():
            camera.start_streaming()
    
    def stop_streaming_all(self):
        """Stop streaming from all cameras."""
        for camera in self.cameras.values():
            camera.stop_streaming()

def create_sample_cameras():
    """Create sample camera objects for testing."""
    # Create camera manager
    manager = TrafficCameraManager()
    
    # Add sample camera using local test video file (if available)
    test_video = "test_traffic.mp4"
    if os.path.exists(test_video):
        manager.add_camera(TrafficCamera(
            camera_id="cam1",
            name="Test Traffic Camera 1",
            location="Main Street Intersection",
            url=test_video,
            coordinates=(27.7172, 85.3240)  # Kathmandu coordinates
        ))
        
    # Add a camera using a sample image instead of video
    test_image = "new_improved_test_plate.jpg"
    if os.path.exists(test_image):
        manager.add_camera(TrafficCamera(
            camera_id="cam2",
            name="Test Static Camera",
            location="Highway Entrance",
            url=test_image,  # Use as static image source
            coordinates=(27.6910, 85.3512)  # Nearby location
        ))
        
    # Add a simulated camera using OpenCV's built-in camera (if available)
    try:
        test_cam = cv2.VideoCapture(0)
        if test_cam.isOpened():
            test_cam.release()
            manager.add_camera(TrafficCamera(
                camera_id="cam3",
                name="Local Camera",
                location="System Camera",
                url=0,  # Use default camera
                coordinates=(27.7000, 85.3333)
            ))
    except:
        pass  # Skip if no camera available
    
    # Save the configuration
    manager.save_config()
    
    # If no cameras were found, create a dummy camera
    if not manager.cameras:
        # Create a dummy camera that generates a synthetic image
        dummy_camera = TrafficCamera(
            camera_id="dummy1",
            name="Synthetic Camera",
            location="Virtual Location",
            url=None
        )
        
        # Override the capture_frame method to generate a synthetic image
        def dummy_capture_frame(self):
            # Create a blank image
            frame = np.ones((480, 640, 3), dtype=np.uint8) * 255
            
            # Add some text
            cv2.putText(
                frame,
                "No real camera available",
                (50, 240),
                cv2.FONT_HERSHEY_SIMPLEX,
                1,
                (0, 0, 0),
                2,
                cv2.LINE_AA
            )
            
            # Add current timestamp
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            cv2.putText(
                frame,
                timestamp,
                (50, 270),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.7,
                (0, 0, 0),
                2,
                cv2.LINE_AA
            )
            
            # Use a test image if available
            test_plate = "new_improved_test_plate.jpg"
            if os.path.exists(test_plate):
                try:
                    plate_img = cv2.imread(test_plate)
                    if plate_img is not None:
                        h, w = plate_img.shape[:2]
                        # Resize the plate if necessary
                        if h > 100:
                            scale = 100 / h
                            new_w = int(w * scale)
                            plate_img = cv2.resize(plate_img, (new_w, 100))
                            h, w = plate_img.shape[:2]
                        
                        # Insert the plate image
                        y_offset = 320
                        x_offset = 50
                        frame[y_offset:y_offset+h, x_offset:x_offset+w] = plate_img
                        
                        # Add a label
                        cv2.putText(
                            frame,
                            "Sample License Plate",
                            (50, 310),
                            cv2.FONT_HERSHEY_SIMPLEX,
                            0.7,
                            (0, 0, 0),
                            2,
                            cv2.LINE_AA
                        )
                except Exception as e:
                    print(f"Error loading test plate: {str(e)}")
            
            self.last_image = frame.copy()
            self.last_capture_time = datetime.now()
            self.status = CameraStatus.ONLINE
            return frame
        
        # Override the connect method to always succeed
        def dummy_connect(self):
            self.status = CameraStatus.ONLINE
            return True
        
        # Patch the dummy camera
        dummy_camera.capture_frame = dummy_capture_frame.__get__(dummy_camera)
        dummy_camera.connect = dummy_connect.__get__(dummy_camera)
        
        # Add the dummy camera
        manager.add_camera(dummy_camera)
        manager.save_config()
    
    return manager

def process_camera_feed(camera_id=None, manager=None, duration=30):
    """
    Process camera feed for a specified duration, detecting license plates.
    
    Args:
        camera_id: ID of the camera to process, or None to use the first available
        manager: TrafficCameraManager instance, or None to create a new one
        duration: Duration to process in seconds
        
    Returns:
        Dictionary with processing results
    """
    # Create or use camera manager
    if manager is None:
        manager = create_sample_cameras()
    
    # Connect all cameras
    manager.connect_all()
    
    # Get the specific camera or the first available
    if camera_id and camera_id in manager.cameras:
        camera = manager.get_camera(camera_id)
    elif manager.cameras:
        camera = list(manager.cameras.values())[0]
    else:
        print("No cameras available")
        return {"success": False, "error": "No cameras available"}
    
    print(f"Processing feed from camera: {camera.name}")
    
    # Start streaming
    camera.start_streaming()
    
    # Create directory for results
    results_dir = os.path.join("camera_results", f"camera_{camera.camera_id}")
    os.makedirs(results_dir, exist_ok=True)
    
    # Create animated progress indicator
    progress = LicensePlateProgressIndicator(save_dir=results_dir)
    
    # Process frames for the specified duration
    start_time = time.time()
    end_time = start_time + duration
    
    detection_results = []
    frame_count = 0
    detected_count = 0
    
    while time.time() < end_time:
        # Get frame from camera
        frame = camera.get_latest_frame()
        if frame is None:
            print("Failed to get frame, retrying...")
            time.sleep(0.5)
            continue
            
        frame_count += 1
        
        # Save frame for demonstration
        frame_path = camera.save_frame(frame, filename=f"frame_{frame_count:04d}.jpg")
        
        # Update progress (step 1: Frame capture)
        progress.next_step(save=True)
        
        # Try to detect and recognize license plates
        try:
            # Preprocess the frame to find potential license plates (step 2)
            progress.next_step(save=True)
            
            # For demonstration purposes, we'll use our plate detector on the whole frame
            # In a real implementation, we'd use a dedicated plate detector model first
            plate_path = os.path.join(results_dir, f"plate_candidate_{frame_count:04d}.jpg")
            cv2.imwrite(plate_path, frame)
            
            # Simulate plate detection (step 3)
            progress.next_step(save=True)
            
            # Perform OCR on the detected plate (step 4)
            progress.next_step(save=True)
            ocr_result = ocr_license_plate(plate_path)
            
            # Process the OCR result (step 5)
            progress.next_step(save=True)
            
            if ocr_result["success"]:
                detected_count += 1
                result = {
                    "frame_number": frame_count,
                    "frame_path": frame_path,
                    "plate_path": plate_path,
                    "ocr_text": ocr_result.get("processed_text", ""),
                    "confidence": ocr_result.get("confidence", 0),
                    "timestamp": datetime.now().isoformat()
                }
                detection_results.append(result)
                
                print(f"Detected plate: {result['ocr_text']} (Confidence: {result['confidence']:.2f}%)")
                
                # Mark progress as complete
                progress.complete(save=True)
            else:
                # If OCR failed, still complete the progress for this frame
                progress.complete(save=True)
                
            # Reset progress for next frame
            progress.current_step = 0
        
        except Exception as e:
            print(f"Error processing frame: {str(e)}")
            # Still complete the progress animation
            progress.complete(save=True)
            progress.current_step = 0
            
        # Short delay between frames to avoid overwhelming the system
        time.sleep(0.2)
    
    # Stop streaming
    camera.stop_streaming()
    
    # Create an animated GIF of the progress
    animation_path = progress.create_animation(
        output_path=os.path.join(results_dir, "recognition_process.gif")
    )
    
    # Save results to a JSON file
    results_path = os.path.join(results_dir, "detection_results.json")
    with open(results_path, 'w') as f:
        json.dump({
            "camera_id": camera.camera_id,
            "camera_name": camera.name,
            "frames_processed": frame_count,
            "plates_detected": detected_count,
            "duration_seconds": duration,
            "detections": detection_results
        }, f, indent=2)
    
    print(f"\nProcessing complete:")
    print(f"- Frames processed: {frame_count}")
    print(f"- Plates detected: {detected_count}")
    print(f"- Results saved to: {results_path}")
    print(f"- Animation saved to: {animation_path}")
    
    return {
        "success": True,
        "frames_processed": frame_count,
        "plates_detected": detected_count,
        "results_path": results_path,
        "animation_path": animation_path
    }
    
def main():
    """Main function to demonstrate traffic camera integration."""
    print("Traffic Camera Integration Demo")
    print("=" * 30)
    
    # Create camera manager with sample cameras
    manager = create_sample_cameras()
    
    # List available cameras
    cameras = manager.list_cameras()
    print(f"\nAvailable cameras ({len(cameras)}):")
    for i, camera in enumerate(cameras, 1):
        print(f"{i}. {camera.name} ({camera.camera_id}) - {camera.location}")
    
    # Process feed from the first camera for demonstration
    if cameras:
        print("\nProcessing camera feed...")
        result = process_camera_feed(cameras[0].camera_id, manager, duration=15)
        
        if result["success"]:
            print("\nDemo completed successfully!")
            print(f"Check the results in the {os.path.dirname(result['results_path'])} directory")
        else:
            print(f"\nDemo failed: {result.get('error', 'Unknown error')}")
    else:
        print("\nNo cameras available for demo")
    
    # Cleanup
    manager.disconnect_all()
    print("\nDemo finished")

if __name__ == "__main__":
    main()