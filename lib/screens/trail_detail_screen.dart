import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../models/trail.dart';
import '../services/trail_service.dart';
import '../utils/app_constants.dart';

class TrailDetailScreen extends StatefulWidget {
  final Trail trail;
  final String jwtToken;
  final String username;

  const TrailDetailScreen({
    super.key,
    required this.trail,
    required this.jwtToken,
    required this.username,
  });

  @override
  State<TrailDetailScreen> createState() => _TrailDetailScreenState();
}

class _TrailDetailScreenState extends State<TrailDetailScreen> {
  late Trail _trail;
  GoogleMapController? _mapController;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  bool _isLoading = false;

  final _observationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _trail = widget.trail;
    _setupMapData();
  }

  @override
  void dispose() {
    _observationController.dispose();
    super.dispose();
  }

  void _setupMapData() {
    if (_trail.points.isEmpty) return;

    // Create polyline from trail points
    final polylinePoints = _trail.points
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('trail'),
          points: polylinePoints,
          color: AppColors.primaryGreen,
          width: 4,
        ),
      };

      // Add start and end markers
      _markers = {
        Marker(
          markerId: const MarkerId('start'),
          position: LatLng(
            _trail.points.first.latitude,
            _trail.points.first.longitude,
          ),
          infoWindow: InfoWindow(
            title: 'Start',
            snippet: DateFormat('HH:mm').format(_trail.points.first.timestamp),
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
        if (_trail.points.length > 1)
          Marker(
            markerId: const MarkerId('end'),
            position: LatLng(
              _trail.points.last.latitude,
              _trail.points.last.longitude,
            ),
            infoWindow: InfoWindow(
              title: 'End',
              snippet: DateFormat('HH:mm').format(_trail.points.last.timestamp),
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          ),
      };
    });
  }

  Future<void> _addObservation() async {
    if (_observationController.text.trim().isEmpty) {
      _showSnackBar('Please enter an observation', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedTrail = await TrailService.addObservation(
        jwtToken: widget.jwtToken,
        trailId: _trail.id,
        observation: _observationController.text.trim(),
      );

      setState(() {
        _trail = updatedTrail;
      });

      _observationController.clear();
      _showSnackBar('Observation added successfully');
    } catch (e) {
      _showSnackBar('Error adding observation: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateVisibility(TrailVisibility newVisibility) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final updatedTrail = await TrailService.updateVisibility(
        jwtToken: widget.jwtToken,
        trailId: _trail.id,
        visibility: newVisibility,
      );

      setState(() {
        _trail = updatedTrail;
      });

      _showSnackBar('Visibility updated successfully');
    } catch (e) {
      _showSnackBar('Error updating visibility: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateStatus(TrailStatus newStatus) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final updatedTrail = await TrailService.updateStatus(
        jwtToken: widget.jwtToken,
        trailId: _trail.id,
        status: newStatus,
      );

      setState(() {
        _trail = updatedTrail;
      });

      _showSnackBar('Status updated successfully');
    } catch (e) {
      _showSnackBar('Error updating status: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  void _fitCameraToTrail() {
    if (_trail.points.isEmpty || _mapController == null) return;

    double minLat = _trail.points.first.latitude;
    double maxLat = _trail.points.first.latitude;
    double minLng = _trail.points.first.longitude;
    double maxLng = _trail.points.first.longitude;

    for (final point in _trail.points) {
      minLat = minLat < point.latitude ? minLat : point.latitude;
      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
      minLng = minLng < point.longitude ? minLng : point.longitude;
      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        100.0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMyTrail = _trail.createdBy == widget.username;
    final canEdit = _trail.canBeEditedBy(widget.username);

    return Scaffold(
      appBar: AppBar(
        title: Text(_trail.name),
        backgroundColor: AppColors.primaryGreen,
        actions: [
          if (isMyTrail)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'visibility') {
                  _showVisibilityDialog();
                } else if (value == 'status' && 
                          _trail.visibility == TrailVisibility.PRIVATE) {
                  _showStatusDialog();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'visibility',
                  child: Row(
                    children: [
                      Icon(Icons.visibility, size: 20),
                      SizedBox(width: 8),
                      Text('Change Visibility'),
                    ],
                  ),
                ),
                if (_trail.visibility == TrailVisibility.PRIVATE)
                  const PopupMenuItem(
                    value: 'status',
                    child: Row(
                      children: [
                        Icon(Icons.flag, size: 20),
                        SizedBox(width: 8),
                        Text('Change Status'),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // Trail info card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _trail.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ),
                        _buildVisibilityChip(_trail.visibility),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow('Created by:', _trail.createdBy),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      'Created on:',
                      DateFormat('MMM dd, yyyy HH:mm').format(_trail.createdAt),
                    ),
                    if (_trail.worksheetId != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.assignment, color: Colors.blue.shade700, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Associated with Worksheet #${_trail.worksheetId}',
                              style: TextStyle(
                                color: Colors.blue.shade800,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_trail.visibility == TrailVisibility.PRIVATE && 
                        _trail.status != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text(
                            'Status: ',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                          _buildStatusChip(_trail.status!),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn('Distance', _trail.formattedDistance),
                        _buildStatColumn('Duration', _trail.formattedDuration),
                        _buildStatColumn('Points', '${_trail.points.length}'),
                        _buildStatColumn('Notes', '${_trail.observations.length}'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Map
          Expanded(
            child: _trail.points.isEmpty
                ? const Center(
                    child: Text(
                      'No trail data to display',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : Stack(
                    children: [
                      GoogleMap(
                        onMapCreated: (controller) {
                          _mapController = controller;
                          Future.delayed(
                            const Duration(milliseconds: 500),
                            _fitCameraToTrail,
                          );
                        },
                        initialCameraPosition: CameraPosition(
                          target: LatLng(
                            _trail.points.first.latitude,
                            _trail.points.first.longitude,
                          ),
                          zoom: 15,
                        ),
                        polylines: _polylines,
                        markers: _markers,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                      ),
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: FloatingActionButton(
                          mini: true,
                          onPressed: _fitCameraToTrail,
                          backgroundColor: AppColors.primaryGreen,
                          child: const Icon(Icons.center_focus_strong, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
          ),

          // Observations section
          if (canEdit || _trail.observations.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: Card(
                margin: const EdgeInsets.all(16.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Observations (${_trail.observations.length})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (canEdit) ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _observationController,
                                decoration: const InputDecoration(
                                  hintText: 'Add an observation...',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                maxLines: 2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _isLoading ? null : _addObservation,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen,
                                foregroundColor: Colors.white,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text('Add'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      Expanded(
                        child: _trail.observations.isEmpty
                            ? const Center(
                                child: Text(
                                  'No observations yet',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _trail.observations.length,
                                itemBuilder: (context, index) {
                                  final obs = _trail.observations[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                obs.username,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.primaryGreen,
                                                ),
                                              ),
                                              const Spacer(),
                                              Text(
                                                DateFormat('MMM dd, HH:mm')
                                                    .format(obs.timestamp),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(obs.observation),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.primaryGreen,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(value)),
      ],
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryGreen,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildVisibilityChip(TrailVisibility visibility) {
    final isPublic = visibility == TrailVisibility.PUBLIC;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isPublic ? Colors.green.shade100 : Colors.orange.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPublic ? Icons.public : Icons.lock,
            size: 12,
            color: isPublic ? Colors.green.shade800 : Colors.orange.shade800,
          ),
          const SizedBox(width: 4),
          Text(
            isPublic ? 'Public' : 'Private',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isPublic ? Colors.green.shade800 : Colors.orange.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(TrailStatus status) {
    Color backgroundColor;
    Color textColor;

    switch (status) {
      case TrailStatus.ACTIVE:
        backgroundColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        break;
      case TrailStatus.COMPLETED:
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        break;
      case TrailStatus.PAUSED:
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.name.toLowerCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  void _showVisibilityDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Visibility'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: TrailVisibility.values.map((visibility) {
            return RadioListTile<TrailVisibility>(
              title: Row(
                children: [
                  Icon(
                    visibility == TrailVisibility.PUBLIC
                        ? Icons.public
                        : Icons.lock,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(visibility.name.toLowerCase()),
                ],
              ),
              value: visibility,
              groupValue: _trail.visibility,
              onChanged: (value) {
                Navigator.of(context).pop();
                if (value != null && value != _trail.visibility) {
                  _updateVisibility(value);
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showStatusDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: TrailStatus.values.map((status) {
            return RadioListTile<TrailStatus>(
              title: Text(status.name.toLowerCase()),
              value: status,
              groupValue: _trail.status,
              onChanged: (value) {
                Navigator.of(context).pop();
                if (value != null && value != _trail.status) {
                  _updateStatus(value);
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}