import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:trailblaze_app/models/parcel_operation_execution.dart';
import 'package:trailblaze_app/services/execution_service.dart';
import 'package:trailblaze_app/utils/app_constants.dart';
import 'package:trailblaze_app/utils/map_utils.dart';

class PoLiveTrackingMapScreen extends StatefulWidget {
  final ParcelOperationExecution parcelOperation;
  final String jwtToken;
  final String assignedWorkSheetId;

  const PoLiveTrackingMapScreen({
    super.key,
    required this.parcelOperation,
    required this.jwtToken,
    required this.assignedWorkSheetId,
  });

  @override
  State<PoLiveTrackingMapScreen> createState() =>
      _PoLiveTrackingMapScreenState();
}

class _PoLiveTrackingMapScreenState extends State<PoLiveTrackingMapScreen> {
  GoogleMapController? _mapController;
  final Set<Polygon> _polygons = {};
  final Set<Marker> _markers = {};
  bool _isInsideParcel = false;
  String _statusMessage = 'Checking location...';
  StreamSubscription<Position>? _positionStreamSubscription;

  @override
  void initState() {
    super.initState();
    _initializeMapAndTracking();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeMapAndTracking() async {
    await _fetchParcelGeometry();
    await _startLocationTracking();
  }

  Future<void> _fetchParcelGeometry() async {
    try {
      if (widget.parcelOperation.operationExecution == null) {
        _showSnackBar('Operation details are missing.', isError: true);
        return;
      }

      final String parcelId = widget.parcelOperation.parcelId.toString();

      final geometry = await ExecutionService.fetchParcelGeometry(
        jwtToken: widget.jwtToken,
        worksheetId: widget.assignedWorkSheetId,
        parcelId: parcelId,
      );

      if (mounted && geometry.isNotEmpty) {
        setState(() {
          final parcelPolygon = Polygon(
            polygonId: PolygonId(widget.parcelOperation.parcelId),
            points: geometry,
            strokeColor: AppColors.primaryGreen,
            strokeWidth: 2,
            fillColor: AppColors.primaryGreen.withOpacity(0.2),
          );
          _polygons.add(parcelPolygon);
        });
        _fitCameraToPolygon(geometry);
      } else if (mounted) {
        _showSnackBar('Could not load parcel boundary.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Failed to load parcel boundary: $e', isError: true);
    }
  }

  Future<void> _startLocationTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _setStatus('Location services are disabled.', isError: true);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _setStatus('Location permission denied.', isError: true);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _setStatus(
          'Location permissions are permanently denied, we cannot request permissions.',
          isError: true);
      return;
    }

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
      if (!mounted) return;

      final currentLatLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _markers.removeWhere((m) => m.markerId.value == 'userLocation');
        _markers.add(
          Marker(
            markerId: const MarkerId('userLocation'),
            position: currentLatLng,
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure),
            infoWindow: const InfoWindow(title: 'Your Location'),
          ),
        );
      });

      if (_polygons.isNotEmpty) {
        final polygonPoints = _polygons.first.points;
        final isInside = MapUtils.isPointInPolygon(currentLatLng, polygonPoints);
        _setStatus(
            isInside
                ? 'You are inside the parcel.'
                : 'WARNING: You are outside the parcel!',
            isError: !isInside);
      }
    });
  }

  void _fitCameraToPolygon(List<LatLng> polygonPoints) {
    if (polygonPoints.isEmpty || _mapController == null) return;

    LatLngBounds bounds = MapUtils.boundsFromLatLngList(polygonPoints);
    _mapController!
        .animateCamera(CameraUpdate.newLatLngBounds(bounds, 50.0));
  }

  void _setStatus(String message, {bool isError = false}) {
    if (mounted) {
      setState(() {
        _statusMessage = message;
        _isInsideParcel = !isError;
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text('Live Tracking - Parcel ${widget.parcelOperation.parcelId}'),
        backgroundColor: AppColors.primaryGreen,
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
              // After map is created, we can try to fit the camera if the polygon is already loaded
              if (_polygons.isNotEmpty) {
                _fitCameraToPolygon(_polygons.first.points);
              }
            },
            initialCameraPosition: const CameraPosition(
              target: LatLng(38.7223, -9.1393), // Default to Lisbon
              zoom: 14,
            ),
            polygons: _polygons,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(12),
              color: _isInsideParcel
                  ? Colors.green.withOpacity(0.8)
                  : Colors.red.withOpacity(0.8),
              child: Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
