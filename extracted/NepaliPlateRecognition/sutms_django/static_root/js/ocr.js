/**
 * OCR Module JavaScript
 */

document.addEventListener('DOMContentLoaded', function() {
    // Initialize file input preview
    const imageInput = document.getElementById('imageInput');
    if (imageInput) {
        imageInput.addEventListener('change', function(e) {
            const file = e.target.files[0];
            if (file) {
                const reader = new FileReader();
                reader.onload = function(e) {
                    const imagePreview = document.getElementById('imagePreview');
                    if (imagePreview) {
                        imagePreview.src = e.target.result;
                        imagePreview.parentElement.classList.remove('d-none');
                    }
                };
                reader.readAsDataURL(file);
            }
        });
    }
    
    // Initialize confidence meter
    const confidenceElement = document.getElementById('confidence');
    if (confidenceElement) {
        const value = parseFloat(confidenceElement.innerText);
        const confidenceLevel = document.querySelector('.confidence-level');
        if (confidenceLevel) {
            confidenceLevel.style.width = value + '%';
            
            // Set color based on confidence level
            if (value < 30) {
                confidenceLevel.classList.add('bg-danger');
            } else if (value < 70) {
                confidenceLevel.classList.add('bg-warning');
            } else {
                confidenceLevel.classList.add('bg-success');
            }
        }
    }
    
    // Handle image upload form submission
    const plateDetectionForm = document.getElementById('plateDetectionForm');
    if (plateDetectionForm) {
        plateDetectionForm.addEventListener('submit', function(e) {
            // Form submission is handled by the inline script
            // This is just for additional functionality
            
            // Disable submit button
            const submitButton = plateDetectionForm.querySelector('button[type="submit"]');
            if (submitButton) {
                submitButton.disabled = true;
                submitButton.innerHTML = '<span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span> Processing...';
            }
        });
    }
    
    // Handle corrected text form
    const correctionForm = document.getElementById('correctionForm');
    if (correctionForm) {
        correctionForm.addEventListener('submit', function(e) {
            e.preventDefault();
            // Submission is handled by the inline script
        });
        
        // Auto format license plate input
        const correctedText = document.getElementById('correctedText');
        if (correctedText) {
            correctedText.addEventListener('input', function() {
                this.value = this.value.toUpperCase();
            });
        }
    }
    
    // Image zooming functionality
    const plateImage = document.getElementById('plateImage');
    if (plateImage) {
        plateImage.addEventListener('click', function() {
            // Create modal with larger image
            const modal = document.createElement('div');
            modal.classList.add('modal', 'fade');
            modal.setAttribute('tabindex', '-1');
            modal.innerHTML = `
                <div class="modal-dialog modal-lg">
                    <div class="modal-content">
                        <div class="modal-header">
                            <h5 class="modal-title">License Plate Image</h5>
                            <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                        </div>
                        <div class="modal-body text-center">
                            <img src="${plateImage.src}" class="img-fluid" alt="License plate">
                        </div>
                    </div>
                </div>
            `;
            document.body.appendChild(modal);
            
            // Show modal
            const modalInstance = new bootstrap.Modal(modal);
            modalInstance.show();
            
            // Remove from DOM when hidden
            modal.addEventListener('hidden.bs.modal', function() {
                document.body.removeChild(modal);
            });
        });
    }
    
    // Helper functions
    window.updatePlateText = function(text) {
        const plateText = document.getElementById('plateText');
        if (plateText) {
            plateText.innerText = text;
        }
    };
    
    window.searchVehicle = function(licensePlate) {
        fetch(`/api/v1/vehicles/search/?license_plate=${encodeURIComponent(licensePlate)}`)
            .then(response => response.json())
            .then(data => {
                const vehicleInfo = document.getElementById('vehicleInfo');
                const noVehicleInfo = document.getElementById('noVehicleInfo');
                
                if (data.count > 0) {
                    // Vehicle found
                    const vehicle = data.results[0];
                    
                    // Update vehicle info
                    const vehicleOwner = document.getElementById('vehicleOwner');
                    const vehicleId = document.getElementById('vehicleId');
                    const vehicleDetailsLink = document.getElementById('vehicleDetailsLink');
                    
                    if (vehicleOwner) vehicleOwner.innerText = vehicle.owner.name;
                    if (vehicleId) vehicleId.innerText = vehicle.id;
                    if (vehicleDetailsLink) vehicleDetailsLink.href = `/vehicles/${vehicle.id}/`;
                    
                    // Show vehicle info
                    if (vehicleInfo) vehicleInfo.classList.remove('d-none');
                    if (noVehicleInfo) noVehicleInfo.classList.add('d-none');
                } else {
                    // No vehicle found
                    if (vehicleInfo) vehicleInfo.classList.add('d-none');
                    if (noVehicleInfo) noVehicleInfo.classList.remove('d-none');
                }
            })
            .catch(error => {
                console.error('Error searching for vehicle:', error);
                // Show error
                const errorInfo = document.getElementById('errorInfo');
                const errorMessage = document.getElementById('errorMessage');
                
                if (errorInfo) errorInfo.classList.remove('d-none');
                if (errorMessage) errorMessage.innerText = 'Error searching for vehicle: ' + error.message;
            });
    };
});