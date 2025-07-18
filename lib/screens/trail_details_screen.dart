import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../models/trail.dart';
import '../services/trail_service.dart';
import '../utils/app_constants.dart';

class TrailDetailsScreen extends StatefulWidget {
  final Trail trail;
  final String username;
  final String jwtToken;

  const TrailDetailsScreen({
    super.key,
    required this.trail,
    required this.username,
    required this.jwtToken,
  });

  @override
  State<TrailDetailsScreen> createState() => _TrailDetailsScreenState();
}

class _TrailDetailsScreenState extends State<TrailDetailsScreen> {
  GoogleMapController? _mapController;
  final TextEditingController _observationController = TextEditingController();
  
  bool _isLoading = false;
  late Trail _currentTrail;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _currentTrail = widget.trail;
    _setupMap();
  }

  @override
  void dispose() {
    _observationController.dispose();
    super.dispose();
  }

  void _setupMap() {
    if (_currentTrail.points.isEmpty) return;

    // Create polyline
    final polyline = Polyline(
      polylineId: const PolylineId('trail'),
      points: _currentTrail.points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
      color: AppColors.primaryGreen,
      width: 4,
    );

    // Create markers
    Set<Marker> markers = {};
    
    // Start marker
    final start = _currentTrail.points.first;
    markers.add(
      Marker(
        markerId: const MarkerId('start'),
        position: LatLng(start.latitude, start.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Start'),
      ),
    );

    // End marker
    if (_currentTrail.points.length > 1) {
      final end = _currentTrail.points.last;
      markers.add(
        Marker(
          markerId: const MarkerId('end'),
          position: LatLng(end.latitude, end.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'End'),
        ),
      );
    }

    setState(() {
      _polylines = {polyline};
      _markers = markers;
    });
  }

  void _fitCameraToTrail() {
    if (_currentTrail.points.isEmpty || _mapController == null) return;

    double minLat = _currentTrail.points.first.latitude;
    double maxLat = _currentTrail.points.first.latitude;
    double minLng = _currentTrail.points.first.longitude;
    double maxLng = _currentTrail.points.first.longitude;

    for (final point in _currentTrail.points) {
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
        trailId: _currentTrail.id,
        observation: _observationController.text.trim(),
        jwtToken: widget.jwtToken,
      );

      setState(() {
        _currentTrail = updatedTrail;
      });

      _observationController.clear();
      _showSnackBar('Observation added successfully');
    } catch (e) {
      _showSnackBar('Failed to add observation: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _changeVisibility() async {
    final newVisibility = _currentTrail.visibility == TrailVisibility.PUBLIC
        ? TrailVisibility.PRIVATE
        : TrailVisibility.PUBLIC;

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedTrail = await TrailService.updateVisibility(
        trailId: _currentTrail.id,
        visibility: newVisibility,
        jwtToken: widget.jwtToken,
      );

      setState(() {
        _currentTrail = updatedTrail;
      });

      _showSnackBar(
        'Trail is now ${newVisibility == TrailVisibility.PUBLIC ? 'public' : 'private'}',
      );
    } catch (e) {
      _showSnackBar('Failed to update visibility: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateStatus() async {
    final newStatus = _currentTrail.status == TrailStatus.ACTIVE
        ? TrailStatus.COMPLETED
        : TrailStatus.ACTIVE;

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedTrail = await TrailService.updateStatus(
        trailId: _currentTrail.id,
        status: newStatus,
        jwtToken: widget.jwtToken,
      );

      setState(() {
        _currentTrail = updatedTrail;
      });

      _showSnackBar(
        'Trail marked as ${newStatus == TrailStatus.COMPLETED ? 'completed' : 'active'}',
      );
    } catch (e) {
      _showSnackBar('Failed to update status: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteTrail() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Trail'),
        content: const Text('Are you sure you want to delete this trail? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await TrailService.deleteTrail(
        trailId: _currentTrail.id,
        jwtToken: widget.jwtToken,
      );

      _showSnackBar('Trail deleted successfully');
      Navigator.of(context).pop(true);
    } catch (e) {
      _showSnackBar('Failed to delete trail: $e', isError: true);
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

  @override
  Widget build(BuildContext context) {
    final isOwner = _currentTrail.createdBy == widget.username;
    final canEdit = isOwner || _currentTrail.visibility == TrailVisibility.PUBLIC;

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentTrail.name),
        backgroundColor: AppColors.primaryGreen,
        actions: [
          if (isOwner)
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'visibility':
                    _changeVisibility();
                    break;
                  case 'status':
                    _updateStatus();
                    break;
                  case 'delete':
                    _deleteTrail();
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'visibility',
                  child: Text(
                    _currentTrail.visibility == TrailVisibility.PUBLIC
                        ? 'Make Private'
                        : 'Make Public',
                  ),
                ),
                if (_currentTrail.visibility == TrailVisibility.PRIVATE)
                  PopupMenuItem(
                    value: 'status',
                    child: Text(
                      _currentTrail.status == TrailStatus.ACTIVE
                          ? 'Mark as Completed'
                          : 'Mark as Active',
                    ),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'Delete Trail',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Trail info
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _currentTrail.name,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'by ${isOwner ? 'You' : _currentTrail.createdBy}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildStatusChip(),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      Row(
                        children: [
                          _buildInfoChip(
                            Icons.calendar_today,
                            _currentTrail.formattedDate,
                          ),
                          const SizedBox(width: 12),
                          _buildInfoChip(
                            Icons.route,
                            '${_currentTrail.points.length} points',
                          ),
                          const SizedBox(width: 12),
                          _buildInfoChip(
                            Icons.straighten,
                            _formatDistance(_currentTrail.totalDistance),
                          ),
                        ],
                      ),
                      
                      if (_currentTrail.observations.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildInfoChip(
                          Icons.comment,
                          '${_currentTrail.observations.length} observation${_currentTrail.observations.length == 1 ? '' : 's'}',
                        ),
                      ],
                      
                      if (_currentTrail.worksheetProximities.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildInfoChip(
                          Icons.warning_amber,
                          '${_currentTrail.worksheetProximities.length} proximity alert${_currentTrail.worksheetProximities.length == 1 ? '' : 's'}',
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Worksheet Proximities Section
                if (_currentTrail.worksheetProximities.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.warning_amber,
                              color: Colors.orange.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Transformation Zone Proximities',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...(_currentTrail.worksheetProximities.map((proximity) => 
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  proximity.worksheetName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'POSP: ${proximity.posp}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Distance: ${proximity.distanceKm.toStringAsFixed(2)} km',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.orange.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )),
                      ],
                    ),
                  ),
                ],
                
                // Map
                Expanded(
                  flex: 2,
                  child: _currentTrail.points.isEmpty
                      ? const Center(
                          child: Text('No trail data available'),
                        )
                      : GoogleMap(
                          onMapCreated: (controller) {
                            _mapController = controller;
                            Future.delayed(const Duration(milliseconds: 500), () {
                              _fitCameraToTrail();
                            });
                          },
                          initialCameraPosition: CameraPosition(
                            target: LatLng(
                              _currentTrail.points.first.latitude,
                              _currentTrail.points.first.longitude,
                            ),
                            zoom: 14,
                          ),
                          polylines: _polylines,
                          markers: _markers,
                          mapType: MapType.hybrid,
                        ),
                ),
                
                // Observations
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Add observation section
                        if (canEdit) ...[
                          Container(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
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
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: _addObservation,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryGreen,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Add'),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                        ],
                        
                        // Observations list
                        Expanded(
                          child: _currentTrail.observations.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No observations yet',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(16.0),
                                  itemCount: _currentTrail.observations.length,
                                  itemBuilder: (context, index) {
                                    final observation = _currentTrail.observations[index];
                                    return _buildObservationCard(observation);
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatusChip() {
    Color backgroundColor;
    Color textColor;
    String text;

    if (_currentTrail.visibility == TrailVisibility.PUBLIC) {
      backgroundColor = Colors.green.shade100;
      textColor = Colors.green.shade800;
      text = 'Public';
    } else {
      switch (_currentTrail.status) {
        case TrailStatus.ACTIVE:
          backgroundColor = Colors.blue.shade100;
          textColor = Colors.blue.shade800;
          text = 'Active';
          break;
        case TrailStatus.COMPLETED:
          backgroundColor = Colors.orange.shade100;
          textColor = Colors.orange.shade800;
          text = 'Completed';
          break;
        default:
          backgroundColor = Colors.grey.shade100;
          textColor = Colors.grey.shade800;
          text = 'Private';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildObservationCard(TrailObservation observation) {
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
                  observation.username,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryGreen,
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('MMM dd, HH:mm').format(observation.timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              observation.observation,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDistance(double distance) {
    if (distance > 1000) {
      return '${(distance / 1000).toStringAsFixed(2)} km';
    } else {
      return '${distance.toStringAsFixed(0)} m';
    }
  }
}