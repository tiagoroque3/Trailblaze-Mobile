import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../services/photo_service.dart';

class PhotoGalleryWidget extends StatefulWidget {
  final List<String> photoUrls;
  final String jwtToken;
  final String activityId;
  final bool canEdit;
  final Function(List<String>)? onPhotosUpdated;

  const PhotoGalleryWidget({
    super.key,
    required this.photoUrls,
    required this.jwtToken,
    required this.activityId,
    this.canEdit = false,
    this.onPhotosUpdated,
  });

  @override
  State<PhotoGalleryWidget> createState() => _PhotoGalleryWidgetState();
}

class _PhotoGalleryWidgetState extends State<PhotoGalleryWidget> {
  List<String> _currentPhotoUrls = [];
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _currentPhotoUrls = _cleanPhotoUrls(widget.photoUrls);
  }

  /// Clean and normalize photo URLs
  List<String> _cleanPhotoUrls(List<String> photoUrls) {
    List<String> cleanUrls = [];

    for (String url in photoUrls) {
      if (url.trim().startsWith('{') && url.trim().endsWith('}')) {
        try {
          // Parse JSON and extract photoUrl
          var jsonMap = jsonDecode(url);
          if (jsonMap['photoUrl'] != null) {
            cleanUrls.add(jsonMap['photoUrl'].toString());
          }
        } catch (e) {
          // If parsing fails, treat as regular URL
          cleanUrls.add(url);
        }
      } else {
        // Regular URL string
        cleanUrls.add(url);
      }
    }

    return cleanUrls;
  }

  Future<void> _takePhoto() async {
    try {
      setState(() => _isUploading = true);

      final File? photo = await PhotoService.takePhoto();
      if (photo != null) {
        await _uploadAndAddPhoto(photo);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error taking photo: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _pickPhotosFromGallery() async {
    try {
      setState(() => _isUploading = true);

      final List<File> photos = await PhotoService.pickPhotosFromGallery(
        maxImages: 5,
      );

      for (final photo in photos) {
        await _uploadAndAddPhoto(photo);
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString();

        // Show specific dialog for permission errors
        if (errorMessage.contains('permission') ||
            errorMessage.contains('Permission')) {
          _showPermissionDialog();
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error picking photos: $e')));
        }
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permission Required'),
          content: const Text(
            'This app needs access to your photos to upload images. '
            'Please grant permission in your device settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await PhotoService.openPermissionSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _uploadAndAddPhoto(File photo) async {
    try {
      // Validate photo size
      if (!PhotoService.isPhotoSizeValid(photo)) {
        throw Exception('Photo is too large (max 10MB)');
      }

      // Upload photo
      final String photoUrl = await PhotoService.uploadPhoto(
        imageFile: photo,
        jwtToken: widget.jwtToken,
      );

      // Add to activity
      final bool success = await PhotoService.addPhotosToActivity(
        activityId: widget.activityId,
        photoUrls: [photoUrl],
        jwtToken: widget.jwtToken,
      );

      if (success) {
        setState(() {
          _currentPhotoUrls.add(photoUrl);
        });
        widget.onPhotosUpdated?.call(_currentPhotoUrls);
      } else {
        throw Exception('Failed to add photo to activity');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error uploading photo: $e')));
      }
    }
  }

  Future<void> _deletePhoto(String photoUrl) async {
    try {
      final bool success = await PhotoService.deletePhotoFromActivity(
        activityId: widget.activityId,
        photoUrl: photoUrl,
        jwtToken: widget.jwtToken,
      );

      if (success) {
        setState(() {
          _currentPhotoUrls.remove(photoUrl);
        });
        widget.onPhotosUpdated?.call(_currentPhotoUrls);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo deleted successfully')),
          );
        }
      } else {
        throw Exception('Failed to delete photo');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting photo: $e')));
      }
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickPhotosFromGallery();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _viewPhoto(String photoUrl, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoViewScreen(
          photoUrls: _currentPhotoUrls,
          initialIndex: index,
          canEdit: widget.canEdit,
          onDeletePhoto: _deletePhoto,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Photos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4F695B),
                  ),
                ),
                const Spacer(),
                if (widget.canEdit) ...[
                  if (_isUploading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.add_a_photo),
                      onPressed: _showPhotoOptions,
                      color: const Color(0xFF4F695B),
                    ),
                ],
                Text(
                  '${_currentPhotoUrls.length} photo(s)',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_currentPhotoUrls.isEmpty)
              Container(
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.photo_library,
                        size: 32,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.canEdit
                            ? 'Tap + to add photos'
                            : 'No photos available',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _currentPhotoUrls.length,
                itemBuilder: (context, index) {
                  final photoUrl = _currentPhotoUrls[index];
                  return GestureDetector(
                    onTap: () => _viewPhoto(photoUrl, index),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: photoUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            placeholder: (context, url) => Container(
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.error),
                            ),
                          ),
                        ),
                        if (widget.canEdit)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _deletePhoto(photoUrl),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class PhotoViewScreen extends StatefulWidget {
  final List<String> photoUrls;
  final int initialIndex;
  final bool canEdit;
  final Function(String)? onDeletePhoto;

  const PhotoViewScreen({
    super.key,
    required this.photoUrls,
    this.initialIndex = 0,
    this.canEdit = false,
    this.onDeletePhoto,
  });

  @override
  State<PhotoViewScreen> createState() => _PhotoViewScreenState();
}

class _PhotoViewScreenState extends State<PhotoViewScreen> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _deleteCurrentPhoto() {
    if (widget.canEdit && widget.onDeletePhoto != null) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Delete Photo'),
            content: const Text('Are you sure you want to delete this photo?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onDeletePhoto!(widget.photoUrls[_currentIndex]);
                  Navigator.pop(context);
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_currentIndex + 1} of ${widget.photoUrls.length}',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          if (widget.canEdit)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: _deleteCurrentPhoto,
            ),
        ],
      ),
      body: PhotoViewGallery.builder(
        scrollPhysics: const BouncingScrollPhysics(),
        builder: (BuildContext context, int index) {
          return PhotoViewGalleryPageOptions(
            imageProvider: CachedNetworkImageProvider(widget.photoUrls[index]),
            initialScale: PhotoViewComputedScale.contained,
            minScale: PhotoViewComputedScale.contained * 0.8,
            maxScale: PhotoViewComputedScale.covered * 2,
          );
        },
        itemCount: widget.photoUrls.length,
        loadingBuilder: (context, event) =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        pageController: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
