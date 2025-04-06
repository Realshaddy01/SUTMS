"""
Test script for the traffic camera integration with license plate recognition.
"""

import os
import sys
import time
from traffic_camera import create_sample_cameras, process_camera_feed

def main():
    """
    Main function to run the traffic camera integration test.
    """
    print("=" * 50)
    print("Traffic Camera Integration Test")
    print("=" * 50)
    print("\nThis test will demonstrate the integration of traffic cameras")
    print("with the license plate recognition system.\n")
    
    # Create a set of sample cameras for testing
    print("Creating sample cameras...")
    manager = create_sample_cameras()
    cameras = manager.list_cameras()
    
    if not cameras:
        print("No cameras available for testing. Using dummy camera.")
    
    print(f"\nFound {len(cameras)} camera(s):")
    for i, camera in enumerate(cameras, 1):
        print(f"  {i}. {camera.name} - {camera.location}")
    
    print("\nProcessing camera feed for recognition...")
    # Process the first camera for a short duration (10 seconds)
    result = process_camera_feed(
        camera_id=cameras[0].camera_id if cameras else None,
        manager=manager,
        duration=10
    )
    
    if result["success"]:
        print("\nTest completed successfully!")
        print(f"Processed {result['frames_processed']} frames")
        print(f"Detected {result['plates_detected']} license plates")
        print(f"\nResults saved to: {result['results_path']}")
        if "animation_path" in result and result["animation_path"]:
            print(f"Animation saved to: {result['animation_path']}")
    else:
        print(f"\nTest failed: {result.get('error', 'Unknown error')}")
    
    # Clean up
    manager.disconnect_all()
    print("\nTest complete!")

if __name__ == "__main__":
    main()