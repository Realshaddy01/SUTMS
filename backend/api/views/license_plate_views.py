"""
License plate detection views.
"""
from rest_framework import viewsets, status
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
import os
import tempfile
from django.conf import settings
import uuid
import json
import base64

class LicensePlateDetectionViewSet(viewsets.ModelViewSet):
    """
    API endpoint that allows license plates to be detected from images.
    """
    permission_classes = [IsAuthenticated]
    
    def create(self, request):
        """
        Process an image and detect license plate.
        
        Request body should contain:
        - image: base64 encoded image
        
        Returns:
        - license_plate: detected license plate text
        - confidence: confidence score
        - coordinates: coordinates of detected license plate in the image
        """
        try:
            # Get image from request
            image_data = request.data.get('image')
            if not image_data:
                return Response({
                    'error': 'No image provided'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Save image to temp file
            temp_dir = tempfile.mkdtemp()
            temp_image_path = os.path.join(temp_dir, f"{uuid.uuid4()}.jpg")
            
            # Handle base64 encoded images
            if isinstance(image_data, str) and image_data.startswith('data:image'):
                header, encoded = image_data.split(",", 1)
                with open(temp_image_path, "wb") as f:
                    f.write(base64.b64decode(encoded))
            else:
                # Handle direct file upload
                with open(temp_image_path, "wb") as f:
                    for chunk in request.FILES['image'].chunks():
                        f.write(chunk)
            
            # Here we would normally use a real license plate detection model
            # For this mockup, we'll just return a fixed response
            license_plate = "बा २१ प १२३४"
            confidence = 0.95
            coordinates = {
                "top_left": [100, 200],
                "top_right": [300, 200],
                "bottom_right": [300, 250],
                "bottom_left": [100, 250]
            }
            
            # Clean up the temp file
            try:
                os.remove(temp_image_path)
                os.rmdir(temp_dir)
            except Exception as e:
                print(f"Error cleaning up temp files: {e}")
            
            return Response({
                'license_plate': license_plate,
                'confidence': confidence,
                'coordinates': coordinates
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            return Response({
                'error': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

# Additional helper functions for license plate detection
def detect_license_plate(image_path):
    """
    Detect license plate from image.
    This is a mockup function that would normally use a real detection model.
    
    Args:
        image_path: Path to the image file
        
    Returns:
        tuple: (license_plate, confidence, coordinates)
    """
    # Mock response
    return "बा २१ प १२३४", 0.95, {
        "top_left": [100, 200],
        "top_right": [300, 200],
        "bottom_right": [300, 250],
        "bottom_left": [100, 250]
    } 