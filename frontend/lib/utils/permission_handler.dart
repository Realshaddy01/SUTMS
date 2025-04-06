import 'package:permission_handler/permission_handler.dart';

class PermissionUtil {
  // Check and request camera permission
  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.status;
    
    if (status.isGranted) {
      return true;
    } else if (status.isDenied) {
      final result = await Permission.camera.request();
      return result.isGranted;
    } else if (status.isPermanentlyDenied) {
      return false;
    }
    
    return false;
  }
  
  // Check and request location permission
  static Future<bool> requestLocationPermission() async {
    final status = await Permission.location.status;
    
    if (status.isGranted) {
      return true;
    } else if (status.isDenied) {
      final result = await Permission.location.request();
      return result.isGranted;
    } else if (status.isPermanentlyDenied) {
      return false;
    }
    
    return false;
  }
  
  // Check and request storage permission
  static Future<bool> requestStoragePermission() async {
    final status = await Permission.storage.status;
    
    if (status.isGranted) {
      return true;
    } else if (status.isDenied) {
      final result = await Permission.storage.request();
      return result.isGranted;
    } else if (status.isPermanentlyDenied) {
      return false;
    }
    
    return false;
  }
  
  // Check and request notification permission
  static Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.status;
    
    if (status.isGranted) {
      return true;
    } else if (status.isDenied) {
      final result = await Permission.notification.request();
      return result.isGranted;
    } else if (status.isPermanentlyDenied) {
      return false;
    }
    
    return false;
  }
  
  // Open app settings
  static Future<bool> openAppSettings() async {
    return await openAppSettings();
  }
  
  // Check multiple permissions
  static Future<Map<Permission, PermissionStatus>> requestMultiplePermissions(
    List<Permission> permissions
  ) async {
    return await permissions.request();
  }
}
