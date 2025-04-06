from django.shortcuts import render
from django.contrib.auth.decorators import login_required
from django.utils import timezone
from datetime import timedelta
from django.db.models import Sum, Count, Q

# Import models as needed
from vehicles.models import Vehicle
from violations.models import Violation, Notification, ViolationAppeal


@login_required
def dashboard(request):
    """Main dashboard view with role-specific data."""
    context = {
        'current_date': timezone.now(),
    }
    
    # Get statistics based on user role
    if request.user.is_vehicle_owner():
        # Statistics for vehicle owners
        user_vehicles = Vehicle.objects.filter(owner=request.user)
        user_violations = Violation.objects.filter(vehicle__in=user_vehicles)
        
        pending_violations = user_violations.filter(
            status__in=['pending', 'approved', 'issued']
        ).count()
        
        outstanding_fines = user_violations.filter(
            status__in=['pending', 'approved', 'issued']
        ).aggregate(total=Sum('fine_amount'))['total'] or 0
        
        # Calculate compliance rate
        total_violations = user_violations.count()
        if total_violations > 0:
            resolved_violations = user_violations.filter(
                status__in=['paid', 'appeal_approved', 'cancelled']
            ).count()
            compliance_rate = f"{int((resolved_violations / total_violations) * 100)}%"
        else:
            compliance_rate = "100%"
        
        context.update({
            'stats': {
                'vehicles_count': user_vehicles.count(),
                'pending_violations': pending_violations,
                'outstanding_fines': f"रू {outstanding_fines:,.2f}",
                'compliance_rate': compliance_rate,
            },
            'recent_violations': user_violations.order_by('-timestamp')[:5],
        })
        
    elif request.user.is_officer():
        # Statistics for traffic officers
        today = timezone.now().date()
        violations_today = Violation.objects.filter(
            reported_by=request.user,
            timestamp__date=today
        ).count()
        
        # This would be replaced with actual plate detection model in production
        from ocr.models import LicensePlateDetection
        detections = LicensePlateDetection.objects.filter(user=request.user)
        
        # Get pending appeals count
        pending_appeals = ViolationAppeal.objects.filter(
            status='pending'
        ).count()
        
        # Detection accuracy (placeholder for demo)
        detection_accuracy = "85%"
        
        context.update({
            'stats': {
                'violations_today': violations_today,
                'detections_count': detections.count(),
                'pending_appeals': pending_appeals,
                'detection_accuracy': detection_accuracy,
            },
            'recent_detections': detections.order_by('-created_at')[:5],
        })
        
    elif request.user.is_admin():
        # Statistics for administrators
        total_vehicles = Vehicle.objects.count()
        total_violations = Violation.objects.count()
        
        # Revenue collected
        total_revenue = Violation.objects.filter(
            status='paid'
        ).aggregate(total=Sum('fine_amount'))['total'] or 0
        
        # User count 
        # Replace with actual User model import in production
        from django.contrib.auth import get_user_model
        User = get_user_model()
        total_users = User.objects.count()
        
        # Last 7 days violations for chart
        last_week = timezone.now().date() - timedelta(days=7)
        violation_data = []
        violation_types = Violation.objects.values('violation_type__name').annotate(
            count=Count('id')
        ).order_by('-count')[:5]
        
        for vtype in violation_types:
            violation_data.append({
                'label': vtype['violation_type__name'],
                'count': vtype['count']
            })
        
        context.update({
            'stats': {
                'total_vehicles': total_vehicles,
                'total_violations': total_violations,
                'total_revenue': f"रू {total_revenue:,.2f}",
                'total_users': total_users,
            },
            'violation_data': violation_data,
        })
    
    # Recent activities for all users
    activities = Notification.objects.filter(
        Q(user=request.user) | Q(user__isnull=True)
    ).order_by('-created_at')[:10]
    
    context['recent_activities'] = activities
    
    # Get unread notifications count for topbar
    unread_count = Notification.objects.filter(
        user=request.user, 
        is_read=False
    ).count()
    
    context['unread_notifications_count'] = unread_count
    context['notifications'] = Notification.objects.filter(
        user=request.user
    ).order_by('-created_at')[:5]
    
    return render(request, 'dashboard/index.html', context)