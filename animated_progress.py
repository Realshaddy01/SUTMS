"""
Animated progress indicator for license plate recognition.
Provides visual feedback during the OCR process.
"""
import cv2
import numpy as np
import time
import os
import sys
from tqdm import tqdm

class LicensePlateProgressIndicator:
    """
    Class to create and display an animated progress indicator
    for license plate recognition process.
    """
    def __init__(self, total_steps=5, width=600, height=300, save_dir='.'):
        """
        Initialize the progress indicator.
        
        Args:
            total_steps: Total number of steps in the recognition process
            width: Width of the progress animation
            height: Height of the progress animation
            save_dir: Directory to save animation frames
        """
        self.total_steps = total_steps
        self.width = width
        self.height = height
        self.current_step = 0
        self.save_dir = save_dir
        self.progress_frames = []
        self.step_descriptions = [
            "Loading image",
            "Detecting plate region",
            "Preprocessing",
            "Performing OCR",
            "Post-processing"
        ]
        
        # Ensure we have descriptions for all steps
        while len(self.step_descriptions) < total_steps:
            self.step_descriptions.append(f"Step {len(self.step_descriptions) + 1}")
            
        # Initialize the base frame
        self.base_frame = np.ones((height, width, 3), dtype=np.uint8) * 255
        
        # Define colors
        self.bg_color = (255, 255, 255)  # White
        self.text_color = (0, 0, 0)      # Black
        self.progress_color = (0, 120, 215)  # Blue
        self.completed_color = (0, 180, 0)  # Green
        
        # Draw initial frame
        self._draw_frame(0)
    
    def _draw_frame(self, step):
        """Draw a frame of the progress animation at a specific step."""
        # Create a copy of the base frame
        frame = self.base_frame.copy()
        
        # Calculate progress metrics
        progress_percent = (step / self.total_steps) * 100
        
        # Draw title
        cv2.putText(
            frame,
            "License Plate Recognition",
            (int(self.width * 0.1), int(self.height * 0.15)),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.8,
            self.text_color,
            2,
            cv2.LINE_AA
        )
        
        # Draw progress bar background
        cv2.rectangle(
            frame,
            (int(self.width * 0.1), int(self.height * 0.25)),
            (int(self.width * 0.9), int(self.height * 0.35)),
            (220, 220, 220),
            -1
        )
        
        # Draw progress bar fill
        progress_width = int((self.width * 0.8) * (step / self.total_steps))
        cv2.rectangle(
            frame,
            (int(self.width * 0.1), int(self.height * 0.25)),
            (int(self.width * 0.1) + progress_width, int(self.height * 0.35)),
            self.progress_color if step < self.total_steps else self.completed_color,
            -1
        )
        
        # Draw progress percentage
        cv2.putText(
            frame,
            f"{progress_percent:.1f}%",
            (int(self.width * 0.1), int(self.height * 0.45)),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.7,
            self.text_color,
            2,
            cv2.LINE_AA
        )
        
        # Draw current step information
        current_step_text = f"Current step: {self.step_descriptions[min(step, self.total_steps - 1)]}"
        cv2.putText(
            frame,
            current_step_text,
            (int(self.width * 0.1), int(self.height * 0.6)),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.7,
            self.text_color,
            2,
            cv2.LINE_AA
        )
        
        # Draw step markers
        for i in range(self.total_steps):
            # Calculate position
            x_pos = int(self.width * 0.1) + int((self.width * 0.8) * (i / (self.total_steps - 1)))
            y_pos = int(self.height * 0.25) - 10
            
            # Determine marker color
            marker_color = self.completed_color if i < step else (
                self.progress_color if i == step else (200, 200, 200)
            )
            
            # Draw marker
            cv2.circle(frame, (x_pos, y_pos), 10, marker_color, -1)
            
            # Draw step number
            cv2.putText(
                frame,
                str(i + 1),
                (x_pos - 5, y_pos + 5),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.5,
                (255, 255, 255),
                1,
                cv2.LINE_AA
            )
        
        # Draw status message
        if step < self.total_steps:
            status_message = "Processing..."
        else:
            status_message = "Completed!"
            
        cv2.putText(
            frame,
            status_message,
            (int(self.width * 0.1), int(self.height * 0.75)),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.8,
            self.completed_color if step == self.total_steps else self.progress_color,
            2,
            cv2.LINE_AA
        )
        
        return frame
    
    def next_step(self, display=False, save=True):
        """
        Advance to the next step in the recognition process.
        
        Args:
            display: Whether to display the frame (only works in GUI environment)
            save: Whether to save the frame
            
        Returns:
            The path to the saved frame, if saved
        """
        if self.current_step < self.total_steps:
            self.current_step += 1
            
        frame = self._draw_frame(self.current_step)
        
        # Only try to display if explicitly requested and not in a headless environment
        if display:
            try:
                cv2.imshow("License Plate Recognition Progress", frame)
                cv2.waitKey(1)
            except Exception as e:
                print(f"Warning: Unable to display frame: {str(e)}")
        
        frame_path = None
        if save:
            os.makedirs(self.save_dir, exist_ok=True)
            frame_path = os.path.join(self.save_dir, f"progress_{self.current_step}.png")
            cv2.imwrite(frame_path, frame)
            self.progress_frames.append(frame_path)
            
        return frame_path
    
    def complete(self, display=False, save=True):
        """
        Mark the recognition process as complete.
        
        Args:
            display: Whether to display the frame (only works in GUI environment)
            save: Whether to save the frame
            
        Returns:
            The path to the saved frame, if saved
        """
        self.current_step = self.total_steps
        frame = self._draw_frame(self.current_step)
        
        # Only try to display if explicitly requested and not in a headless environment
        if display:
            try:
                cv2.imshow("License Plate Recognition Progress", frame)
                cv2.waitKey(1)
            except Exception as e:
                print(f"Warning: Unable to display frame: {str(e)}")
        
        frame_path = None
        if save:
            os.makedirs(self.save_dir, exist_ok=True)
            frame_path = os.path.join(self.save_dir, "progress_complete.png")
            cv2.imwrite(frame_path, frame)
            self.progress_frames.append(frame_path)
            
        return frame_path
    
    def create_animation(self, output_path="license_plate_recognition.gif", duration=1.0):
        """
        Create an animated GIF from the progress frames.
        
        Args:
            output_path: Path to save the animated GIF
            duration: Duration of each frame in seconds
            
        Returns:
            Path to the animated GIF
        """
        try:
            import imageio
            with imageio.get_writer(output_path, mode='I', duration=duration) as writer:
                for frame_path in self.progress_frames:
                    image = imageio.imread(frame_path)
                    writer.append_data(image)
            
            print(f"Created animation at {output_path}")
            return output_path
        except ImportError:
            print("Warning: imageio not installed. Cannot create animation.")
            return None
    
    def simulate_process(self, sleep_time=1.0, create_animation=True):
        """
        Simulate the recognition process for demonstration purposes.
        
        Args:
            sleep_time: Time to sleep between steps in seconds
            create_animation: Whether to create an animated GIF
            
        Returns:
            Path to the animated GIF, if created
        """
        print("Simulating license plate recognition process:")
        
        # Reset to beginning
        self.current_step = 0
        self.progress_frames = []
        
        # Go through each step
        for i in range(self.total_steps):
            print(f"Step {i+1}/{self.total_steps}: {self.step_descriptions[i]}")
            self.next_step(display=False, save=True)
            time.sleep(sleep_time)
            
        self.complete(display=False, save=True)
        print("Recognition process completed!")
        
        # Create animation if requested
        if create_animation:
            return self.create_animation()
        
        return None

# Example usage
def main():
    """Demo function to show the progress indicator."""
    print("Demonstrating license plate recognition progress indicator")
    
    # Create the progress indicator
    progress = LicensePlateProgressIndicator()
    
    # Simulate the recognition process
    animation_path = progress.simulate_process(sleep_time=0.5)
    
    print(f"Animation saved to: {animation_path}")
    
    # Only try to wait for keypress in GUI environment
    try:
        print("Press any key to exit")
        cv2.waitKey(0)
        cv2.destroyAllWindows()
    except:
        print("Running in headless mode, exiting automatically")

if __name__ == "__main__":
    main()