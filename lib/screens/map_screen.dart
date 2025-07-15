import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/parcel.dart';
import '../services/parcel_service.dart';

/// Representa o ecrã dedicado à exibição do mapa com polígonos das folhas de obra.
/// Este ecrã é acessível a todos os utilizadores, independentemente do estado de login.
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
  // Controlador para a instância do Google Map.
  GoogleMapController? _mapController;
  // Armazena a localização atual do utilizador.
  LatLng? _currentLocation;
  // Marcador para exibir a localização atual do utilizador no mapa.
  Marker? _userLocationMarker;
  // Estado para gerir o indicador de carregamento durante a busca de localização.
  bool _isLoadingLocation = false;
  // Estado para gerir o carregamento das parcelas.
  bool _isLoadingParcels = false;
  // Lista de parcelas/folhas de obra.
  List<Parcel> _parcels = [];
  // Conjunto de polígonos para exibir no mapa.
  Set<Polygon> _polygons = {};
  // Localização padrão (Lisboa, Portugal)
  static const LatLng _defaultLocation = LatLng(38.7223, -9.1393);

  @override
  void initState() {
    super.initState();
    _loadParcels();
  }

  /// Carrega as parcelas/folhas de obra do servidor ou dados de exemplo.
  Future<void> _loadParcels() async {
    setState(() {
      _isLoadingParcels = true;
    });

    try {
      // Tenta buscar parcelas do servidor
      List<Parcel> parcels = await ParcelService.fetchParcels(
        jwtToken: widget.jwtToken,
      );

      // Se não conseguir dados do servidor, usa dados de exemplo
      if (parcels.isEmpty) {
        parcels = ParcelService.getMockParcels();
        _showSnackBar('A usar dados de exemplo das folhas de obra');
      }

      setState(() {
        _parcels = parcels;
        _createPolygons();
      });
    } catch (e) {
      print('Erro ao carregar parcelas: $e');
      // Em caso de erro, usa dados de exemplo
      setState(() {
        _parcels = ParcelService.getMockParcels();
        _createPolygons();
      });
      _showSnackBar('Erro ao carregar dados. A usar dados de exemplo.');
    } finally {
      setState(() {
        _isLoadingParcels = false;
      });
    }
  }

  /// Cria os polígonos a partir das parcelas carregadas.
  void _createPolygons() {
    Set<Polygon> polygons = {};

    for (int i = 0; i < _parcels.length; i++) {
      final parcel = _parcels[i];
      
      // Converte as coordenadas para LatLng
      List<LatLng> polygonPoints = parcel.coordinates
          .map((coord) => LatLng(coord[0], coord[1]))
          .toList();

      // Define cores alternadas se não especificada
      Color polygonColor;
      if (parcel.color != null) {
        polygonColor = _hexToColor(parcel.color!);
      } else {
        // Cores alternadas
        List<Color> colors = [
          Colors.red.withOpacity(0.3),
          Colors.green.withOpacity(0.3),
          Colors.blue.withOpacity(0.3),
          Colors.orange.withOpacity(0.3),
          Colors.purple.withOpacity(0.3),
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
          onTap: () => _onPolygonTapped(parcel),
        ),
      );
    }

    setState(() {
      _polygons = polygons;
    });
  }

  /// Converte uma string hexadecimal para Color.
  Color _hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16)).withOpacity(0.3);
  }

  /// Callback quando um polígono é tocado.
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
              Text('Descrição: ${parcel.description}'),
              const SizedBox(height: 8),
              Text('Coordenadas: ${parcel.coordinates.length} pontos'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
            if (widget.jwtToken != null)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _centerMapOnParcel(parcel);
                },
                child: const Text('Centrar no Mapa'),
              ),
          ],
        );
      },
    );
  }

  /// Centra o mapa numa parcela específica.
  void _centerMapOnParcel(Parcel parcel) {
    if (_mapController != null && parcel.coordinates.isNotEmpty) {
      // Calcula o centro do polígono
      double avgLat = parcel.coordinates.map((coord) => coord[0]).reduce((a, b) => a + b) / parcel.coordinates.length;
      double avgLng = parcel.coordinates.map((coord) => coord[1]).reduce((a, b) => a + b) / parcel.coordinates.length;
      
      LatLng center = LatLng(avgLat, avgLng);
      
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(center, 15),
      );
    }
  }

  /// Determina a posição atual do dispositivo.
  Future<void> _determinePosition() async {
    setState(() {
      _isLoadingLocation = true;
    });

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('Os serviços de localização estão desativados. Por favor, ative-os.', isError: true);
      setState(() {
        _isLoadingLocation = false;
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('Permissões de localização negadas.', isError: true);
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackBar('Permissões de localização permanentemente negadas. Por favor, ative nas definições da aplicação.', isError: true);
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
          infoWindow: const InfoWindow(title: 'A Sua Localização'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        );
        _isLoadingLocation = false;
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLocation!, 15),
      );
    } catch (e) {
      _showSnackBar('Erro ao obter localização: $e', isError: true);
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  /// Callback quando o Google Map é criado.
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  /// Exibe uma SnackBar com mensagem.
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa das Folhas de Obra'),
        backgroundColor: const Color(0xFF4F695B),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadParcels,
            tooltip: 'Recarregar Folhas de Obra',
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _currentLocation ?? _defaultLocation,
              zoom: 12,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            markers: _userLocationMarker != null ? {_userLocationMarker!} : {},
            polygons: _polygons,
            onTap: (LatLng position) {
              // Opcional: ação quando o mapa é tocado
            },
          ),
          if (_isLoadingParcels)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'A carregar folhas de obra...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          // Painel de informações
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF4F695B)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_parcels.length} folhas de obra carregadas. Toque num polígono para mais informações.',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
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
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: "center",
            onPressed: () {
              if (_mapController != null) {
                LatLng target = _currentLocation ?? _defaultLocation;
                _mapController!.animateCamera(
                  CameraUpdate.newLatLngZoom(target, 12),
                );
              }
            },
            backgroundColor: const Color(0xFF4F695B),
            child: const Icon(Icons.center_focus_strong, color: Colors.white),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}