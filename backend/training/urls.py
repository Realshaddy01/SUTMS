"""
URL patterns for the training app.
"""
from django.urls import path

from . import views

app_name = 'training'

urlpatterns = [
    # Web views
    path('', views.training_dashboard, name='dashboard'),
    path('images/', views.training_images, name='images'),
    path('train/', views.train_model, name='train'),
    path('evaluate/', views.evaluate_model, name='evaluate'),
    path('models/', views.model_list, name='models'),
    
    # API endpoints
    path('api/images/', views.training_images_api, name='api_images'),
    path('api/train/', views.train_model_api, name='api_train'),
    path('api/evaluate/', views.evaluate_model_api, name='api_evaluate'),
    path('api/models/', views.model_list_api, name='api_models'),
]