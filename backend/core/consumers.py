import json
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from django.contrib.auth.models import User, AnonymousUser
from rest_framework.authtoken.models import Token
from .models import Notification

class NotificationConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.user = self.scope["user"]
        self.notification_group_name = f"user_{self.user.id}_notifications"
        
        # Verify the user is authenticated
        if isinstance(self.user, AnonymousUser):
            # Try to authenticate with token
            token = self.scope.get('url_route', {}).get('kwargs', {}).get('token', None)
            if token:
                self.user = await self.get_user_from_token(token)
                if self.user is None:
                    await self.close()
                    return
            else:
                await self.close()
                return
        
        # Join notification group
        await self.channel_layer.group_add(
            self.notification_group_name,
            self.channel_name
        )
        
        await self.accept()
        
        # Send unread notifications count on connect
        unread_count = await self.get_unread_notifications_count()
        await self.send(text_data=json.dumps({
            'type': 'unread_count',
            'count': unread_count
        }))
    
    async def disconnect(self, close_code):
        # Leave notification group
        await self.channel_layer.group_discard(
            self.notification_group_name,
            self.channel_name
        )
    
    # Receive message from WebSocket
    async def receive(self, text_data):
        text_data_json = json.loads(text_data)
        message_type = text_data_json.get('type', '')
        
        if message_type == 'mark_read':
            notification_id = text_data_json.get('id')
            if notification_id:
                await self.mark_notification_read(notification_id)
                unread_count = await self.get_unread_notifications_count()
                await self.send(text_data=json.dumps({
                    'type': 'unread_count',
                    'count': unread_count
                }))
        
        elif message_type == 'mark_all_read':
            await self.mark_all_notifications_read()
            await self.send(text_data=json.dumps({
                'type': 'unread_count',
                'count': 0
            }))
    
    # Receive message from notification group
    async def notification_message(self, event):
        message = event['message']
        
        # Send message to WebSocket
        await self.send(text_data=json.dumps(message))
    
    # Database operations
    @database_sync_to_async
    def get_user_from_token(self, token_key):
        try:
            token = Token.objects.get(key=token_key)
            return token.user
        except Token.DoesNotExist:
            return None
    
    @database_sync_to_async
    def get_unread_notifications_count(self):
        return Notification.objects.filter(
            user=self.user, 
            is_read=False
        ).count()
    
    @database_sync_to_async
    def mark_notification_read(self, notification_id):
        try:
            notification = Notification.objects.get(
                id=notification_id,
                user=self.user
            )
            notification.is_read = True
            notification.save(update_fields=['is_read'])
            return True
        except Notification.DoesNotExist:
            return False
    
    @database_sync_to_async
    def mark_all_notifications_read(self):
        Notification.objects.filter(
            user=self.user, 
            is_read=False
        ).update(is_read=True)
        return True
