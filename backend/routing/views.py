"""
Views for the route recommendation system.
"""
import json
import logging
from datetime import timedelta
import numpy as np

from django.shortcuts import render, redirect
from django.http import JsonResponse
from django.contrib.auth.decorators import login_required
from django.views.decorators.http import require_http_methods
from django.utils import timezone
from django.contrib import messages
from django.core.paginator import Paginator
from django.db.models import Avg, Count, Max, Min

from .models import TrafficData, RouteRecommendation, PeakTrafficTime
from .utils import (
    get_directions, analyze_traffic_on_route, predict_traffic_level,
    get_alternative_routes, is_peak_traffic_time, train_traffic_model
)

logger = logging.getLogger('sutms.routing')


@login_required
def route_dashboard(request):
    """
    Dashboard view for route recommendations.
    """
    # Get user's recent route recommendations
    user_routes = RouteRecommendation.objects.filter(
        user=request.user
    ).order_by('-created_at')[:10]
    
    # Get general traffic statistics
    today = timezone.now().date()
    
    # Average traffic level today
    avg_traffic_today = TrafficData.objects.filter(
        timestamp__date=today
    ).aggregate(avg_traffic=Avg('traffic_level'))['avg_traffic'] or 0
    
    # Peak traffic areas
    peak_areas = PeakTrafficTime.objects.all()
    
    # Current peak areas
    current_peak_areas = [area for area in peak_areas if area.is_current]
    
    # Weekly traffic pattern (average by day and hour)
    traffic_by_hour = TrafficData.objects.values('day_of_week', 'hour_of_day').annotate(
        avg_traffic=Avg('traffic_level'),
        count=Count('id')
    ).order_by('day_of_week', 'hour_of_day')
    
    # Format data for charting
    days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
    hours = list(range(24))
    
    # Initialize the chart data structure
    traffic_chart_data = {day: [0] * 24 for day in days}
    
    # Fill in the data
    for entry in traffic_by_hour:
        day = days[entry['day_of_week']]
        hour = entry['hour_of_day']
        traffic_chart_data[day][hour] = round(entry['avg_traffic'])
    
    context = {
        'user_routes': user_routes,
        'avg_traffic_today': round(avg_traffic_today),
        'peak_areas': peak_areas,
        'current_peak_areas': current_peak_areas,
        'traffic_chart_data': json.dumps(traffic_chart_data),
        'days': days,
        'hours': hours,
    }
    
    return render(request, 'routing/dashboard.html', context)


@login_required
def route_planner(request):
    """
    View for planning routes with alternate recommendations.
    """
    context = {
        'google_maps_api_key': request.META.get('GOOGLE_MAPS_API_KEY', ''),
    }
    
    return render(request, 'routing/planner.html', context)


@login_required
def traffic_analytics(request):
    """
    View for traffic analytics.
    """
    # Get filter parameters
    days_ago = int(request.GET.get('days_ago', 7))
    day_of_week = request.GET.get('day_of_week')
    hour_start = request.GET.get('hour_start')
    hour_end = request.GET.get('hour_end')
    
    # Base queryset
    start_date = timezone.now() - timedelta(days=days_ago)
    queryset = TrafficData.objects.filter(timestamp__gte=start_date)
    
    # Apply filters
    if day_of_week and day_of_week.isdigit():
        queryset = queryset.filter(day_of_week=int(day_of_week))
    
    if hour_start and hour_start.isdigit():
        queryset = queryset.filter(hour_of_day__gte=int(hour_start))
    
    if hour_end and hour_end.isdigit():
        queryset = queryset.filter(hour_of_day__lt=int(hour_end))
    
    # Aggregate statistics
    stats = queryset.aggregate(
        avg_traffic=Avg('traffic_level'),
        max_traffic=Max('traffic_level'),
        min_traffic=Min('traffic_level'),
        avg_travel_time=Avg('travel_time_seconds'),
        avg_distance=Avg('distance_meters'),
        count=Count('id')
    )
    
    # Traffic by hour of day
    traffic_by_hour = queryset.values('hour_of_day').annotate(
        avg_traffic=Avg('traffic_level'),
        count=Count('id')
    ).order_by('hour_of_day')
    
    # Traffic by day of week
    traffic_by_day = queryset.values('day_of_week').annotate(
        avg_traffic=Avg('traffic_level'),
        count=Count('id')
    ).order_by('day_of_week')
    
    # Format data for charting
    hours = list(range(24))
    days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
    
    # Initialize with zeros
    traffic_hour_data = [0] * 24
    for entry in traffic_by_hour:
        hour = entry['hour_of_day']
        if 0 <= hour < 24:
            traffic_hour_data[hour] = round(entry['avg_traffic'])
    
    traffic_day_data = [0] * 7
    for entry in traffic_by_day:
        day = entry['day_of_week']
        if 0 <= day < 7:
            traffic_day_data[day] = round(entry['avg_traffic'])
    
    context = {
        'stats': stats,
        'days_ago': days_ago,
        'day_of_week': day_of_week,
        'hour_start': hour_start,
        'hour_end': hour_end,
        'traffic_hour_data': json.dumps(traffic_hour_data),
        'traffic_day_data': json.dumps(traffic_day_data),
        'hours': hours,
        'days': days,
    }
    
    return render(request, 'routing/analytics.html', context)


