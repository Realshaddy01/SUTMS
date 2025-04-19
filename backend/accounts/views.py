from django.shortcuts import render, redirect
from rest_framework.authtoken.models import Token
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework import status
from django.contrib.auth import authenticate, login
from rest_framework.permissions import AllowAny
from django.views.decorators.csrf import csrf_protect
from django.contrib.auth.decorators import user_passes_test
from django.http import JsonResponse
from django.contrib.auth import get_user_model
from django.conf import settings

User = get_user_model()

# Create your views here.

class CustomObtainAuthToken(APIView):
    """
    A custom view for obtaining authentication tokens without relying on coreapi
    """
    permission_classes = [AllowAny]
    
    def post(self, request, *args, **kwargs):
        username = request.data.get('username')
        password = request.data.get('password')
        
        if username is None or password is None:
            return Response({'error': 'Please provide both username and password'},
                            status=status.HTTP_400_BAD_REQUEST)
        
        user = authenticate(username=username, password=password)
        
        if not user:
            return Response({'error': 'Invalid Credentials'},
                            status=status.HTTP_401_UNAUTHORIZED)
        
        token, created = Token.objects.get_or_create(user=user)
        return Response({'token': token.key})

@csrf_protect
def custom_login(request):
    """Custom login view for direct admin login"""
    if request.method == 'POST':
        username = request.POST.get('username')
        password = request.POST.get('password')
        
        user = authenticate(request, username=username, password=password)
        
        if user is not None:
            login(request, user)
            
            # Create a session for the user
            request.session['user_id'] = user.id
            request.session['is_authenticated'] = True
            
            # Redirect to admin if superuser or staff
            if user.is_superuser or user.is_staff:
                return redirect('/admin/')
            
            # Otherwise redirect to home
            return redirect('/')
        else:
            return JsonResponse({'status': 'error', 'message': 'Invalid credentials'}, status=401)
    
    return render(request, 'accounts/login.html')

def create_test_superuser(request):
    """Create a test superuser for development purposes only"""
    if not settings.DEBUG:
        return JsonResponse({'status': 'error', 'message': 'Only available in debug mode'}, status=403)
    
    if User.objects.filter(username='admin').exists():
        return JsonResponse({'status': 'success', 'message': 'Admin user already exists'})
    
    User.objects.create_superuser(
        username='admin', 
        email='admin@example.com', 
        password='adminpassword',
        user_type='admin'
    )
    
    return JsonResponse({'status': 'success', 'message': 'Admin user created'})
