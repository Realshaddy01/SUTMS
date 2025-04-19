from django.shortcuts import render, get_object_or_404, redirect
from django.http import JsonResponse, HttpResponse
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from django.views.decorators.http import require_POST
from django.urls import reverse
from django.utils import timezone
from .models import Vehicle, VehicleDocument, VehicleType
from violations.models import Violation

# Create your views here.
@login_required
def vehicle_list(request):
    """List all vehicles for the logged-in user."""
    if request.user.is_vehicle_owner():
        # For vehicle owners, show only their vehicles
        try:
            vehicle_owner = request.user.vehicle_owner
            vehicles = Vehicle.objects.filter(owner=vehicle_owner)
        except Exception as e:
            messages.error(request, f"Error retrieving vehicles: {str(e)}")
            vehicles = Vehicle.objects.none()
    else:
        # For officers and admins, show all vehicles
        vehicles = Vehicle.objects.all()
    
    return render(request, 'vehicles/list.html', {'vehicles': vehicles})

@login_required
def add_vehicle(request):
    """Add a new vehicle."""
    # Check if user is a vehicle owner
    if not request.user.is_vehicle_owner():
        messages.error(request, "Only vehicle owners can add vehicles.")
        return redirect('dashboard:index')
    
    # Get all vehicle types
    vehicle_types = VehicleType.objects.filter(is_active=True)
    
    if request.method == 'POST':
        # Get form data
        license_plate = request.POST.get('license_plate')
        nickname = request.POST.get('nickname', '')
        vehicle_type_id = request.POST.get('vehicle_type')
        make = request.POST.get('make')
        model = request.POST.get('model')
        year = request.POST.get('year')
        color = request.POST.get('color')
        registration_number = request.POST.get('registration_number', '')
        registration_expiry = request.POST.get('registration_expiry', None)
        vin = request.POST.get('vin', '')
        is_insured = request.POST.get('is_insured') == 'on'
        insurance_provider = request.POST.get('insurance_provider', '')
        insurance_policy_number = request.POST.get('insurance_policy_number', '')
        insurance_expiry = request.POST.get('insurance_expiry', None)
        
        # Basic validation
        if not all([license_plate, vehicle_type_id, make, model, year, color]):
            messages.error(request, "Please fill in all required fields.")
            return render(request, 'vehicles/add.html', {'vehicle_types': vehicle_types})
        
        # Create new vehicle
        try:
            vehicle_type = VehicleType.objects.get(id=vehicle_type_id)
            
            vehicle = Vehicle.objects.create(
                license_plate=license_plate,
                nickname=nickname,
                vehicle_type=vehicle_type,
                owner=request.user,
                make=make,
                model=model,
                year=year,
                color=color,
                registration_number=registration_number,
                vin=vin,
                is_insured=is_insured,
                insurance_provider=insurance_provider,
                insurance_policy_number=insurance_policy_number
            )
            
            # Set dates if provided
            if registration_expiry:
                vehicle.registration_expiry = registration_expiry
            if insurance_expiry and is_insured:
                vehicle.insurance_expiry = insurance_expiry
            
            vehicle.save()
            
            # Generate QR code
            vehicle.generate_qr_code()
            
            messages.success(request, f"Vehicle {vehicle.license_plate} added successfully.")
            return redirect('vehicles:detail', vehicle_id=vehicle.id)
            
        except Exception as e:
            messages.error(request, f"Error adding vehicle: {str(e)}")
            return render(request, 'vehicles/add.html', {'vehicle_types': vehicle_types})
    
    return render(request, 'vehicles/add.html', {'vehicle_types': vehicle_types})

@login_required
def vehicle_detail(request, vehicle_id):
    """View vehicle details."""
    vehicle = get_object_or_404(Vehicle, id=vehicle_id)
    
    # Check permissions
    if request.user.is_vehicle_owner() and vehicle.owner != request.user:
        messages.error(request, "You don't have permission to view this vehicle.")
        return redirect('dashboard:index')
    
    # Get vehicle documents
    documents = VehicleDocument.objects.filter(vehicle=vehicle)
    
    # Get vehicle violations
    violations = Violation.objects.filter(vehicle=vehicle).order_by('-created_at')
    
    # Generate QR code if it doesn't exist
    if not vehicle.qr_code:
        vehicle.generate_qr_code()
    
    context = {
        'vehicle': vehicle,
        'documents': documents,
        'violations': violations,
        'now': timezone.now(),
    }
    
    return render(request, 'vehicles/detail.html', context)

@login_required
def edit_vehicle(request, vehicle_id):
    """Edit vehicle details."""
    vehicle = get_object_or_404(Vehicle, id=vehicle_id)
    
    # Check permissions
    if request.user.is_vehicle_owner() and vehicle.owner != request.user:
        messages.error(request, "You don't have permission to edit this vehicle.")
        return redirect('dashboard:index')
    
    # Real implementation to be completed
    return render(request, 'vehicles/edit.html', {'vehicle': vehicle})

@login_required
def vehicle_documents(request, vehicle_id):
    """View vehicle documents."""
    vehicle = get_object_or_404(Vehicle, id=vehicle_id)
    
    # Check permissions
    if request.user.is_vehicle_owner() and vehicle.owner != request.user:
        messages.error(request, "You don't have permission to view this vehicle's documents.")
        return redirect('dashboard:index')
    
    documents = VehicleDocument.objects.filter(vehicle=vehicle)
    
    return render(request, 'vehicles/documents.html', {
        'vehicle': vehicle, 
        'documents': documents
    })

