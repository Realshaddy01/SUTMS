"""
Views for the tracking app.
"""
import json
import logging
from datetime import timedelta

from django.shortcuts import render, get_object_or_404, redirect
from django.http import JsonResponse, HttpResponse
from django.contrib.auth.decorators import login_required
from django.views.decorators.http import require_POST, require_http_methods
from django.utils import timezone
from django.contrib import messages
from django.core.paginator import Paginator
from django.db.models import Count, Q

from .models import OfficerLocation, TrafficSignal, Incident

logger = logging.getLogger('sutms.tracking')


@login_required
def tracking_dashboard(request):
    """
    Dashboard view for tracking.
    Shows map with officer locations, incidents, and signals.
    """
    # Check user permissions
    user = request.user
    
    # Only officers and admins can access tracking
    if not (user.is_officer or user.is_admin):
        messages.error(request, 'You do not have permission to access tracking.')
        return redirect('dashboard:index')
    
    # Get active officer locations
    active_locations = OfficerLocation.objects.filter(
        last_updated__gte=timezone.now() - timedelta(hours=1)
    ).select_related('officer')
    
    # Get active incidents
    active_incidents = Incident.objects.exclude(
        status__in=[Incident.Status.RESOLVED, Incident.Status.CANCELLED]
    ).select_related('reported_by').order_by('-reported_at')
    
    # Get signals
    signals = TrafficSignal.objects.all().select_related('updated_by')
    
    # Group signals by status
    signal_stats = {
        'total': signals.count(),
        'operational': signals.filter(status=TrafficSignal.Status.OPERATIONAL).count(),
        'maintenance': signals.filter(status=TrafficSignal.Status.MAINTENANCE).count(),
        'offline': signals.filter(status=TrafficSignal.Status.OFFLINE).count(),
        'warning': signals.filter(status=TrafficSignal.Status.WARNING).count(),
        'malfunction': signals.filter(status=TrafficSignal.Status.MALFUNCTION).count(),
    }
    
    # Group incidents by status
    incident_stats = {
        'total': Incident.objects.count(),
        'active': active_incidents.count(),
        'reported': active_incidents.filter(status=Incident.Status.REPORTED).count(),
        'responding': active_incidents.filter(status=Incident.Status.RESPONDING).count(),
        'in_progress': active_incidents.filter(status=Incident.Status.IN_PROGRESS).count(),
        'resolved': Incident.objects.filter(status=Incident.Status.RESOLVED).count(),
    }
    
    context = {
        'active_locations': active_locations,
        'active_incidents': active_incidents[:10],  # Limit to 10 most recent
        'signals': signals,
        'signal_stats': signal_stats,
        'incident_stats': incident_stats,
    }
    
    return render(request, 'tracking/dashboard.html', context)


@login_required
def incident_list(request):
    """
    List view for incidents.
    Shows list of incidents with filtering and pagination.
    """
    # Check user permissions
    user = request.user
    
    # Only officers and admins can access tracking
    if not (user.is_officer or user.is_admin):
        messages.error(request, 'You do not have permission to access incident list.')
        return redirect('dashboard:index')
    
    # Get filter parameters
    status = request.GET.get('status')
    incident_type = request.GET.get('type')
    severity = request.GET.get('severity')
    date_range = request.GET.get('date_range', 'all')
    
    # Start with all incidents
    incidents = Incident.objects.all().select_related('reported_by', 'updated_by')
    
    # Apply filters
    if status and status in dict(Incident.Status.choices):
        incidents = incidents.filter(status=status)
    
    if incident_type and incident_type in dict(Incident.IncidentType.choices):
        incidents = incidents.filter(incident_type=incident_type)
    
    if severity and severity in dict(Incident.Severity.choices):
        incidents = incidents.filter(severity=severity)
    
    # Apply date filter
    if date_range == 'today':
        today = timezone.now().date()
        incidents = incidents.filter(reported_at__date=today)
    elif date_range == 'week':
        week_ago = timezone.now() - timedelta(days=7)
        incidents = incidents.filter(reported_at__gte=week_ago)
    elif date_range == 'month':
        month_ago = timezone.now() - timedelta(days=30)
        incidents = incidents.filter(reported_at__gte=month_ago)
    
    # Order by reported_at (newest first)
    incidents = incidents.order_by('-reported_at')
    
    # Paginate results
    paginator = Paginator(incidents, 20)  # Show 20 incidents per page
    page_number = request.GET.get('page')
    page_obj = paginator.get_page(page_number)
    
    context = {
        'incidents': page_obj,
        'status_choices': Incident.Status.choices,
        'type_choices': Incident.IncidentType.choices,
        'severity_choices': Incident.Severity.choices,
        'date_range_choices': [
            ('all', 'All Time'),
            ('today', 'Today'),
            ('week', 'This Week'),
            ('month', 'This Month'),
        ],
        'selected_status': status,
        'selected_type': incident_type,
        'selected_severity': severity,
        'selected_date_range': date_range,
    }
    
    return render(request, 'tracking/incident_list.html', context)


