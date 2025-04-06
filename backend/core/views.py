from django.http import JsonResponse

def health_check(request):
    """
    A simple health check endpoint to verify the API is working
    """
    return JsonResponse({
        "status": "ok",
        "message": "SUTMS API is running"
    })