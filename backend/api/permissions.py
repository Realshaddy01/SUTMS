"""
Custom permission classes for the SUTMS API.
"""
from rest_framework import permissions


class IsOfficerOrAdmin(permissions.BasePermission):
    """
    Custom permission to allow only officers and admins to perform actions.
    """
    def has_permission(self, request, view):
        if not request.user.is_authenticated:
            return False
        
        if request.user.is_staff or request.user.is_superuser:
            return True
        
        if hasattr(request.user, 'role'):
            return request.user.role in ['officer', 'admin']
        
        return False


class IsAdminUser(permissions.BasePermission):
    """
    Custom permission to only allow admin users to perform actions.
    """
    def has_permission(self, request, view):
        if not request.user.is_authenticated:
            return False
        
        if request.user.is_superuser:
            return True
        
        if hasattr(request.user, 'role'):
            return request.user.role == 'admin'
        
        return False


class IsVehicleOwner(permissions.BasePermission):
    """
    Custom permission to only allow vehicle owners to perform actions on their vehicles.
    """
    def has_object_permission(self, request, view, obj):
        if not request.user.is_authenticated:
            return False
        
        if request.user.is_staff or request.user.is_superuser:
            return True
        
        if hasattr(request.user, 'role') and request.user.role in ['officer', 'admin']:
            return True
        
        # Check if the user is the owner of the vehicle
        return obj.owner == request.user


class IsOfficerAssignedToViolation(permissions.BasePermission):
    """
    Custom permission to only allow officers who are assigned to a violation to perform actions.
    """
    def has_object_permission(self, request, view, obj):
        if not request.user.is_authenticated:
            return False
        
        if request.user.is_staff or request.user.is_superuser:
            return True
        
        if hasattr(request.user, 'role') and request.user.role == 'admin':
            return True
        
        # Check if the user is the officer assigned to the violation
        return obj.officer == request.user


class IsOwnerOrOfficerOrAdmin(permissions.BasePermission):
    """
    Custom permission to allow owner, officer, or admin to perform actions.
    """
    def has_object_permission(self, request, view, obj):
        if not request.user.is_authenticated:
            return False
        
        if request.user.is_staff or request.user.is_superuser:
            return True
        
        if hasattr(request.user, 'role') and request.user.role in ['officer', 'admin']:
            return True
        
        # Check if the user is the owner of the object (for objects like Vehicle that have owner field)
        if hasattr(obj, 'owner'):
            return obj.owner == request.user
        
        # For violations, check if the user owns the vehicle
        if hasattr(obj, 'vehicle') and hasattr(obj.vehicle, 'owner'):
            return obj.vehicle.owner == request.user
        
        return False