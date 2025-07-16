import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/parcel.dart';
import '../services/parcel_service.dart';
import 'dart:convert';
import 'dart:math' as math;

/// Represents the screen dedicated to displaying the map with worksheet polygons.
/// This screen is accessible to all users, regardless of login status.
class MapScreen extends StatefulWidget {
  final String? username;
  final String? jwtToken;

  const MapScreen({
    super.key,
    this.username,
    this.jwtToken,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Controller for the Google Map instance.
  GoogleMapController? _mapController;
  // Stores the user's current location.
  LatLng? _currentLocation;
  // Marker to display the user's current location on the map.
  Marker? _userLocationMarker;
  // State to manage the loading indicator during location search.
  bool _isLoadingLocation = false;
  // State to manage loading of worksheets.
  bool _isLoadingWorksheets = false;
  // List of worksheets from backend
  List<Map<String, dynamic>> _worksheets = [];
  // Set of polygons to display on the map.
  Set<Polygon> _polygons = {};
  // Default location (Lisbon, Portugal)
  static const LatLng _defaultLocation = LatLng(38.7223, -9.1393);
  // Current map type
  MapType _currentMapType = MapType.normal;
  // Selected worksheet
  int? _selectedWorksheetId;
  // Panel visibility for mobile
  bool _isPanelVisible = false;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  /// Initialize map by getting location and loading worksheets
  Future<void> _initializeMap() async {
    // First get user location
    await _getCurrentLocationSilently();
    // Then load worksheets and select nearest one
    await _loadWorksheets();
  }

  /// Get current location without showing loading indicator
  Future<void> _getCurrentLocationSilently() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _userLocationMarker = Marker(
          markerId: const MarkerId('userLocation'),
          position: _currentLocation!,
          infoWindow: const InfoWindow(title: 'Your Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        );
      });
    } catch (e) {
      print('Error getting location silently: $e');
      // Use default location if can't get current location
      setState(() {
        _currentLocation = _defaultLocation;
      });
    }
  }

  /// Calculate distance between two points in kilometers
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    double lat1Rad = point1.latitude * (math.pi / 180);
    double lat2Rad = point2.latitude * (math.pi / 180);
    double deltaLatRad = (point2.latitude - point1.latitude) * (math.pi / 180);
    double deltaLngRad = (point2.longitude - point1.longitude) * (math.pi / 180);

    double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.sin(deltaLngRad / 2) * math.sin(deltaLngRad / 2);
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  /// Calculate the center point of a worksheet's polygons
  LatLng? _calculateWorksheetCenter(Map<String, dynamic> worksheet) {
    List<Parcel> parcels = List<Parcel>.from(worksheet['parcels'] ?? []);
    if (parcels.isEmpty) return null;

    double totalLat = 0;
    double totalLng = 0;
    int totalPoints = 0;

    for (final parcel in parcels) {
      for (final coord in parcel.coordinates) {
        double lat = coord[0];
        double lng = coord[1];
        
        // Only consider valid coordinates
        if (lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
          totalLat += lat;
          totalLng += lng;
          totalPoints++;
        }
      }
    }

    if (totalPoints == 0) return null;

    return LatLng(totalLat / totalPoints, totalLng / totalPoints);
  }

  /// Find the nearest worksheet to current location
  int? _findNearestWorksheet() {
    if (_currentLocation == null || _worksheets.isEmpty) return null;

    double minDistance = double.infinity;
    int? nearestWorksheetId;

    for (final worksheet in _worksheets) {
      LatLng? worksheetCenter = _calculateWorksheetCenter(worksheet);
      if (worksheetCenter != null) {
        double distance = _calculateDistance(_currentLocation!, worksheetCenter);
        if (distance < minDistance) {
          minDistance = distance;
          nearestWorksheetId = worksheet['id'];
        }
      }
    }

    return nearestWorksheetId;
  }

