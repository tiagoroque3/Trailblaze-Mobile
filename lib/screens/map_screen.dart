import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/parcel.dart';
import '../services/parcel_service.dart';
import 'dart:convert';

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
  // Lista de worksheets reais do backend
  List<Map<String, dynamic>> _worksheets = [];
  // Conjunto de polígonos para exibir no mapa.
  Set<Polygon> _polygons = {};
  // Localização padrão (Lisboa, Portugal)
  static const LatLng _defaultLocation = LatLng(38.7223, -9.1393);
  // Tipo de mapa atual
  MapType _currentMapType = MapType.normal;
  // Folha de obra selecionada
  int? _selectedWorksheetId;

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

    // Lista de roles autorizados
    const allowedRoles = [
      'SMBO', 'SDVBO', 'SGVBO', 'RU', 'ADLU', 'PO', 'PRBO', 'SYSADMIN', 'SYSBO'
    ];

    // Extrai roles do JWT
    List<String> userRoles = _extractRolesFromJwt(widget.jwtToken);

    // Verifica se o utilizador tem pelo menos um role autorizado
    bool hasAccess = userRoles.any((role) => allowedRoles.contains(role));

    if (!hasAccess) {
      setState(() {
        _worksheets = ParcelService.getMockWorksheets();
        _parcels = ParcelService.getMockParcels();
        _createPolygons();
        _isLoadingParcels = false;
      });
      if (_worksheets.isNotEmpty) {
        _selectedWorksheetId = _worksheets.first['id'];
      }
      _showSnackBar('Sem permissões suficientes para carregar detalhes das folhas de obra.', isError: true);
      return;
    }

    try {
      // Busca worksheets e parcelas do servidor
      final result = await ParcelService.fetchWorksheetsWithParcels(
        jwtToken: widget.jwtToken,
      );

      List<Map<String, dynamic>> worksheets = List<Map<String, dynamic>>.from(result['worksheets'] ?? []);
      List<Parcel> parcels = List<Parcel>.from(result['parcels'] ?? []);

      // Usa dados de exemplo se não conseguir dados do servidor
      if (worksheets.isEmpty) {
        worksheets = ParcelService.getMockWorksheets();
        parcels = ParcelService.getMockParcels();
        _showSnackBar('A usar dados de exemplo das worksheets');
      } else {
        _showSnackBar('${worksheets.length} worksheets e ${parcels.length} parcelas carregadas');
      }

      setState(() {
        _worksheets = worksheets;
        _parcels = parcels;
        _createPolygons();
      });
      
      // Define a primeira worksheet como selecionada
      if (_worksheets.isNotEmpty) {
        _selectedWorksheetId = _worksheets.first['id'];
      }
    } catch (e) {
      print('Erro ao carregar worksheets: $e');
      // Em caso de erro, usa dados de exemplo
      setState(() {
        _worksheets = ParcelService.getMockWorksheets();
        _parcels = ParcelService.getMockParcels();
        _createPolygons();
      });
      if (_worksheets.isNotEmpty) {
        _selectedWorksheetId = _worksheets.first['id'];
      }
      _showSnackBar('Erro ao carregar dados do servidor. A usar dados de exemplo.', isError: true);
    } finally {
      setState(() {
        _isLoadingParcels = false;
      });
    }
  }

  /// Formata data ISO para exibição
  String _formatDate(String? isoDate) {
    if (isoDate == null) return 'N/A';
    try {
      DateTime date = DateTime.parse(isoDate);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  /// Função auxiliar para extrair roles do JWT
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

  /// Cria os polígonos a partir das parcelas carregadas.
  void _createPolygons() {
    print('\n=== CRIANDO POLÍGONOS ===');
    print('Total de parcelas para processar: ${_parcels.length}');
    
    Set<Polygon> polygons = {};
    int polygonsCreated = 0;
    int polygonsSkipped = 0;

    // Filtra parcelas baseado na worksheet selecionada
    List<Parcel> filteredParcels = _parcels;
    if (_selectedWorksheetId != null) {
      var selectedWorksheetData = _worksheets.firstWhere(
        (w) => w['id'] == _selectedWorksheetId,
        orElse: () => {},
      );
      if (selectedWorksheetData.isNotEmpty) {
        filteredParcels = List<Parcel>.from(selectedWorksheetData['parcels'] ?? []);
      }
    }

    for (int i = 0; i < filteredParcels.length; i++) {
      final parcel = filteredParcels[i];
      print('\nProcessando parcela ${i + 1}/${filteredParcels.length}: ${parcel.id}');
      
      // Validação das coordenadas antes de criar o polígono
      if (parcel.coordinates.length < 3) {
        print('⚠️ Parcela ${parcel.id} tem apenas ${parcel.coordinates.length} coordenadas (mínimo 3), ignorando');
        polygonsSkipped++;
        continue;
      }
      
      // Converte as coordenadas para LatLng
      List<LatLng> polygonPoints = parcel.coordinates
          .map((coord) {
            double lat = coord[0];
            double lng = coord[1];
            
            // Validação adicional
            if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
              print('⚠️ Coordenada inválida ignorada: [$lat, $lng] na parcela ${parcel.id}');
              return LatLng(38.7223, -9.1393); // Lisboa como fallback
            }
            
            return LatLng(lat, lng);
          })
          .toList();
      
      // Define cores alternadas se não especificada
      Color polygonColor;
      if (parcel.color != null) {
        polygonColor = _hexToColor(parcel.color!);
      } else {
        // Cores alternadas
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
      print('✓ Polígono ${parcel.id} adicionado ao mapa');
    }

    print('\n=== RESUMO DA CRIAÇÃO DE POLÍGONOS ===');
    print('Polígonos criados: $polygonsCreated');
    print('Polígonos ignorados: $polygonsSkipped');
    print('Total no mapa: ${polygons.length}');
    print('=====================================');

    setState(() {
      _polygons = polygons;
    });
    
    // Se temos polígonos, ajusta a câmera para mostrar todos
    if (polygons.isNotEmpty && _mapController != null) {
      print('Ajustando câmera para mostrar todos os polígonos...');
      _fitCameraToPolygons();
    } else if (polygons.isEmpty) {
      print('⚠️ Nenhum polígono foi criado para exibir no mapa!');
    }
  }

  /// Converte uma string hexadecimal para Color.
  Color _hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16)).withOpacity(0.4);
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
      
      print('Centrando mapa em: $avgLat, $avgLng');
      
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(center, 16),
      );
    }
  }
  
  /// Ajusta a câmera para mostrar todos os polígonos
  void _fitCameraToPolygons() {
    List<Parcel> parcelsToShow = _parcels;
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
    
    // Calcula os bounds de todos os polígonos
    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;
    
    int validCoordinatesCount = 0;
    
    for (final parcel in parcelsToShow) {
      for (final coord in parcel.coordinates) {
        double lat = coord[0];
        double lng = coord[1];
        
        // Só considera coordenadas válidas para o cálculo dos bounds
        if (lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
          validCoordinatesCount++;
          
          if (lat < minLat) minLat = lat;
          if (lat > maxLat) maxLat = lat;
          if (lng < minLng) minLng = lng;
          if (lng > maxLng) maxLng = lng;
        }
      }
    }
    
    // Se encontrou bounds válidos, ajusta a câmera
    if (validCoordinatesCount > 0 && 
        minLat != double.infinity && maxLat != -double.infinity &&
        minLng != double.infinity && maxLng != -double.infinity) {
      
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );
      
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100.0), // 100px de padding
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
    
    // Se já temos polígonos carregados, ajusta a câmera
    if (_polygons.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _fitCameraToPolygons();
      });
    }
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

  /// Constrói o painel lateral com as worksheets
  Widget _buildWorksheetPanel() {
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
          // Header do painel
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFF5F5DC), // Cor bege similar à imagem
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
                // Dropdown para selecionar worksheet
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
                          _createPolygons(); // Recria polígonos para a nova seleção
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Detalhes da worksheet selecionada
          Expanded(
            child: _selectedWorksheetId != null
                ? _buildWorksheetDetails()
                : const Center(
                    child: Text('Selecione uma worksheet'),
                  ),
          ),
        ],
      ),
    );
  }

  /// Constrói os detalhes da worksheet selecionada
  Widget _buildWorksheetDetails() {
    var selectedWorksheetData = _worksheets.firstWhere(
      (w) => w['id'] == _selectedWorksheetId,
      orElse: () => {},
    );

    if (selectedWorksheetData.isEmpty) {
      return const Center(child: Text('Worksheet não encontrada'));
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
          _buildDetailRow('POSA:', selectedWorksheetData['posa']?['description'] ?? 'N/A'),
          const SizedBox(height: 8),
          _buildDetailRow('POSP:', selectedWorksheetData['posp']?['description'] ?? 'N/A'),
          const SizedBox(height: 8),
          _buildDetailRow('Início:', _formatDate(selectedWorksheetData['startingDate'])),
          const SizedBox(height: 8),
          _buildDetailRow('Fim:', _formatDate(selectedWorksheetData['finishingDate'])),
          const SizedBox(height: 8),
          _buildDetailRow('Emissão:', _formatDate(selectedWorksheetData['issueDate'])),
          const SizedBox(height: 8),
          _buildDetailRow('Adjudicação:', _formatDate(selectedWorksheetData['awardDate'])),
          const SizedBox(height: 20),
          Text(
            'Parcelas (${(selectedWorksheetData['parcels'] as List).length})',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: (selectedWorksheetData['parcels'] as List).length,
              itemBuilder: (context, index) {
                Parcel parcel = (selectedWorksheetData['parcels'] as List)[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(
                      parcel.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      parcel.description,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Icon(
                      Icons.location_on,
                      color: _hexToColor(parcel.color ?? '#4CAF50'),
                    ),
                    onTap: () => _centerMapOnParcel(parcel),
                  ),
                );
              },
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
        SizedBox(
          width: 60,
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
            tooltip: 'Recarregar Parcelas',
          ),
        ],
      ),
      body: Row(
        children: [
          // Mapa principal
          Expanded(
            child: Stack(
              children: [
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
                    print('Mapa tocado em: ${position.latitude}, ${position.longitude}');
                  },
                ),
                // Controles de tipo de mapa (similar à versão web)
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
                        _buildMapTypeButton('Mapa', MapType.normal),
                        Container(
                          width: 1,
                          height: 30,
                          color: Colors.grey.shade300,
                        ),
                        _buildMapTypeButton('Satélite', MapType.satellite),
                      ],
                    ),
                  ),
                ),
                // Indicador de carregamento
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
                            'A carregar parcelas...',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Botões de ação (canto inferior direito)
                Positioned(
                  bottom: 20,
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
              ],
            ),
          ),
          // Painel lateral das worksheets
          _buildWorksheetPanel(),
        ],
      ),
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
}