@login_required
def peak_traffic_management(request):
    """
    View for managing peak traffic time definitions.
    """
    if request.method == 'POST':
        # Handle create/update
        peak_id = request.POST.get('peak_id')
        area_name = request.POST.get('area_name')
        center_lat = float(request.POST.get('center_lat', 0))
        center_lng = float(request.POST.get('center_lng', 0))
        radius_meters = int(request.POST.get('radius_meters', 1000))
        day_of_week = int(request.POST.get('day_of_week', 0))
        start_hour = int(request.POST.get('start_hour', 0))
        end_hour = int(request.POST.get('end_hour', 0))
        traffic_level = int(request.POST.get('traffic_level', 50))
        
        if peak_id:
            # Update existing
            try:
                peak = PeakTrafficTime.objects.get(id=peak_id)
                peak.area_name = area_name
                peak.center_lat = center_lat
                peak.center_lng = center_lng
                peak.radius_meters = radius_meters
                peak.day_of_week = day_of_week
                peak.start_hour = start_hour
                peak.end_hour = end_hour
                peak.traffic_level = traffic_level
                peak.save()
                messages.success(request, f'Peak traffic time for {area_name} updated.')
            except PeakTrafficTime.DoesNotExist:
                messages.error(request, 'Peak traffic time not found.')
        else:
            # Create new
            PeakTrafficTime.objects.create(
                area_name=area_name,
                center_lat=center_lat,
                center_lng=center_lng,
                radius_meters=radius_meters,
                day_of_week=day_of_week,
                start_hour=start_hour,
                end_hour=end_hour,
                traffic_level=traffic_level
            )
            messages.success(request, f'Peak traffic time for {area_name} created.')
            
        return redirect('routing:peak_traffic_management')
    
    # GET request - show all peak traffic times
    peak_times = PeakTrafficTime.objects.all().order_by('area_name', 'day_of_week', 'start_hour')
    
    context = {
        'peak_times': peak_times,
        'google_maps_api_key': request.META.get('GOOGLE_MAPS_API_KEY', ''),
        'days': ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'],
        'hours': list(range(24)),
    }
    
    return render(request, 'routing/peak_management.html', context)


@login_required
def delete_peak_traffic(request, peak_id):
    """
    Delete a peak traffic time definition.
    """
    if request.method == 'POST':
        try:
            peak = PeakTrafficTime.objects.get(id=peak_id)
            area_name = peak.area_name
            peak.delete()
            messages.success(request, f'Peak traffic time for {area_name} deleted.')
        except PeakTrafficTime.DoesNotExist:
            messages.error(request, 'Peak traffic time not found.')
    
    return redirect('routing:peak_traffic_management')


@login_required
def route_history(request):
    """
    View for user's route recommendation history.
    """
    routes = RouteRecommendation.objects.filter(
        user=request.user
    ).order_by('-created_at')
    
    # Paginate
    paginator = Paginator(routes, 20)
    page_number = request.GET.get('page')
    page_obj = paginator.get_page(page_number)
    
    context = {
        'routes': page_obj,
    }
    
    return render(request, 'routing/history.html', context)


