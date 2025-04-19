from django.http import JsonResponse, HttpResponse
from django.shortcuts import render

def health_check(request):
    """
    A simple health check endpoint to verify the API is working
    """
    return JsonResponse({
        "status": "ok",
        "message": "SUTMS API is running"
    })

def home(request):
    """
    Home page for the SUTMS project
    """
    return HttpResponse("""
    <html>
        <head>
            <title>Smart Urban Traffic Management System</title>
            <style>
                body {
                    font-family: Arial, sans-serif;
                    line-height: 1.6;
                    margin: 0;
                    padding: 20px;
                    max-width: 800px;
                    margin: 0 auto;
                }
                h1 {
                    color: #333;
                    border-bottom: 1px solid #eee;
                    padding-bottom: 10px;
                }
                .status {
                    background-color: #e9f7ef;
                    border-left: 4px solid #27ae60;
                    padding: 15px;
                    margin: 20px 0;
                }
            </style>
        </head>
        <body>
            <h1>Smart Urban Traffic Management System</h1>
            <div class="status">
                <h2>Server Status: Online</h2>
                <p>The Django backend server is running correctly.</p>
            </div>
            <p>Welcome to the Smart Urban Traffic Management System (SUTMS) with Nepali license plate recognition.</p>
            <p>This system provides:</p>
            <ul>
                <li>License plate recognition for Nepali vehicles</li>
                <li>Traffic violation detection and reporting</li>
                <li>Vehicle owner notifications</li>
                <li>Traffic officer dashboards</li>
                <li>Payment processing for violations</li>
            </ul>
            <p>API endpoints are available at <a href="/api/">/api/</a></p>
        </body>
    </html>
    """)

def home_view(request):
    """
    View for the home page
    """
    context = {
        'server_status': {
            'is_running': True,
            'message': 'Django server is running successfully'
        }
    }
    return render(request, 'home/index.html', context)