@login_required
def signal_list(request):
    """
    List view for traffic signals.
    Shows list of signals with filtering and pagination.
    """
    # Check user permissions
    user = request.user
    
    # Only officers and admins can access tracking
    if not (user.is_officer or user.is_admin):
        messages.error(request, 'You do not have permission to access signal list.')
        return redirect('dashboard:index')
    
    # Get filter parameters
    status = request.GET.get('status')
    
    # Start with all signals
    signals = TrafficSignal.objects.all().select_related('updated_by')
    
    # Apply filters
    if status and status in dict(TrafficSignal.Status.choices):
        signals = signals.filter(status=status)
    
    # Order by name
    signals = signals.order_by('name')
    
    # Paginate results
    paginator = Paginator(signals, 20)  # Show 20 signals per page
    page_number = request.GET.get('page')
    page_obj = paginator.get_page(page_number)
    
    context = {
        'signals': page_obj,
        'status_choices': TrafficSignal.Status.choices,
        'selected_status': status,
    }
    
    return render(request, 'tracking/signal_list.html', context)


# API views for tracking

@login_required
@require_http_methods(['GET', 'POST'])
def location_api(request):
    """
    API view for officer locations.
    GET: Returns list of officer locations
    POST: Updates the current officer's location
    """
    # Check user permissions
    user = request.user
    
    if not (user.is_officer or user.is_admin):
        return JsonResponse({'error': 'Permission denied'}, status=403)
    
    if request.method == 'GET':
        # Get all recent officer locations
        locations = OfficerLocation.objects.filter(
            last_updated__gte=timezone.now() - timedelta(hours=1)
        ).select_related('officer')
        
        locations_data = []
        for loc in locations:
            locations_data.append({
                'id': str(loc.id),
                'officer_id': str(loc.officer.id),
                'officer_name': loc.officer.get_full_name() or loc.officer.username,
                'latitude': loc.latitude,
                'longitude': loc.longitude,
                'accuracy': loc.accuracy,
                'speed': loc.speed,
                'heading': loc.heading,
                'battery_level': loc.battery_level,
                'last_updated': loc.last_updated.isoformat(),
            })
        
        return JsonResponse({'locations': locations_data})
    
    elif request.method == 'POST':
        try:
            data = json.loads(request.body)
            
            # Update officer location
            latitude = data.get('latitude')
            longitude = data.get('longitude')
            accuracy = data.get('accuracy', 0)
            speed = data.get('speed', 0)
            heading = data.get('heading', 0)
            battery = data.get('battery', 0)
            
            if not latitude or not longitude:
                return JsonResponse({'error': 'Latitude and longitude are required'}, status=400)
            
            # Get or create OfficerLocation object
            location, created = OfficerLocation.objects.update_or_create(
                officer=user,
                defaults={
                    'latitude': latitude,
                    'longitude': longitude,
                    'accuracy': accuracy,
                    'speed': speed,
                    'heading': heading,
                    'battery_level': battery,
                    'last_updated': timezone.now()
                }
            )
            
            return JsonResponse({
                'success': True,
                'id': str(location.id),
                'created': created,
                'last_updated': location.last_updated.isoformat()
            })
            
        except json.JSONDecodeError:
            return JsonResponse({'error': 'Invalid JSON'}, status=400)
        except Exception as e:
            logger.error(f"Error updating location: {str(e)}")
            return JsonResponse({'error': str(e)}, status=500)


