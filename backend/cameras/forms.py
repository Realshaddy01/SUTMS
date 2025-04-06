"""
Forms for the cameras app.
"""

from django import forms
from .models import TrafficCamera, CameraCapture

class TrafficCameraForm(forms.ModelForm):
    """Form for TrafficCamera model."""
    
    class Meta:
        model = TrafficCamera
        fields = ['camera_id', 'name', 'location', 'description', 'is_active', 'coordinates_lat', 'coordinates_lng']
        widgets = {
            'description': forms.Textarea(attrs={'rows': 3}),
        }
    
    def __init__(self, *args, **kwargs):
        """Initialize the form with Bootstrap classes."""
        super().__init__(*args, **kwargs)
        for field_name, field in self.fields.items():
            field.widget.attrs['class'] = 'form-control'