  /// Loads worksheets from server or example data.
  Future<void> _loadWorksheets() async {
    setState(() {
      _isLoadingWorksheets = true;
    });

    // List of authorized roles
    const allowedRoles = [
      'SMBO', 'SDVBO', 'SGVBO', 'RU', 'ADLU', 'PO', 'PRBO', 'SYSADMIN', 'SYSBO'
    ];

    // Extract roles from JWT
    List<String> userRoles = _extractRolesFromJwt(widget.jwtToken);

    // Check if user has at least one authorized role
    bool hasAccess = userRoles.any((role) => allowedRoles.contains(role));

    if (!hasAccess) {
      setState(() {
        _worksheets = ParcelService.getMockWorksheets();
        _isLoadingWorksheets = false;
      });
      // Select nearest worksheet
      _selectedWorksheetId = _findNearestWorksheet() ?? (_worksheets.isNotEmpty ? _worksheets.first['id'] : null);
      _createPolygons();
      _showSnackBar('Insufficient permissions to load worksheet details.', isError: true);
      return;
    }

    try {
      // Fetch worksheets from server
      final result = await ParcelService.fetchWorksheetsWithParcels(
        jwtToken: widget.jwtToken,
      );

      List<Map<String, dynamic>> worksheets = List<Map<String, dynamic>>.from(result['worksheets'] ?? []);

      // Use example data if can't get data from server
      if (worksheets.isEmpty) {
        worksheets = ParcelService.getMockWorksheets();
        _showSnackBar('Using example worksheet data');
      }

      setState(() {
        _worksheets = worksheets;
        _isLoadingWorksheets = false;
      });
      
      // Select nearest worksheet to user location
      _selectedWorksheetId = _findNearestWorksheet() ?? (_worksheets.isNotEmpty ? _worksheets.first['id'] : null);
      _createPolygons();
      
    } catch (e) {
      print('Error loading worksheets: $e');
      // In case of error, use example data
      setState(() {
        _worksheets = ParcelService.getMockWorksheets();
        _isLoadingWorksheets = false;
      });
      _selectedWorksheetId = _findNearestWorksheet() ?? (_worksheets.isNotEmpty ? _worksheets.first['id'] : null);
      _createPolygons();
      _showSnackBar('Error loading server data. Using example data.', isError: true);
    }
  }

  /// Formats ISO date for display
  String _formatDate(String? isoDate) {
    if (isoDate == null) return 'N/A';
    try {
      DateTime date = DateTime.parse(isoDate);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  /// Helper function to extract roles from JWT
  List<String> _extractRolesFromJwt(String? jwtToken) {
    if (jwtToken == null) return [];

    final parts = jwtToken.split('.');
    if (parts.length != 3) return [];

    final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));

    if (payload['roles'] is List) {
      return List<String>.from(payload['roles']);
    } else if (payload['role'] is String) {
      return [payload['role']];
    }

    return [];
  }

  /// Creates polygons from loaded worksheets.
  void _createPolygons() {
    print('\n=== CREATING POLYGONS ===');
    
    Set<Polygon> polygons = {};
    int polygonsCreated = 0;
    int polygonsSkipped = 0;

    // Filter worksheets based on selected worksheet
    List<Parcel> parcelsToShow = [];
    if (_selectedWorksheetId != null) {
      var selectedWorksheetData = _worksheets.firstWhere(
        (w) => w['id'] == _selectedWorksheetId,
        orElse: () => {},
      );
      if (selectedWorksheetData.isNotEmpty) {
        parcelsToShow = List<Parcel>.from(selectedWorksheetData['parcels'] ?? []);
      }
    }

    print('Processing ${parcelsToShow.length} polygons for worksheet $_selectedWorksheetId');

    for (int i = 0; i < parcelsToShow.length; i++) {
      final parcel = parcelsToShow[i];
      
      // Validate coordinates before creating polygon
      if (parcel.coordinates.length < 3) {
        print('⚠️ Polygon ${parcel.id} has only ${parcel.coordinates.length} coordinates (minimum 3), ignoring');
        polygonsSkipped++;
        continue;
      }
      
      // Convert coordinates to LatLng
      List<LatLng> polygonPoints = parcel.coordinates
          .map((coord) {
            double lat = coord[0];
            double lng = coord[1];
            
            // Additional validation
            if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
              print('⚠️ Invalid coordinate ignored: [$lat, $lng] in polygon ${parcel.id}');
              return LatLng(38.7223, -9.1393); // Lisbon as fallback
            }
            
            return LatLng(lat, lng);
          })
          .toList();
      
      // Define alternating colors if not specified
      Color polygonColor;
      if (parcel.color != null) {
        polygonColor = _hexToColor(parcel.color!);
      } else {
        // Alternating colors
        List<Color> colors = [
          Colors.green.withOpacity(0.4),
          Colors.blue.withOpacity(0.4),
          Colors.orange.withOpacity(0.4),
          Colors.purple.withOpacity(0.4),
          Colors.red.withOpacity(0.4),
        ];
        polygonColor = colors[i % colors.length];
      }

      polygons.add(
        Polygon(
          polygonId: PolygonId(parcel.id),
          points: polygonPoints,
          fillColor: polygonColor,
          strokeColor: polygonColor.withOpacity(0.8),
          strokeWidth: 2,
          consumeTapEvents: true,
          onTap: () => _onPolygonTapped(parcel),
        ),
      );

      polygonsCreated++;
    }

