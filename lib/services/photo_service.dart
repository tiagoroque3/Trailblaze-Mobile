import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class PhotoService {
  static const String baseUrl = 'https://trailblaze-460312.appspot.com/rest';
  static final ImagePicker _picker = ImagePicker();

  /// Upload a photo to the server
  static Future<String> uploadPhoto({
    required File imageFile,
    required String jwtToken,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/photos/upload');
      final request = http.MultipartRequest('POST', uri);

      // Add headers
      request.headers['Authorization'] = 'Bearer $jwtToken';

      // Add file
      final multipartFile = await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
      );
      request.files.add(multipartFile);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        String responseBody = response.body.trim();

        // Check if response is JSON format or plain URL
        if (responseBody.startsWith('{') && responseBody.endsWith('}')) {
          try {
            var jsonResponse = jsonDecode(responseBody);
            // Extract photoUrl from JSON response
            return jsonResponse['photoUrl']?.toString() ?? responseBody;
          } catch (e) {
            // If JSON parsing fails, return as is
            return responseBody;
          }
        } else {
          // Plain URL response
          return responseBody;
        }
      } else {
        throw Exception(
          'Failed to upload photo: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error uploading photo: $e');
    }
  }

  /// Add photo URLs to an activity
  static Future<bool> addPhotosToActivity({
    required String activityId,
    required List<String> photoUrls,
    required String jwtToken,
    String? observations,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/operations/activity/addinfo');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({
          'activityId': activityId,
          'observations': observations ?? '',
          'photos': photoUrls,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error adding photos to activity: $e');
    }
  }

  /// Delete a specific photo from an activity
  static Future<bool> deletePhotoFromActivity({
    required String activityId,
    required String photoUrl,
    required String jwtToken,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/operations/activity/deletephoto');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({'activityId': activityId, 'photoUrl': photoUrl}),
      );

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error deleting photo from activity: $e');
    }
  }

  /// Take a photo using the device camera
  static Future<File?> takePhoto() async {
    try {
      // Check camera permission
      final cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        throw Exception('Camera permission denied');
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      throw Exception('Error taking photo: $e');
    }
  }

  /// Check storage permission with better Android version handling
  static Future<bool> _requestStoragePermission() async {
    try {
      // For Android 13+ (API 33+), use granular media permissions
      if (Platform.isAndroid) {
        // Try the new photo permission first (Android 13+)
        var photosPermission = await Permission.photos.status;

        if (photosPermission.isDenied) {
          photosPermission = await Permission.photos.request();
        }

        if (photosPermission.isGranted) {
          return true;
        }

        // Fallback to storage permission for older Android versions
        var storagePermission = await Permission.storage.status;

        if (storagePermission.isDenied) {
          storagePermission = await Permission.storage.request();
        }

        if (storagePermission.isGranted) {
          return true;
        }

        // If both fail, check if permanently denied
        if (photosPermission.isPermanentlyDenied ||
            storagePermission.isPermanentlyDenied) {
          throw Exception(
            'Storage permission permanently denied. Please enable it in app settings.',
          );
        }

        return false;
      }

      return true; // For non-Android platforms
    } catch (e) {
      print('Error requesting storage permission: $e');
      return false;
    }
  }

  /// Pick photos from gallery with improved permission handling
  static Future<List<File>> pickPhotosFromGallery({int maxImages = 5}) async {
    try {
      final hasPermission = await _requestStoragePermission();

      if (!hasPermission) {
        throw Exception('Storage permission denied');
      }

      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      // Limit the number of images
      final limitedImages = images.take(maxImages).toList();

      return limitedImages.map((image) => File(image.path)).toList();
    } catch (e) {
      throw Exception('Error picking photos from gallery: $e');
    }
  }

  /// Get photo file size in MB
  static Future<double> getPhotoSizeInMB(File file) async {
    final int bytes = await file.length();
    return bytes / (1024 * 1024);
  }

  /// Validate photo size (max 10MB as per backend implementation)
  static bool isPhotoSizeValid(File file, {double maxSizeMB = 10.0}) {
    return file.lengthSync() <= (maxSizeMB * 1024 * 1024);
  }

  /// Open app settings for permission management
  static Future<void> openPermissionSettings() async {
    await openAppSettings();
  }
}
