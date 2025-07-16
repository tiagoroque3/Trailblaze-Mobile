import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:trailblaze_app/models/activity.dart';
import 'package:trailblaze_app/services/execution_sheet_service.dart';
import 'package:trailblaze_app/utils/app_constants.dart';

class PoActivityDetailsScreen extends StatefulWidget {
  final Activity activity;
  final String jwtToken;
  final bool canEdit;

  const PoActivityDetailsScreen({
    super.key,
    required this.activity,
    required this.jwtToken,
    this.canEdit = false,
  });

  @override
  State<PoActivityDetailsScreen> createState() => _PoActivityDetailsScreenState();
}

class _PoActivityDetailsScreenState extends State<PoActivityDetailsScreen> {
  final TextEditingController _observationsController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  List<String> _photoUrls = [];
  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _observationsController.text = widget.activity.observations ?? '';
    _photoUrls = List.from(widget.activity.photoUrls);
    
    _observationsController.addListener(() {
      setState(() {
        _hasChanges = true;
      });
    });
  }

  @override
  void dispose() {
    _observationsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        // In a real app, you would upload the image to your server
        // and get back a URL. For now, we'll use the local path.
        setState(() {
          _photoUrls.add(image.path);
          _hasChanges = true;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error picking image: $e');
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _photoUrls.add(image.path);
          _hasChanges = true;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error picking image: $e');
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _photoUrls.removeAt(index);
      _hasChanges = true;
    });
  }

  Future<void> _saveChanges() async {
    if (!_hasChanges) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await ExecutionSheetService.addActivityInfo(
        activityId: widget.activity.id,
        observations: _observationsController.text.trim().isEmpty 
            ? null 
            : _observationsController.text.trim(),
        photos: _photoUrls.isEmpty ? null : _photoUrls,
        jwtToken: widget.jwtToken,
      );

      if (success) {
        _showSuccessSnackBar('Activity updated successfully');
        setState(() {
          _hasChanges = false;
        });
      } else {
        _showErrorSnackBar('Failed to update activity');
      }
    } catch (e) {
      _showErrorSnackBar('Error updating activity: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showImageOptions() {
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
                  _pickImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromGallery();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildActivityInfo() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Activity Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Operator', widget.activity.operatorId),
            _buildInfoRow('Start Time', _formatDateTime(widget.activity.startTime)),
            _buildInfoRow('End Time', 
                widget.activity.endTime != null 
                    ? _formatDateTime(widget.activity.endTime!)
                    : 'Ongoing'),
            if (widget.activity.duration != null)
              _buildInfoRow('Duration', widget.activity.durationText),
            _buildInfoRow('Status', widget.activity.statusText),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildObservationsSection() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Observations',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _observationsController,
              enabled: widget.canEdit,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: widget.canEdit 
                    ? 'Add your observations about this activity...'
                    : 'No observations recorded',
                border: const OutlineInputBorder(),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primaryGreen),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotosSection() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Photos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
                  ),
                ),
                if (widget.canEdit)
                  IconButton(
                    onPressed: _showImageOptions,
                    icon: const Icon(Icons.add_a_photo),
                    color: AppColors.primaryGreen,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_photoUrls.isEmpty)
              const Center(
                child: Text(
                  'No photos attached',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _photoUrls.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey[200],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            _photoUrls[index],
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[300],
                                child: const Icon(
                                  Icons.image_not_supported,
                                  color: Colors.grey,
                                  size: 40,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      if (widget.canEdit)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removePhoto(index),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Details'),
        backgroundColor: AppColors.primaryGreen,
        actions: [
          if (widget.canEdit && _hasChanges)
            IconButton(
              onPressed: _isLoading ? null : _saveChanges,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.save),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildActivityInfo(),
            _buildObservationsSection(),
            _buildPhotosSection(),
          ],
        ),
      ),
    );
  }
}