"""
WebSocket routing configuration for the tracking app.
"""

from django.urls import path

from . import consumers

websocket_urlpatterns = [
    path('ws/tracking/', consumers.TrackingConsumer.as_asgi()),
    path('ws/signals/', consumers.SignalConsumer.as_asgi()),
    path('ws/incidents/', consumers.IncidentConsumer.as_asgi()),
]