@login_required
def add_document(request, vehicle_id):
    """Add a document to a vehicle."""
    vehicle = get_object_or_404(Vehicle, id=vehicle_id)
    
    # Check permissions
    if request.user.is_vehicle_owner() and vehicle.owner != request.user:
        messages.error(request, "You don't have permission to add documents to this vehicle.")
        return redirect('dashboard:index')
    
    return render(request, 'vehicles/add_document.html', {'vehicle': vehicle})

@login_required
def search_vehicle(request):
    """Search for vehicles by license plate."""
    license_plate = request.GET.get('license_plate', '')
    
    if license_plate:
        vehicles = Vehicle.objects.filter(license_plate__icontains=license_plate)
        if request.user.is_vehicle_owner():
            # Vehicle owners can only search their own vehicles
            vehicles = vehicles.filter(owner=request.user)
    else:
        vehicles = []
        
    return JsonResponse({'vehicles': list(vehicles.values('id', 'license_plate', 'make', 'model', 'year', 'color'))})

@login_required
def vehicle_qr_code(request, vehicle_id):
    """Generate and display QR code for a vehicle."""
    vehicle = get_object_or_404(Vehicle, id=vehicle_id)
    
    # Check permissions
    if request.user.is_vehicle_owner() and vehicle.owner != request.user:
        messages.error(request, "You don't have permission to view this vehicle's QR code.")
        return redirect('dashboard:index')
    
    # Generate QR code if it doesn't exist
    if not vehicle.qr_code:
        vehicle.generate_qr_code()
    
    return render(request, 'vehicles/qr_code.html', {'vehicle': vehicle})

@login_required
def generate_qr_code(request, vehicle_id):
    """Generate QR code for a vehicle and return it as an image."""
    vehicle = get_object_or_404(Vehicle, id=vehicle_id)
    
    # Check permissions
    if request.user.is_vehicle_owner() and vehicle.owner != request.user:
        return JsonResponse({'error': 'Permission denied'}, status=403)
    
    # Generate QR code
    vehicle.generate_qr_code()
    
    # Return success message
    return JsonResponse({
        'success': True, 
        'qr_code_url': vehicle.qr_code.url if vehicle.qr_code else None
    })

@login_required
def scan_qr(request):
    """Scan QR code to retrieve vehicle information."""
    if not request.user.is_officer() and not request.user.is_admin():
        messages.error(request, "Only officers can scan QR codes.")
        return redirect('dashboard:index')
    
    return render(request, 'vehicles/scan_qr.html')

@login_required
def verify_qr_code(request, code):
    """Verify a QR code for a vehicle."""
    if not request.user.is_officer() and not request.user.is_admin():
        return JsonResponse({'error': 'Only officers can verify QR codes'}, status=403)
    
    if not code or not code.startswith('SUTMS:'):
        return JsonResponse({'verified': False, 'message': 'Invalid QR code format'})
    
    try:
        # Parse the QR code data
        parts = code.split(':')
        if len(parts) != 3:
            return JsonResponse({'verified': False, 'message': 'Invalid QR code format'})
        
        _, license_plate, vehicle_id = parts
        
        # Retrieve the vehicle
        try:
            vehicle = Vehicle.objects.get(id=vehicle_id, license_plate=license_plate)
        except Vehicle.DoesNotExist:
            return JsonResponse({'verified': False, 'message': 'Vehicle not found'})
        
        # Get vehicle violations
        violations = Violation.objects.filter(vehicle=vehicle).order_by('-created_at')
        recent_violations = [
            {
                'id': v.id,
                'type': v.violation_type.name if v.violation_type else 'Unknown',
                'date': v.timestamp.strftime('%Y-%m-%d') if v.timestamp else 'Unknown',
                'status': v.status,
                'fine_amount': v.fine_amount
            }
            for v in violations[:5]
        ]
        
        # Check if the vehicle is valid (registration and insurance not expired)
        is_valid = not (vehicle.is_registration_expired or vehicle.is_insurance_expired)
        
        return JsonResponse({
            'verified': True,
            'vehicle': {
                'id': vehicle.id,
                'license_plate': vehicle.license_plate,
                'make': vehicle.make,
                'model': vehicle.model,
                'year': vehicle.year,
                'color': vehicle.color,
                'vehicle_type': vehicle.vehicle_type.name if vehicle.vehicle_type else 'Unknown',
                'registration_number': vehicle.registration_number,
                'is_registration_expired': vehicle.is_registration_expired,
                'registration_expiry': vehicle.registration_expiry.strftime('%Y-%m-%d') if vehicle.registration_expiry else None,
                'is_insurance_expired': vehicle.is_insurance_expired,
                'insurance_expiry': vehicle.insurance_expiry.strftime('%Y-%m-%d') if vehicle.insurance_expiry else None,
            },
            'owner': {
                'name': vehicle.owner.get_full_name() if vehicle.owner else 'Unknown',
                'phone': vehicle.owner.phone_number if vehicle.owner else None,
                'email': vehicle.owner.email if vehicle.owner else None,
            },
            'violations': {
                'total': violations.count(),
                'recent': recent_violations,
                'has_unpaid': violations.filter(status='issued').exists()
            },
            'is_valid': is_valid,
            'message': 'Vehicle verified successfully'
        })
    except Exception as e:
        return JsonResponse({'verified': False, 'message': f'Error verifying QR code: {str(e)}'})

def verify_qr(request):
    """Verify a QR code for a vehicle."""
    # For backwards compatibility
    return JsonResponse({'verified': False, 'message': 'Please use the new QR verification endpoint'})
