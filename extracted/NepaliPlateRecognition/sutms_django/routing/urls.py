"""
URL patterns for the routing app.
"""
from django.urls import path

from . import views

app_name = 'routing'

urlpatterns = [
    # Web views
    path('', views.route_dashboard, name='dashboard'),
    path('planner/', views.route_planner, name='planner'),
    path('analytics/', views.traffic_analytics, name='analytics'),
    path('peak-traffic/', views.peak_traffic_management, name='peak_traffic_management'),
    path('peak-traffic/delete/<uuid:peak_id>/', views.delete_peak_traffic, name='delete_peak_traffic'),
    path('history/', views.route_history, name='history'),
    path('history/<uuid:route_id>/', views.route_detail, name='route_detail'),
    
    # API endpoints
    path('api/recommend/', views.route_recommendation_api, name='route_recommendation_api'),
    path('api/traffic-prediction/', views.traffic_prediction_api, name='traffic_prediction_api'),
    path('api/train-model/', views.train_model_api, name='train_model_api'),
]