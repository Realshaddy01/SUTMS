"""URL patterns for the route_planner app."""

from django.urls import path
from . import views

app_name = 'route_planner'

urlpatterns = [
    # Main route planner page
    path('', views.index, name='index'),
    
    # Route recommendation endpoints
    path('get-recommendations/', views.get_route_recommendations, name='get_recommendations'),
    path('recommendation/<int:recommendation_id>/', views.view_recommendation, name='view_recommendation'),
    path('recommendation/<int:recommendation_id>/toggle-favorite/', views.toggle_favorite, name='toggle_favorite'),
    
    # Traffic jam endpoints
    path('traffic-jams/', views.traffic_jams, name='traffic_jams'),
    path('report-traffic-jam/', views.report_traffic_jam, name='report_traffic_jam'),
    path('resolve-traffic-jam/<int:jam_id>/', views.resolve_traffic_jam, name='resolve_traffic_jam'),
]