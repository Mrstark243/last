import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

class PermissionService {
  static Future<bool> requestAllPermissions() async {
    try {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.storage,
        Permission.photos,
        Permission.camera,
        Permission.mediaLibrary,
        Permission.manageExternalStorage,
      ].request();

      // Check if any permission was denied
      bool allGranted = true;
      statuses.forEach((permission, status) {
        if (!status.isGranted) {
          allGranted = false;
        }
      });

      if (!allGranted) {
        // Open app settings if any permission was denied
        await openAppSettings();
      }

      return allGranted;
    } on PlatformException catch (e) {
      print('Error requesting permissions: ${e.message}');
      return false;
    } catch (e) {
      print('Error requesting permissions: $e');
      return false;
    }
  }

  static Future<bool> checkAndRequestPermission(Permission permission) async {
    try {
      PermissionStatus status = await permission.status;
      if (!status.isGranted) {
        status = await permission.request();
      }
      return status.isGranted;
    } catch (e) {
      print('Error checking/requesting permission: $e');
      return false;
    }
  }
} 