"""
Test script for the traffic camera API endpoints.
"""
import os
import sys
import time
import json
import argparse
import requests
from datetime import datetime

def test_camera_api(base_url='http://localhost:5000/api/v1/cameras/', username=None, password=None):
    """
    Test the traffic camera API endpoints.
    
    Args:
        base_url: Base URL for the API
        username: Username for authentication
        password: Password for authentication
    """
    # Authentication
    if username and password:
        auth_url = base_url.replace('/cameras/', '/auth/token/')
        auth_data = {
            'username': username,
            'password': password
        }
        print(f"Authenticating as {username}...")
        auth_response = requests.post(auth_url, json=auth_data)
        
        if auth_response.status_code == 200:
            token = auth_response.json().get('access')
            headers = {
                'Authorization': f'Bearer {token}',
                'Content-Type': 'application/json'
            }
            print("Authentication successful")
        else:
            print(f"Authentication failed: {auth_response.text}")
            return False
    else:
        # No authentication
        headers = {
            'Content-Type': 'application/json'
        }
        print("Running without authentication")
    
    # Test the camera list endpoint
    print("\nTesting camera list endpoint...")
    try:
        cameras_url = base_url
        response = requests.get(cameras_url, headers=headers)
        
        if response.status_code == 200:
            cameras = response.json()
            print(f"Found {len(cameras)} cameras")
            
            if len(cameras) > 0:
                print("First camera:")
                print(json.dumps(cameras[0], indent=2))
            
            return cameras
        else:
            print(f"Error getting cameras: {response.status_code} - {response.text}")
            return None
    except Exception as e:
        print(f"Error accessing API: {str(e)}")
        return None

def test_simulate_capture(base_url='http://localhost:5000/api/v1/cameras/', 
                         camera_id='SIM001', username=None, password=None):
    """
    Test the simulate capture endpoint.
    
    Args:
        base_url: Base URL for the API
        camera_id: ID of the camera to simulate
        username: Username for authentication
        password: Password for authentication
    """
    # Authentication
    if username and password:
        auth_url = base_url.replace('/cameras/', '/auth/token/')
        auth_data = {
            'username': username,
            'password': password
        }
        print(f"Authenticating as {username}...")
        auth_response = requests.post(auth_url, json=auth_data)
        
        if auth_response.status_code == 200:
            token = auth_response.json().get('access')
            headers = {
                'Authorization': f'Bearer {token}',
                'Content-Type': 'application/json'
            }
            print("Authentication successful")
        else:
            print(f"Authentication failed: {auth_response.text}")
            return False
    else:
        # No authentication
        headers = {
            'Content-Type': 'application/json'
        }
        print("Running without authentication")
    
    # Test simulate capture
    print(f"\nTesting simulate capture for camera {camera_id}...")
    try:
        simulate_url = f"{base_url}simulate/"
        data = {
            'camera_id': camera_id
        }
        
        response = requests.post(simulate_url, json=data, headers=headers)
        
        if response.status_code == 200:
            result = response.json()
            print("Simulation successful!")
            print(json.dumps(result, indent=2))
            return result
        else:
            print(f"Error simulating capture: {response.status_code} - {response.text}")
            return None
    except Exception as e:
        print(f"Error accessing API: {str(e)}")
        return None

def test_upload_image(base_url='http://localhost:5000/api/v1/cameras/', 
                     camera_id='SIM001', image_path='test_plate.jpg',
                     username=None, password=None):
    """
    Test uploading an image to the camera API.
    
    Args:
        base_url: Base URL for the API
        camera_id: ID of the camera that captured the image
        image_path: Path to the image file
        username: Username for authentication
        password: Password for authentication
    """
    # Check if image exists
    if not os.path.exists(image_path):
        print(f"Error: Image file not found: {image_path}")
        return None
    
    # Authentication
    if username and password:
        auth_url = base_url.replace('/cameras/', '/auth/token/')
        auth_data = {
            'username': username,
            'password': password
        }
        print(f"Authenticating as {username}...")
        auth_response = requests.post(auth_url, json=auth_data)
        
        if auth_response.status_code == 200:
            token = auth_response.json().get('access')
            headers = {
                'Authorization': f'Bearer {token}'
            }
            print("Authentication successful")
        else:
            print(f"Authentication failed: {auth_response.text}")
            return False
    else:
        # No authentication
        headers = {}
        print("Running without authentication")
    
    # Test upload image
    print(f"\nTesting upload image for camera {camera_id}...")
    try:
        upload_url = f"{base_url}upload/"
        
        with open(image_path, 'rb') as image_file:
            files = {
                'image': (os.path.basename(image_path), image_file, 'image/jpeg')
            }
            data = {
                'camera_id': camera_id
            }
            
            response = requests.post(upload_url, data=data, files=files, headers=headers)
        
        if response.status_code == 200:
            result = response.json()
            print("Upload successful!")
            print(json.dumps(result, indent=2))
            return result
        else:
            print(f"Error uploading image: {response.status_code} - {response.text}")
            return None
    except Exception as e:
        print(f"Error accessing API: {str(e)}")
        return None

def main():
    """Main function to run the camera API test."""
    parser = argparse.ArgumentParser(description='Test the traffic camera API endpoints')
    parser.add_argument('--url', default='http://localhost:5000/api/v1/cameras/',
                        help='Base URL for the API')
    parser.add_argument('--username', help='Username for authentication')
    parser.add_argument('--password', help='Password for authentication')
    parser.add_argument('--camera-id', default='SIM001', help='Camera ID for testing')
    parser.add_argument('--image', default='test_plate.jpg', help='Image for upload testing')
    parser.add_argument('--test-type', choices=['list', 'simulate', 'upload', 'all'],
                        default='all', help='Type of test to run')
    
    args = parser.parse_args()
    
    if args.test_type == 'list' or args.test_type == 'all':
        cameras = test_camera_api(args.url, args.username, args.password)
    
    if args.test_type == 'simulate' or args.test_type == 'all':
        result = test_simulate_capture(args.url, args.camera_id, args.username, args.password)
    
    if args.test_type == 'upload' or args.test_type == 'all':
        result = test_upload_image(args.url, args.camera_id, args.image, args.username, args.password)

if __name__ == '__main__':
    main()