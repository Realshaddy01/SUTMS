"""
Analytics views for the SUTMS API.
"""
from django.db.models import Count, Sum, Avg, F, Q
from django.db.models.functions import TruncDay, TruncWeek, TruncMonth, ExtractHour
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework import serializers

from api.permissions import IsOfficerOrAdmin
from violations.models import Violation
from tracking.models import TrafficIncident


class AnalyticsViewSet(viewsets.ViewSet):
    """
    ViewSet for analytics data.
    """
    permission_classes = [IsAuthenticated, IsOfficerOrAdmin]
    
    @action(detail=False, methods=['get'])
    def summary(self, request):
        """
        Get summary statistics.
        """
        # Get the total number of violations
        total_violations = Violation.objects.count()
        
        # Get the total amount of fines
        total_fines = Violation.objects.aggregate(
            total=Sum('fine_amount')
        )['total'] or 0
        
        # Get the number of pending violations
        pending_violations = Violation.objects.filter(
            status='pending'
        ).count()
        
        # Get the number of paid violations
        paid_violations = Violation.objects.filter(
            status='paid'
        ).count()
        
        # Get the number of active incidents
        active_incidents = TrafficIncident.objects.filter(
            is_active=True
        ).count()
        
        return Response({
            'total_violations': total_violations,
            'total_fines': total_fines,
            'pending_violations': pending_violations,
            'paid_violations': paid_violations,
            'active_incidents': active_incidents
        })
    
    @action(detail=False, methods=['get'])
    def violations_by_type(self, request):
        """
        Get violations grouped by type.
        """
        # Get optional period parameter
        period = request.query_params.get('period', 'all')
        
        # Base queryset
        queryset = Violation.objects.all()
        
        # Apply time filtering if needed
        if period != 'all':
            queryset = self._filter_by_period(queryset, period)
        
        # Group by violation type
        violations_by_type = queryset.values(
            'violation_type'
        ).annotate(
            count=Count('id'),
            total_fines=Sum('fine_amount'),
            avg_fine=Avg('fine_amount')
        ).order_by('-count')
        
        return Response(violations_by_type)
    
    @action(detail=False, methods=['get'])
    def violations_over_time(self, request):
        """
        Get violations over time.
        """
        # Get optional parameters
        period = request.query_params.get('period', 'month')
        violation_type = request.query_params.get('type')
        
        # Base queryset
        queryset = Violation.objects.all()
        
        # Filter by violation type if specified
        if violation_type:
            queryset = queryset.filter(violation_type=violation_type)
        
        # Group by time period
        if period == 'day':
            queryset = queryset.annotate(
                date=TruncDay('timestamp')
            )
        elif period == 'week':
            queryset = queryset.annotate(
                date=TruncWeek('timestamp')
            )
        else:  # month is default
            queryset = queryset.annotate(
                date=TruncMonth('timestamp')
            )
        
        # Get the counts per period
        violations_over_time = queryset.values(
            'date'
        ).annotate(
            count=Count('id'),
            total_fines=Sum('fine_amount')
        ).order_by('date')
        
        return Response(list(violations_over_time))
    
    @action(detail=False, methods=['get'])
    def hotspots(self, request):
        """
        Get violation hotspots for map visualization.
        """
        # Get optional parameters
        period = request.query_params.get('period', 'month')
        violation_type = request.query_params.get('type')
        limit = int(request.query_params.get('limit', 100))
        
        # Base queryset - only violations with location data
        queryset = Violation.objects.filter(
            latitude__isnull=False,
            longitude__isnull=False
        )
        
        # Apply time filtering
        queryset = self._filter_by_period(queryset, period)
        
        # Filter by violation type if specified
        if violation_type:
            queryset = queryset.filter(violation_type=violation_type)
        
        # Get the distinct locations with counts
        # This is a simplified approach. For production, consider a more
        # sophisticated clustering algorithm like DBSCAN.
        hotspots = []
        
        # Group violations by location (rounded to 4 decimal places for clustering)
        locations = queryset.values(
            'latitude', 'longitude'
        ).annotate(
            count=Count('id'),
            total_fines=Sum('fine_amount')
        ).order_by('-count')[:limit]
        
        for location in locations:
            hotspots.append({
                'lat': location['latitude'],
                'lng': location['longitude'],
                'weight': location['count'],
                'fines': location['total_fines']
            })
        
        return Response({
            'period': period,
            'violation_type': violation_type,
            'hotspots': hotspots
        })
    
    @action(detail=False, methods=['get'])
    def hourly_distribution(self, request):
        """
        Get hourly distribution of violations.
        """
        # Get optional parameters
        violation_type = request.query_params.get('type')
        
        # Base queryset
        queryset = Violation.objects.all()
        
        # Filter by violation type if specified
        if violation_type:
            queryset = queryset.filter(violation_type=violation_type)
        
        # Extract hour and count violations
        hourly_data = queryset.annotate(
            hour=ExtractHour('timestamp')
        ).values(
            'hour'
        ).annotate(
            count=Count('id')
        ).order_by('hour')
        
        # Convert to a list with all 24 hours
        hours = {h: 0 for h in range(24)}
        for item in hourly_data:
            hours[item['hour']] = item['count']
        
        result = [{'hour': hour, 'count': count} for hour, count in hours.items()]
        
        return Response(result)
    
    @action(detail=False, methods=['get'])
    def officer_performance(self, request):
        """
        Get officer performance statistics.
        """
        # Get optional period parameter
        period = request.query_params.get('period', 'month')
        
        # Base queryset
        queryset = Violation.objects.all()
        
        # Apply time filtering
        queryset = self._filter_by_period(queryset, period)
        
        # Group by officer
        officer_stats = queryset.values(
            'officer', 'officer__username'
        ).annotate(
            violations_reported=Count('id'),
            total_fines=Sum('fine_amount'),
            paid_violations=Count('id', filter=Q(status='paid')),
            pending_violations=Count('id', filter=Q(status='pending'))
        ).order_by('-violations_reported')
        
        return Response(list(officer_stats))
    
    def _filter_by_period(self, queryset, period):
        """
        Filter queryset by time period.
        """
        from datetime import datetime, timedelta
        
        now = datetime.now()
        
        if period == 'today':
            start_date = now.replace(hour=0, minute=0, second=0, microsecond=0)
            queryset = queryset.filter(timestamp__gte=start_date)
        elif period == 'week':
            start_date = now - timedelta(days=7)
            queryset = queryset.filter(timestamp__gte=start_date)
        elif period == 'month':
            start_date = now - timedelta(days=30)
            queryset = queryset.filter(timestamp__gte=start_date)
        elif period == 'year':
            start_date = now - timedelta(days=365)
            queryset = queryset.filter(timestamp__gte=start_date)
        
        return queryset