from rest_framework import views, permissions, status
from rest_framework.response import Response
from django.db.models import Count, Sum
from django.db.models.functions import TruncDate, TruncMonth
from violations.models import Violation, ViolationType
from vehicles.models import Vehicle
from django.contrib.auth import get_user_model

User = get_user_model()

class IsAdminUser(permissions.BasePermission):
    def has_permission(self, request, view):
        return request.user.user_type == 'admin'

class DashboardStatsView(views.APIView):
    permission_classes = [permissions.IsAuthenticated, IsAdminUser]
    
    def get(self, request):
        # Count total users by type
        user_stats = User.objects.values('user_type').annotate(count=Count('id'))
        
        # Count total vehicles by type
        vehicle_stats = Vehicle.objects.values('vehicle_type').annotate(count=Count('id'))
        
        # Count violations by type
        violation_type_stats = Violation.objects.values('violation_type__name').annotate(count=Count('id'))
        
        # Count violations by status
        violation_status_stats = Violation.objects.values('status').annotate(count=Count('id'))
        
        # Calculate total fines and collected amount
        total_fines = Violation.objects.aggregate(total=Sum('fine_amount'))['total'] or 0
        collected_fines = Violation.objects.filter(is_paid=True).aggregate(total=Sum('fine_amount'))['total'] or 0
        
        # Get daily violations for the last 30 days
        daily_violations = Violation.objects.annotate(
            date=TruncDate('timestamp')
        ).values('date').annotate(count=Count('id')).order_by('-date')[:30]
        
        # Get monthly violations for the last 12 months
        monthly_violations = Violation.objects.annotate(
            month=TruncMonth('timestamp')
        ).values('month').annotate(count=Count('id')).order_by('-month')[:12]
        
        return Response({
            'user_stats': user_stats,
            'vehicle_stats': vehicle_stats,
            'violation_type_stats': violation_type_stats,
            'violation_status_stats': violation_status_stats,
            'financial_stats': {
                'total_fines': total_fines,
                'collected_fines': collected_fines,
                'collection_rate': (collected_fines / total_fines * 100) if total_fines > 0 else 0
            },
            'daily_violations': daily_violations,
            'monthly_violations': monthly_violations
        })

class OfficerStatsView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request):
        if request.user.user_type not in ['officer', 'admin']:
            return Response({'error': 'Not authorized'}, status=status.HTTP_403_FORBIDDEN)
        
        # For officers, show their own stats
        if request.user.user_type == 'officer':
            reported_violations = Violation.objects.filter(reported_by=request.user)
            
            # Count violations by type
            violation_type_stats = reported_violations.values('violation_type__name').annotate(count=Count('id'))
            
            # Count violations by status
            violation_status_stats = reported_violations.values('status').annotate(count=Count('id'))
            
            # Get daily violations for the last 30 days
            daily_violations = reported_violations.annotate(
                date=TruncDate('timestamp')
            ).values('date').annotate(count=Count('id')).order_by('-date')[:30]
            
            return Response({
                'total_reported': reported_violations.count(),
                'violation_type_stats': violation_type_stats,
                'violation_status_stats': violation_status_stats,
                'daily_violations': daily_violations
            })
        
        # For admins, show stats for all officers
        officer_stats = Violation.objects.values('reported_by__username', 'reported_by__first_name', 'reported_by__last_name').annotate(
            total_reported=Count('id')
        ).filter(reported_by__user_type='officer').order_by('-total_reported')
        
        return Response({
            'officer_stats': officer_stats
        })

class DriverStatsView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request):
        # Drivers can only see their own stats
        if request.user.user_type == 'driver':
            vehicles = Vehicle.objects.filter(owner=request.user)
            violations = Violation.objects.filter(vehicle__in=vehicles)
            
            # Count violations by vehicle
            vehicle_violation_stats = violations.values('vehicle__license_plate').annotate(count=Count('id'))
            
            # Count violations by type
            violation_type_stats = violations.values('violation_type__name').annotate(count=Count('id'))
            
            # Count violations by status
            violation_status_stats = violations.values('status').annotate(count=Count('id'))
            
            # Calculate total fines and paid amount
            total_fines = violations.aggregate(total=Sum('fine_amount'))['total'] or 0
            paid_fines = violations.filter(is_paid=True).aggregate(total=Sum('fine_amount'))['total'] or 0
            
            return Response({
                'total_violations': violations.count(),
                'vehicle_violation_stats': vehicle_violation_stats,
                'violation_type_stats': violation_type_stats,
                'violation_status_stats': violation_status_stats,
                'financial_stats': {
                    'total_fines': total_fines,
                    'paid_fines': paid_fines,
                    'pending_fines': total_fines - paid_fines
                }
            })
        
        return Response({'error': 'Not authorized'}, status=status.HTTP_403_FORBIDDEN)

