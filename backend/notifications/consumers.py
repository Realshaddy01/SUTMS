import json
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from django.contrib.auth import get_user_model

User = get_user_model()

class NotificationConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.user_id = self.scope['url_route']['kwargs']['user_id']
        self.notification_group_name = f'user_{self.user_id}_notifications'
        
        # Check if the user exists
        user_exists = await self.check_user_exists(self.user_id)
        if not user_exists:
            await self.close()
            return
        
        # Join notification group
        await self.channel_layer.group_add(
            self.notification_group_name,
            self.channel_name
        )
        
        await self.accept()
    
    async def disconnect(self, close_code):
        # Leave notification group
        await self.channel_layer.group_discard(
            self.notification_group_name,
            self.channel_name
        )
    
    async def receive(self, text_data):
        # Handle received messages (if needed)
        pass
    
    async def notification(self, event):
        # Send notification to WebSocket
        await self.send(text_data=json.dumps({
            'type': 'notification',
            'title': event['title'],
            'message': event['message'],
            'data': event.get('data', {})
        }))
    
    @database_sync_to_async
    def check_user_exists(self, user_id):
        try:
            User.objects.get(id=user_id)
            return True
        except User.DoesNotExist:
            return False

