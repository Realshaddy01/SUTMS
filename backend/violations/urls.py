"""
URL patterns for the violations app.
"""
from django.urls import path

from . import views

app_name = 'violations'

urlpatterns = [
    # Web views
    path('', views.violation_list, name='list'),
    path('<int:violation_id>/', views.violation_detail, name='detail'),
    path('report/', views.report_violation, name='report'),
    path('types/', views.violation_types, name='types'),
    path('appeals/', views.appeal_list, name='appeals'),
    path('appeals/<int:appeal_id>/', views.appeal_detail, name='appeal_detail'),
    
    # API endpoints
    path('api/violations/', views.violation_list_api, name='api_list'),
    path('api/violations/<int:violation_id>/', views.violation_detail_api, name='api_detail'),
    path('api/violations/report/', views.report_violation_api, name='api_report'),
    path('api/violation-types/', views.violation_types_api, name='api_types'),
    path('api/appeals/', views.appeal_list_api, name='api_appeals'),
    path('api/appeals/<int:appeal_id>/', views.appeal_detail_api, name='api_appeal_detail'),
]