    print('\n=== POLYGON CREATION SUMMARY ===');
    print('Polygons created: $polygonsCreated');
    print('Polygons ignored: $polygonsSkipped');
    print('Total on map: ${polygons.length}');
    print('=====================================');

    setState(() {
      _polygons = polygons;
    });
    
    // If we have polygons, adjust camera to show all
    if (polygons.isNotEmpty && _mapController != null) {
      print('Adjusting camera to show all polygons...');
      _fitCameraToPolygons();
    }
  }

  /// Converts a hexadecimal string to Color.
  Color _hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16)).withOpacity(0.4);
  }

  /// Callback when a polygon is tapped.
  void _onPolygonTapped(Parcel parcel) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(parcel.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ID: ${parcel.id}'),
              const SizedBox(height: 8),
              Text('Description: ${parcel.description}'),
              const SizedBox(height: 8),
              Text('Coordinates: ${parcel.coordinates.length} points'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            if (widget.jwtToken != null)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _centerMapOnParcel(parcel);
                },
                child: const Text('Center on Map'),
              ),
          ],
        );
      },
    );
  }

  /// Centers the map on a specific parcel.
  void _centerMapOnParcel(Parcel parcel) {
    if (_mapController != null && parcel.coordinates.isNotEmpty) {
      // Calculate polygon center
      double avgLat = parcel.coordinates.map((coord) => coord[0]).reduce((a, b) => a + b) / parcel.coordinates.length;
      double avgLng = parcel.coordinates.map((coord) => coord[1]).reduce((a, b) => a + b) / parcel.coordinates.length;
      
      LatLng center = LatLng(avgLat, avgLng);
      
      print('Centering map at: $avgLat, $avgLng');
      
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(center, 16),
      );
    }
  }
  
  /// Adjusts camera to show all polygons
  void _fitCameraToPolygons() {
    List<Parcel> parcelsToShow = [];
    if (_selectedWorksheetId != null) {
      var selectedWorksheetData = _worksheets.firstWhere(
        (w) => w['id'] == _selectedWorksheetId,
        orElse: () => {},
      );
      if (selectedWorksheetData.isNotEmpty) {
        parcelsToShow = List<Parcel>.from(selectedWorksheetData['parcels'] ?? []);
      }
    }

    if (parcelsToShow.isEmpty || _mapController == null) return;
    
    // Calculate bounds of all polygons
    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;
    
    int validCoordinatesCount = 0;
    
    for (final parcel in parcelsToShow) {
      for (final coord in parcel.coordinates) {
        double lat = coord[0];
        double lng = coord[1];
        
        // Only consider valid coordinates for bounds calculation
        if (lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
          validCoordinatesCount++;
          
          if (lat < minLat) minLat = lat;
          if (lat > maxLat) maxLat = lat;
          if (lng < minLng) minLng = lng;
          if (lng > maxLng) maxLng = lng;
        }
      }
    }
    
    // If found valid bounds, adjust camera
    if (validCoordinatesCount > 0 && 
        minLat != double.infinity && maxLat != -double.infinity &&
        minLng != double.infinity && maxLng != -double.infinity) {
      
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );
      
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100.0), // 100px padding
      );
    }
  }

  /// Determines the current position of the device.
  Future<void> _determinePosition() async {
    setState(() {
      _isLoadingLocation = true;
    });

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('Location services are disabled. Please enable them.', isError: true);
      setState(() {
        _isLoadingLocation = false;
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('Location permissions denied.', isError: true);
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackBar('Location permissions permanently denied. Please enable in app settings.', isError: true);
      setState(() {
        _isLoadingLocation = false;
      });
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _userLocationMarker = Marker(
          markerId: const MarkerId('userLocation'),
          position: _currentLocation!,
          infoWindow: const InfoWindow(title: 'Your Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        );
        _isLoadingLocation = false;
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLocation!, 15),
      );
    } catch (e) {
      _showSnackBar('Error getting location: $e', isError: true);
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  /// Callback when Google Map is created.
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    
    // If we already have loaded polygons, adjust camera
    if (_polygons.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _fitCameraToPolygons();
      });
    }
  }

  /// Shows a SnackBar with message.
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  /// Builds the worksheet panel for mobile (bottom sheet)
  Widget _buildMobileWorksheetPanel() {
    return DraggableScrollableSheet(
      initialChildSize: 0.3,
      minChildSize: 0.1,
      maxChildSize: 0.8,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Panel content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Worksheets',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Dropdown to select worksheet
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedWorksheetId?.toString(),
                              isExpanded: true,
                              items: _worksheets.map((worksheet) {
                                return DropdownMenuItem<String>(
                                  value: worksheet['id'].toString(),
                                  child: Text('Worksheet #${worksheet['id']}'),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedWorksheetId = newValue != null ? int.tryParse(newValue) : null;
                                  _createPolygons(); // Recreate polygons for new selection
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Selected worksheet details
                        if (_selectedWorksheetId != null) _buildWorksheetDetails(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Builds the worksheet panel for desktop (side panel)
  Widget _buildDesktopWorksheetPanel() {
    return Container(
      width: 350,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Panel header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFF5F5DC), // Beige color similar to image
              border: Border(
                bottom: BorderSide(color: Colors.grey, width: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Worksheets',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                // Dropdown to select worksheet
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedWorksheetId?.toString(),
                      isExpanded: true,
                      items: _worksheets.map((worksheet) {
                        return DropdownMenuItem<String>(
                          value: worksheet['id'].toString(),
                          child: Text('Worksheet #${worksheet['id']}'),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedWorksheetId = newValue != null ? int.tryParse(newValue) : null;
                          _createPolygons(); // Recreate polygons for new selection
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Selected worksheet details
          Expanded(
            child: _selectedWorksheetId != null
                ? _buildWorksheetDetails()
                : const Center(
                    child: Text('Select a worksheet'),
                  ),
          ),
        ],
      ),
    );
  }

  /// Builds the details of the selected worksheet
  Widget _buildWorksheetDetails() {
    var selectedWorksheetData = _worksheets.firstWhere(
      (w) => w['id'] == _selectedWorksheetId,
      orElse: () => {},
    );

    if (selectedWorksheetData.isEmpty) {
      return const Center(child: Text('Worksheet not found'));
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Worksheet #${selectedWorksheetData['id']}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailRow('POSP:', selectedWorksheetData['posp']?['description'] ?? 'N/A'),
          const SizedBox(height: 8),
          _buildDetailRow('Start Date:', _formatDate(selectedWorksheetData['startingDate'])),
          const SizedBox(height: 8),
          _buildDetailRow('End Date:', _formatDate(selectedWorksheetData['finishingDate'])),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildMapTypeButton(String label, MapType mapType) {
    bool isSelected = _currentMapType == mapType;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentMapType = mapType;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.grey.shade200 : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check if we're on mobile
    bool isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Worksheet Map'),
        backgroundColor: const Color(0xFF4F695B),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWorksheets,
            tooltip: 'Reload Worksheets',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main map
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _currentLocation ?? _defaultLocation,
              zoom: 10,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            markers: _userLocationMarker != null ? {_userLocationMarker!} : {},
            polygons: _polygons,
            mapType: _currentMapType,
            onTap: (LatLng position) {
              print('Map tapped at: ${position.latitude}, ${position.longitude}');
            },
          ),
          
          // Map type controls
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMapTypeButton('Map', MapType.normal),
                  Container(
                    width: 1,
                    height: 30,
                    color: Colors.grey.shade300,
                  ),
                  _buildMapTypeButton('Satellite', MapType.satellite),
                ],
              ),
            ),
          ),

          // Loading indicator
          if (_isLoadingWorksheets)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Loading...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

          // Action buttons (bottom right corner)
          Positioned(
            bottom: isMobile ? 120 : 20, // Leave space for mobile panel
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: "location",
                  onPressed: _isLoadingLocation ? null : _determinePosition,
                  backgroundColor: const Color(0xFF4F695B),
                  child: _isLoadingLocation
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.my_location, color: Colors.white),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: "center",
                  onPressed: () {
                    if (_mapController != null) {
                      _fitCameraToPolygons();
                    }
                  },
                  backgroundColor: const Color(0xFF4F695B),
                  child: const Icon(Icons.center_focus_strong, color: Colors.white),
                ),
              ],
            ),
          ),

          // Worksheet panel - different for mobile and desktop
          if (isMobile)
            // Mobile: Bottom sheet
            _buildMobileWorksheetPanel()
          else
            // Desktop: Side panel
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: _buildDesktopWorksheetPanel(),
            ),
        ],
      ),
    );
  }
}