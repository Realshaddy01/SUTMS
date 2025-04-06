"""
Management command to simulate traffic cameras capturing license plates.
"""
import os
import time
import random
from datetime import datetime

from django.core.management.base import BaseCommand
from django.core.files.base import ContentFile
from django.conf import settings

import sys
import cv2
import numpy as np

# Add the project root to the path for importing from the root modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.dirname(os.path.dirname(__file__))))))
from optimized_ocr import ocr_license_plate
from generate_test_plate import generate_nepali_plate
from animated_progress import LicensePlateProgressIndicator

from cameras.models import TrafficCamera, CameraCapture, CameraStatus


class Command(BaseCommand):
    help = 'Simulate traffic cameras capturing license plates'

    def add_arguments(self, parser):
        parser.add_argument(
            '--cameras',
            type=int,
            default=3,
            help='Number of cameras to simulate'
        )
        parser.add_argument(
            '--captures',
            type=int,
            default=5,
            help='Number of captures per camera'
        )
        parser.add_argument(
            '--interval',
            type=float,
            default=2.0,
            help='Interval between captures in seconds'
        )
        parser.add_argument(
            '--random-plates',
            action='store_true',
            help='Generate random license plates instead of using test plates'
        )
        parser.add_argument(
            '--animate',
            action='store_true',
            help='Show animated progress indicators'
        )

    def handle(self, *args, **options):
        num_cameras = options['cameras']
        num_captures = options['captures']
        interval = options['interval']
        random_plates = options['random_plates']
        animate = options['animate']
        
        self.stdout.write(self.style.SUCCESS(
            f'Simulating {num_cameras} cameras with {num_captures} captures each '
            f'at {interval} second intervals'
        ))
        
        # Create simulated cameras
        cameras = self._create_simulated_cameras(num_cameras)
        
        # Generate or load test images
        if random_plates:
            self.stdout.write('Generating random license plates...')
            test_images = self._generate_random_plates(num_cameras * num_captures)
        else:
            self.stdout.write('Using existing test plates...')
            test_images = self._load_test_plates()
        
        # Simulate captures
        self._simulate_captures(cameras, test_images, num_captures, interval, animate)
        
        self.stdout.write(self.style.SUCCESS('Simulation complete'))

    def _create_simulated_cameras(self, num_cameras):
        """Create simulated traffic cameras"""
        cameras = []
        locations = [
            'Kathmandu Durbar Square',
            'Thamel Junction',
            'New Road Gate',
            'Kalanki Chowk',
            'Koteshwor Chowk',
            'Chabahil Chowk',
            'Tripureshwor Junction',
            'Balaju Chowk',
            'Bouddha Stupa Road',
            'Sundhara Crossroad'
        ]
        
        # Delete all existing cameras and captures for clean simulation
        CameraCapture.objects.all().delete()
        TrafficCamera.objects.all().delete()
        
        for i in range(num_cameras):
            location = locations[i % len(locations)]
            camera = TrafficCamera.objects.create(
                camera_id=f'SIM{i+1:03d}',
                name=f'Simulated Camera {i+1}',
                location=location,
                status=CameraStatus.ONLINE,
                is_active=True,
                url=f'http://simulated-camera-{i+1}',
                latitude=random.uniform(27.6, 27.8),
                longitude=random.uniform(85.2, 85.4),
                capture_interval=5
            )
            cameras.append(camera)
            self.stdout.write(f'Created camera: {camera.name} at {camera.location}')
        
        return cameras

    def _load_test_plates(self):
        """Load existing test plate images"""
        test_images = []
        
        # Try to find test plate images
        project_root = os.path.dirname(os.path.dirname(os.path.dirname(
            os.path.dirname(os.path.dirname(__file__)))))
        
        possible_images = [
            os.path.join(project_root, 'test_plate.jpg'),
            os.path.join(project_root, 'new_test_plate.jpg'),
            os.path.join(project_root, 'new_improved_test_plate.jpg')
        ]
        
        for img_path in possible_images:
            if os.path.exists(img_path):
                test_images.append(img_path)
                self.stdout.write(f'Found test image: {img_path}')
        
        # If no test images found, generate one
        if not test_images:
            self.stdout.write('No test images found, generating one...')
            output_path = os.path.join(project_root, 'sim_test_plate.jpg')
            generate_nepali_plate(output_path=output_path)
            test_images.append(output_path)
            self.stdout.write(f'Generated test image: {output_path}')
        
        return test_images

    def _generate_random_plates(self, count):
        """Generate random license plates"""
        test_images = []
        project_root = os.path.dirname(os.path.dirname(os.path.dirname(
            os.path.dirname(os.path.dirname(__file__)))))
        
        # Nepali province codes
        province_codes = ['BA', 'GA', 'LU', 'KO', 'DH', 'JA', 'SE']
        
        # Nepali character sets (using Latin approximations)
        letter_codes = ['KA', 'KHA', 'GA', 'GHA', 'NGA', 
                         'CHA', 'CHHA', 'JA', 'JHA', 'YNA',
                         'TA', 'THA', 'DA', 'DHA', 'NA',
                         'PA', 'PHA', 'BA', 'BHA', 'MA',
                         'YA', 'RA', 'LA', 'WA', 'SHA',
                         'SA', 'HA', 'KSHA', 'TRA', 'GYA']
        
        # Generate random plates
        for i in range(count):
            province = random.choice(province_codes)
            number1 = random.randint(1, 99)
            letter = random.choice(letter_codes)
            number2 = random.randint(1, 9999)
            
            plate_text = f"{province} {number1} {letter} {number2}"
            output_path = os.path.join(project_root, f'sim_plate_{i+1}.jpg')
            
            generate_nepali_plate(text=plate_text, output_path=output_path)
            test_images.append(output_path)
            self.stdout.write(f'Generated plate: {plate_text} at {output_path}')
        
        return test_images

    def _simulate_captures(self, cameras, test_images, num_captures, interval, animate):
        """Simulate cameras capturing license plates"""
        for capture_index in range(num_captures):
            self.stdout.write(f'\nCapture round {capture_index+1}/{num_captures}')
            
            for camera in cameras:
                # Select a random test image
                image_path = random.choice(test_images)
                
                # Update camera status
                camera.status = CameraStatus.ONLINE
                camera.last_capture_time = datetime.now()
                camera.save()
                
                self.stdout.write(f'Camera {camera.name} capturing from {image_path}')
                
                # Process the image with animation if requested
                if animate:
                    progress = LicensePlateProgressIndicator(total_steps=5)
                    progress.next_step(display=False, save=True)
                    time.sleep(0.5)
                
                # Create a capture
                capture = CameraCapture(camera=camera)
                
                # Save the image
                with open(image_path, 'rb') as f:
                    capture.image.save(
                        f'{camera.camera_id}_{int(time.time())}.jpg',
                        ContentFile(f.read())
                    )
                
                if animate:
                    progress.next_step(display=False, save=True)
                    time.sleep(0.5)
                
                # Run OCR
                start_time = time.time()
                result = ocr_license_plate(image_path)
                detection_time = time.time() - start_time
                
                if animate:
                    progress.next_step(display=False, save=True)
                    time.sleep(0.5)
                
                # Update the capture with results
                capture.processed = True
                capture.detection_time = detection_time
                
                if result['success']:
                    capture.plate_detected = True
                    capture.detected_plate_text = result.get('processed_text', '')
                    capture.confidence = result.get('confidence', 0.0)
                
                capture.save()
                
                if animate:
                    progress.complete(display=False, save=True)
                
                self.stdout.write(self.style.SUCCESS(
                    f'Camera {camera.name} captured image: {capture.image.name}\n'
                    f'Plate detected: {capture.plate_detected}\n'
                    f'Plate text: {capture.detected_plate_text}\n'
                    f'Confidence: {capture.confidence:.2f}\n'
                    f'Detection time: {capture.detection_time:.3f}s'
                ))
            
            # Wait for the next capture round
            if capture_index < num_captures - 1:
                self.stdout.write(f'Waiting {interval} seconds for next capture...')
                time.sleep(interval)