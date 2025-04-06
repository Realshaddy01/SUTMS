"""
Script to test the OCR API by uploading a sample image.
"""
import os
import requests
import argparse
from pathlib import Path
import json

def test_ocr_api(image_path, url, token=None):
    """
    Test the OCR API by uploading a sample image.
    
    Args:
        image_path: Path to the image file
        url: API endpoint URL
        token: Authentication token (if required)
    """
    print(f"Testing OCR API with image: {image_path}")
    
    # Check if file exists
    if not os.path.isfile(image_path):
        print(f"Error: File not found - {image_path}")
        return
    
    # Prepare headers
    headers = {}
    if token:
        headers['Authorization'] = f'Token {token}'
    
    # Prepare files
    with open(image_path, 'rb') as img_file:
        files = {'image': (os.path.basename(image_path), img_file, 'image/jpeg')}
        
        # Make the request
        try:
            response = requests.post(url, headers=headers, files=files)
            
            # Check response
            if response.status_code == 200:
                print("Request successful!")
                print(json.dumps(response.json(), indent=2))
            else:
                print(f"Request failed with status code: {response.status_code}")
                print(response.text)
        
        except Exception as e:
            print(f"Error making request: {str(e)}")

def main():
    parser = argparse.ArgumentParser(description='Test the license plate OCR API')
    parser.add_argument('--image', required=True, help='Path to the image file')
    parser.add_argument('--url', default='http://localhost:5000/ocr/detect/', help='API endpoint URL')
    parser.add_argument('--token', help='Authentication token')
    
    args = parser.parse_args()
    test_ocr_api(args.image, args.url, args.token)

if __name__ == '__main__':
    main()