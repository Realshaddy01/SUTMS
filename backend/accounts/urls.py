from django.urls import path
from . import views

app_name = 'accounts'

urlpatterns = [
    path('api-token-auth/', views.CustomObtainAuthToken.as_view(), name='api_token_auth'),
    path('login/', views.custom_login, name='custom_login'),
    path('create-admin/', views.create_test_superuser, name='create_admin'),
] 