@login_required
@require_http_methods(['GET', 'POST', 'PUT'])
def incident_api(request):
    """
    API view for incidents.
    GET: Returns list of incidents
    POST: Creates a new incident
    PUT: Updates an existing incident
    """
    # Check user permissions
    user = request.user
    
    if not (user.is_officer or user.is_admin):
        return JsonResponse({'error': 'Permission denied'}, status=403)
    
    if request.method == 'GET':
        # Get query parameters
        active_only = request.GET.get('active_only', 'true').lower() == 'true'
        
        # Get incidents
        if active_only:
            incidents = Incident.objects.exclude(
                status__in=[Incident.Status.RESOLVED, Incident.Status.CANCELLED]
            ).select_related('reported_by', 'updated_by')
        else:
            incidents = Incident.objects.all().select_related('reported_by', 'updated_by')
        
        # Order by reported_at (newest first)
        incidents = incidents.order_by('-reported_at')
        
        # Limit to 100 incidents
        incidents = incidents[:100]
        
        incidents_data = []
        for incident in incidents:
            incidents_data.append({
                'id': str(incident.id),
                'incident_type': incident.incident_type,
                'incident_type_display': incident.get_incident_type_display(),
                'description': incident.description,
                'latitude': incident.latitude,
                'longitude': incident.longitude,
                'status': incident.status,
                'status_display': incident.get_status_display(),
                'severity': incident.severity,
                'severity_display': incident.get_severity_display(),
                'reported_by': incident.reported_by.get_full_name() or incident.reported_by.username,
                'reported_at': incident.reported_at.isoformat(),
                'updated_at': incident.updated_at.isoformat() if incident.updated_at else None,
                'resolution': incident.resolution,
            })
        
        return JsonResponse({'incidents': incidents_data})
    
    elif request.method == 'POST':
        try:
            data = json.loads(request.body)
            
            # Create new incident
            incident_type = data.get('incident_type')
            latitude = data.get('latitude')
            longitude = data.get('longitude')
            description = data.get('description', '')
            severity = data.get('severity', Incident.Severity.MEDIUM)
            
            if not incident_type or not latitude or not longitude:
                return JsonResponse({
                    'error': 'Type, latitude, and longitude are required'
                }, status=400)
            
            # Validate incident_type
            if incident_type not in dict(Incident.IncidentType.choices):
                return JsonResponse({'error': 'Invalid incident type'}, status=400)
            
            # Validate severity
            if severity not in dict(Incident.Severity.choices):
                severity = Incident.Severity.MEDIUM
            
            # Create incident
            incident = Incident.objects.create(
                incident_type=incident_type,
                latitude=latitude,
                longitude=longitude,
                description=description,
                severity=severity,
                reported_by=user,
                reported_at=timezone.now(),
                status=Incident.Status.REPORTED
            )
            
            return JsonResponse({
                'success': True,
                'id': str(incident.id),
                'status': incident.status,
                'reported_at': incident.reported_at.isoformat()
            })
            
        except json.JSONDecodeError:
            return JsonResponse({'error': 'Invalid JSON'}, status=400)
        except Exception as e:
            logger.error(f"Error creating incident: {str(e)}")
            return JsonResponse({'error': str(e)}, status=500)
    
    elif request.method == 'PUT':
        try:
            data = json.loads(request.body)
            
            incident_id = data.get('id')
            if not incident_id:
                return JsonResponse({'error': 'Incident ID is required'}, status=400)
            
            # Get incident
            try:
                incident = Incident.objects.get(id=incident_id)
            except Incident.DoesNotExist:
                return JsonResponse({'error': 'Incident not found'}, status=404)
            
            # Update incident
            status = data.get('status')
            resolution = data.get('resolution')
            
            if status and status in dict(Incident.Status.choices):
                incident.status = status
            
            if resolution is not None:
                incident.resolution = resolution
            
            # Update incident
            incident.updated_by = user
            incident.updated_at = timezone.now()
            
            # Set resolved_at if status is resolved
            if incident.status == Incident.Status.RESOLVED and not incident.resolved_at:
                incident.resolved_at = timezone.now()
            
            incident.save()
            
            return JsonResponse({
                'success': True,
                'id': str(incident.id),
                'status': incident.status,
                'updated_at': incident.updated_at.isoformat()
            })
            
        except json.JSONDecodeError:
            return JsonResponse({'error': 'Invalid JSON'}, status=400)
        except Exception as e:
            logger.error(f"Error updating incident: {str(e)}")
            return JsonResponse({'error': str(e)}, status=500)


@login_required
@require_http_methods(['GET', 'PUT'])
def signal_api(request):
    """
    API view for traffic signals.
    GET: Returns list of traffic signals
    PUT: Updates an existing traffic signal
    """
    # Check user permissions
    user = request.user
    
    if not (user.is_officer or user.is_admin):
        return JsonResponse({'error': 'Permission denied'}, status=403)
    
    if request.method == 'GET':
        # Get all signals
        signals = TrafficSignal.objects.all().select_related('updated_by')
        
        # Order by name
        signals = signals.order_by('name')
        
        signals_data = []
        for signal in signals:
            signals_data.append({
                'id': str(signal.id),
                'name': signal.name,
                'code': signal.code,
                'latitude': signal.latitude,
                'longitude': signal.longitude,
                'status': signal.status,
                'status_display': signal.get_status_display(),
                'last_updated': signal.last_updated.isoformat(),
                'updated_by': signal.updated_by.get_full_name() if signal.updated_by else None,
                'notes': signal.notes,
            })
        
        return JsonResponse({'signals': signals_data})
    
    elif request.method == 'PUT':
        try:
            data = json.loads(request.body)
            
            signal_id = data.get('id')
            if not signal_id:
                return JsonResponse({'error': 'Signal ID is required'}, status=400)
            
            # Get signal
            try:
                signal = TrafficSignal.objects.get(id=signal_id)
            except TrafficSignal.DoesNotExist:
                return JsonResponse({'error': 'Signal not found'}, status=404)
            
            # Update signal
            status = data.get('status')
            notes = data.get('notes')
            
            if status and status in dict(TrafficSignal.Status.choices):
                signal.status = status
            
            if notes is not None:
                signal.notes = notes
            
            # Update signal
            signal.updated_by = user
            signal.save()
            
            return JsonResponse({
                'success': True,
                'id': str(signal.id),
                'status': signal.status,
                'last_updated': signal.last_updated.isoformat()
            })
            
        except json.JSONDecodeError:
            return JsonResponse({'error': 'Invalid JSON'}, status=400)
        except Exception as e:
            logger.error(f"Error updating signal: {str(e)}")
            return JsonResponse({'error': str(e)}, status=500)