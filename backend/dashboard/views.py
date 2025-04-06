from django.shortcuts import render
from django.contrib.auth.decorators import login_required
from django.db.models import Count, Sum, Avg
from django.utils import timezone
from datetime import timedelta

# Import necessary models from other apps
from violations.models import Violation, ViolationType
from vehicles.models import Vehicle
from tracking.models import TrafficOfficerLocation
from ocr.models import LicensePlateDetection


@login_required
def dashboard(request):
    """Main dashboard view showing statistics and recent activity."""
    
    # Get today's date and date range for statistics
    today = timezone.now().date()
    week_ago = today - timedelta(days=7)
    month_ago = today - timedelta(days=30)
    
    context = {
        'today': today,
    }
    
    # Different stats based on user role
    if request.user.is_admin:
        # Admin dashboard stats
        context.update({
            'total_violations': Violation.objects.count(),
            'weekly_violations': Violation.objects.filter(created_at__gte=week_ago).count(),
            'total_vehicles': Vehicle.objects.count(),
            'total_officers': TrafficOfficerLocation.objects.values('officer').distinct().count(),
            'recent_detections': LicensePlateDetection.objects.order_by('-detected_at')[:10],
            'violation_chart_data': _get_violation_chart_data(month_ago),
            'officer_stats': _get_officer_stats(),
            'hotspot_data': _get_violation_hotspots(),
        })
    elif request.user.is_officer:
        # Officer dashboard stats
        context.update({
            'officer_violations': Violation.objects.filter(reported_by=request.user).count(),
            'officer_weekly': Violation.objects.filter(
                reported_by=request.user, 
                created_at__gte=week_ago
            ).count(),
            'recent_reports': Violation.objects.filter(
                reported_by=request.user
            ).order_by('-created_at')[:5],
            'recent_detections': LicensePlateDetection.objects.filter(
                user=request.user
            ).order_by('-detected_at')[:10],
            'officer_chart_data': _get_officer_violations_chart(request.user, month_ago),
        })
    else:
        # Vehicle owner dashboard stats
        owner_vehicles = Vehicle.objects.filter(owner=request.user)
        context.update({
            'owner_vehicles': owner_vehicles,
            'vehicle_violations': Violation.objects.filter(
                vehicle__in=owner_vehicles
            ).count(),
            'recent_violations': Violation.objects.filter(
                vehicle__in=owner_vehicles
            ).order_by('-created_at')[:5],
            'unpaid_violations': Violation.objects.filter(
                vehicle__in=owner_vehicles,
                status='issued'
            ).count(),
            'owner_chart_data': _get_owner_violations_chart(request.user, month_ago),
        })
    
    return render(request, 'dashboard/dashboard.html', context)


def _get_violation_chart_data(start_date):
    """Get violation statistics for charts."""
    # This is a placeholder for actual chart data gathering
    violation_stats = Violation.objects.filter(
        created_at__gte=start_date
    ).values('violation_type__name').annotate(
        count=Count('id')
    ).order_by('-count')
    
    return violation_stats


def _get_officer_stats():
    """Get officer activity statistics."""
    # This is a placeholder for actual officer stats calculation
    return {}


def _get_violation_hotspots():
    """Get geographical hotspots for violations."""
    # This is a placeholder for actual hotspot calculation
    return {}


def _get_officer_violations_chart(officer, start_date):
    """Get violation statistics for a specific officer."""
    # This is a placeholder for actual officer-specific chart data
    return {}


def _get_owner_violations_chart(owner, start_date):
    """Get violation statistics for a specific vehicle owner."""
    # This is a placeholder for actual owner-specific chart data
    return {}