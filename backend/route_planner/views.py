"""
Views for the route_planner app.
"""

from django.shortcuts import render, redirect, get_object_or_404
from django.http import JsonResponse, HttpResponse
from django.contrib.auth.decorators import login_required
from django.views.decorators.http import require_POST, require_GET
from django.utils import timezone
from django.db.models import Q

from .models import Location, Route, RouteRecommendation, RecommendedRoute, TrafficJam
from .route_service import RoutePlannerService


@login_required
def index(request):
    """
    Main route planner view for users to plan trips.
    """
    # Get all locations, with popular ones first
    locations = Location.objects.all().order_by('-is_popular', 'name')
    
    # Get user's recent recommendations
    route_planner = RoutePlannerService()
    recent_recommendations = route_planner.get_user_recent_recommendations(request.user)
    
    # Get active traffic jams for warning display
    active_jams = TrafficJam.objects.filter(is_active=True).select_related('location')
    
    context = {
        'locations': locations,
        'recent_recommendations': recent_recommendations,
        'active_jams': active_jams[:5],  # Limit to 5 most recent
    }
    
    return render(request, 'route_planner/index.html', context)


@login_required
@require_POST
def get_route_recommendations(request):
    """
    API endpoint to get route recommendations.
    """
    try:
        origin_id = int(request.POST.get('origin_id'))
        destination_id = int(request.POST.get('destination_id'))
        
        # Optional travel datetime (defaults to current time)
        travel_datetime = request.POST.get('travel_datetime')
        if travel_datetime:
            travel_datetime = timezone.datetime.fromisoformat(travel_datetime)
        else:
            travel_datetime = timezone.now()
        
        # Validate that origin and destination are different
        if origin_id == destination_id:
            return JsonResponse({'error': 'Origin and destination cannot be the same'}, status=400)
        
        # Get the locations
        try:
            origin = Location.objects.get(pk=origin_id)
            destination = Location.objects.get(pk=destination_id)
        except Location.DoesNotExist:
            return JsonResponse({'error': 'Invalid origin or destination'}, status=400)
        
        # Get route recommendations
        route_planner = RoutePlannerService()
        recommended_routes = route_planner.find_best_routes(origin_id, destination_id, travel_datetime)
        
        if not recommended_routes:
            return JsonResponse({'error': 'No routes found'}, status=404)
        
        # Save the recommendation
        recommendation = route_planner.save_recommendation(request.user, origin_id, destination_id, recommended_routes)
        
        # Return success and redirect to the recommendation detail
        return JsonResponse({
            'success': True,
            'recommendation_id': recommendation.id,
            'redirect_url': f'/routes/recommendation/{recommendation.id}/'
        })
        
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


@login_required
def view_recommendation(request, recommendation_id):
    """
    View a saved route recommendation.
    """
    recommendation = get_object_or_404(
        RouteRecommendation.objects.select_related('origin', 'destination').prefetch_related('routes'),
        pk=recommendation_id
    )
    
    # Check permissions (user must own the recommendation)
    if recommendation.user != request.user and not (request.user.is_admin or request.user.is_officer):
        return HttpResponse("Unauthorized", status=403)
    
    # Get active traffic jams that might affect the route
    # This is a simplified approach - in a real system, we'd check if the jams are actually on the route
    active_jams = TrafficJam.objects.filter(
        is_active=True
    ).select_related('location')
    
    context = {
        'recommendation': recommendation,
        'routes': recommendation.routes.all().order_by('route_type'),
        'active_jams': active_jams,
    }
    
    return render(request, 'route_planner/recommendation_detail.html', context)


@login_required
@require_POST
def toggle_favorite(request, recommendation_id):
    """
    Toggle favorite status for a route recommendation.
    """
    recommendation = get_object_or_404(RouteRecommendation, pk=recommendation_id)
    
    # Check permissions (user must own the recommendation)
    if recommendation.user != request.user:
        return JsonResponse({'error': 'Unauthorized'}, status=403)
    
    # Toggle favorite status
    recommendation.is_favorite = not recommendation.is_favorite
    recommendation.save(update_fields=['is_favorite'])
    
    return JsonResponse({
        'success': True,
        'is_favorite': recommendation.is_favorite
    })


@login_required
def traffic_jams(request):
    """
    View traffic jams in the system.
    """
    # Get all locations for reporting
    locations = Location.objects.all().order_by('name')
    
    # Get active and recently resolved traffic jams
    active_jams = TrafficJam.objects.filter(
        is_active=True
    ).select_related('location', 'reported_by').order_by('-severity', '-start_time')
    
    # Get recently resolved jams (last 24 hours)
    one_day_ago = timezone.now() - timezone.timedelta(days=1)
    resolved_jams = TrafficJam.objects.filter(
        is_active=False,
        end_time__gte=one_day_ago
    ).select_related('location', 'reported_by').order_by('-end_time')
    
    context = {
        'locations': locations,
        'active_jams': active_jams,
        'resolved_jams': resolved_jams,
    }
    
    return render(request, 'route_planner/traffic_jams.html', context)


@login_required
@require_POST
def report_traffic_jam(request):
    """
    Report a new traffic jam.
    """
    try:
        location_id = int(request.POST.get('location_id'))
        severity = request.POST.get('severity')
        description = request.POST.get('description', '')
        
        # Validate severity
        valid_severities = [choice[0] for choice in TrafficJam.Severity.choices]
        if severity not in valid_severities:
            return JsonResponse({'error': 'Invalid severity level'}, status=400)
        
        # Get the location
        try:
            location = Location.objects.get(pk=location_id)
        except Location.DoesNotExist:
            return JsonResponse({'error': 'Invalid location'}, status=400)
        
        # Create the traffic jam
        jam = TrafficJam.objects.create(
            location=location,
            reported_by=request.user,
            severity=severity,
            description=description,
            start_time=timezone.now(),
            is_active=True
        )
        
        return JsonResponse({
            'success': True,
            'jam_id': jam.id,
            'message': 'Traffic jam reported successfully'
        })
        
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


@login_required
@require_POST
def resolve_traffic_jam(request, jam_id):
    """
    Mark a traffic jam as resolved.
    """
    jam = get_object_or_404(TrafficJam, pk=jam_id)
    
    # Check permissions (user must be admin, officer, or the reporter)
    if not (request.user.is_admin or request.user.is_officer or jam.reported_by == request.user):
        return JsonResponse({'error': 'Unauthorized'}, status=403)
    
    # Only resolve if it's still active
    if jam.is_active:
        jam.resolve()
        return redirect('route_planner:traffic_jams')
    
    return JsonResponse({'error': 'Traffic jam is already resolved'}, status=400)