@login_required
def route_detail(request, route_id):
    """
    View for route recommendation details.
    """
    try:
        route = RouteRecommendation.objects.get(id=route_id, user=request.user)
    except RouteRecommendation.DoesNotExist:
        messages.error(request, 'Route recommendation not found.')
        return redirect('routing:route_history')
    
    context = {
        'route': route,
        'route_data': json.loads(route.route_data) if route.route_data else None,
        'google_maps_api_key': request.META.get('GOOGLE_MAPS_API_KEY', ''),
    }
    
    return render(request, 'routing/detail.html', context)


# API Views

@login_required
@require_http_methods(['GET'])
def route_recommendation_api(request):
    """
    API view for route recommendations.
    GET: Returns route recommendations based on origin and destination
    """
    try:
        # Get parameters
        origin_lat = float(request.GET.get('origin_lat', 0))
        origin_lng = float(request.GET.get('origin_lng', 0))
        destination_lat = float(request.GET.get('destination_lat', 0))
        destination_lng = float(request.GET.get('destination_lng', 0))
        
        if not all([origin_lat, origin_lng, destination_lat, destination_lng]):
            return JsonResponse({
                'error': 'Origin and destination coordinates are required'
            }, status=400)
        
        # Get alternative routes
        routes = get_alternative_routes(
            origin_lat, origin_lng, destination_lat, destination_lng, user=request.user
        )
        
        if not routes:
            return JsonResponse({
                'error': 'Failed to get route recommendations'
            }, status=500)
        
        return JsonResponse(routes)
    
    except Exception as e:
        logger.error(f"Error in route recommendation API: {str(e)}")
        return JsonResponse({'error': str(e)}, status=500)


@login_required
@require_http_methods(['GET'])
def traffic_prediction_api(request):
    """
    API view for traffic predictions.
    GET: Returns traffic predictions for a location and time
    """
    try:
        # Get parameters
        lat = float(request.GET.get('lat', 0))
        lng = float(request.GET.get('lng', 0))
        
        if not all([lat, lng]):
            return JsonResponse({
                'error': 'Latitude and longitude are required'
            }, status=400)
        
        # Check if it's peak traffic time
        is_peak = is_peak_traffic_time(lat, lng)
        
        # Get nearby peak traffic areas
        peak_areas = []
        for peak in PeakTrafficTime.objects.all():
            # Calculate distance using Haversine formula
            R = 6371000  # Earth radius in meters
            dLat = np.radians(lat - peak.center_lat)
            dLon = np.radians(lng - peak.center_lng)
            a = (np.sin(dLat/2) * np.sin(dLat/2) + 
                 np.cos(np.radians(peak.center_lat)) * np.cos(np.radians(lat)) * 
                 np.sin(dLon/2) * np.sin(dLon/2))
            c = 2 * np.arctan2(np.sqrt(a), np.sqrt(1-a))
            distance = R * c
            
            if distance <= peak.radius_meters * 2:  # Within double the radius
                peak_areas.append({
                    'id': str(peak.id),
                    'area_name': peak.area_name,
                    'distance_meters': int(distance),
                    'is_within': distance <= peak.radius_meters,
                    'day_of_week': peak.day_of_week,
                    'start_hour': peak.start_hour,
                    'end_hour': peak.end_hour,
                    'traffic_level': peak.traffic_level,
                    'is_current': peak.is_current,
                })
        
        return JsonResponse({
            'is_peak_traffic_time': is_peak,
            'nearby_peak_areas': peak_areas,
            'current_time': timezone.now().isoformat(),
        })
    
    except Exception as e:
        logger.error(f"Error in traffic prediction API: {str(e)}")
        return JsonResponse({'error': str(e)}, status=500)


@login_required
@require_http_methods(['POST'])
def train_model_api(request):
    """
    API view for training the traffic prediction model.
    POST: Trains the model and returns metadata
    """
    if not request.user.is_admin:
        return JsonResponse({'error': 'Permission denied'}, status=403)
    
    try:
        model = train_traffic_model()
        
        if not model:
            return JsonResponse({
                'error': 'Failed to train model. Not enough data.'
            }, status=400)
        
        return JsonResponse({
            'success': True,
            'message': 'Model trained successfully',
            'feature_importance': model.feature_importances_.tolist(),
            'trained_at': timezone.now().isoformat(),
        })
    
    except Exception as e:
        logger.error(f"Error training model: {str(e)}")
        return JsonResponse({'error': str(e)}, status=500)