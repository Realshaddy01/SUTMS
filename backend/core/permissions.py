from rest_framework import permissions

class IsOwner(permissions.BasePermission):
    """
    Custom permission to only allow owners of an object to access it.
    """
    def has_object_permission(self, request, view, obj):
        # For User objects, check if the user is the same
        if hasattr(obj, 'user'):
            return obj.user == request.user
        
        # For Notification objects
        if hasattr(obj, 'user_id'):
            return obj.user_id == request.user.id
        
        # For other objects with an owner field
        if hasattr(obj, 'owner'):
            if hasattr(obj.owner, 'user'):
                return obj.owner.user == request.user
        
        # For Violation objects
        if hasattr(obj, 'vehicle'):
            if hasattr(obj.vehicle, 'owner'):
                if hasattr(obj.vehicle.owner, 'user'):
                    return obj.vehicle.owner.user == request.user
        
        return False

class IsTrafficOfficer(permissions.BasePermission):
    """
    Custom permission to only allow traffic officers to access certain views.
    """
    def has_permission(self, request, view):
        return (
            request.user.is_authenticated and 
            hasattr(request.user, 'profile') and 
            hasattr(request.user.profile, 'trafficofficer')
        )

class IsVehicleOwner(permissions.BasePermission):
    """
    Custom permission to only allow vehicle owners to access certain views.
    """
    def has_permission(self, request, view):
        return (
            request.user.is_authenticated and 
            hasattr(request.user, 'profile') and 
            hasattr(request.user.profile, 'vehicleowner')
        )
