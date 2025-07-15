// lib/services/parcel_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import '../models/parcel.dart';

class ParcelService {
  static const String baseUrl = 'https://trailblaze-460312.appspot.com/rest';

  /// Busca todas as folhas de obra e extrai as parcelas
  static Future<List<Parcel>> fetchParcels({String? jwtToken}) async {
    try {
      // Primeiro, busca todas as folhas de obra genéricas
      final Uri url = Uri.parse('$baseUrl/fo/search/generic');
      
      final Map<String, String> headers = {
        'Content-Type': 'application/json; charset=UTF-8',
      };
      
      if (jwtToken != null) {
        headers['Authorization'] = 'Bearer $jwtToken';
      }

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> worksheets = jsonDecode(response.body);
        List<Parcel> parcels = [];
        
        // Para cada folha de obra, busca os detalhes para obter as parcelas
        for (var worksheet in worksheets) {
          final int worksheetId = worksheet['id'];
          final parcelsFromWorksheet = await _fetchParcelsFromWorksheet(worksheetId, jwtToken);
          parcels.addAll(parcelsFromWorksheet);
        }
        
        return parcels;
      } else {
        print('Erro ao buscar folhas de obra: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Erro na requisição de folhas de obra: $e');
      return [];
    }
  }

  /// Busca parcelas de uma folha de obra específica
  static Future<List<Parcel>> _fetchParcelsFromWorksheet(int worksheetId, String? jwtToken) async {
    try {
      final Uri url = Uri.parse('$baseUrl/fo/$worksheetId/detail');
      
      final Map<String, String> headers = {
        'Content-Type': 'application/json; charset=UTF-8',
      };
      
      if (jwtToken != null) {
        headers['Authorization'] = 'Bearer $jwtToken';
      }

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final Map<String, dynamic> worksheetDetail = jsonDecode(response.body);
        final List<dynamic> parcelsJson = worksheetDetail['parcels'] ?? [];
        
        return parcelsJson.map((parcelJson) {
          return _convertBackendParcelToModel(parcelJson, worksheetId, worksheetDetail);
        }).toList();
      } else {
        print('Erro ao buscar detalhes da folha $worksheetId: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Erro ao buscar parcelas da folha $worksheetId: $e');
      return [];
    }
  }

  /// Converte uma parcela do backend para o modelo do frontend
  static Parcel _convertBackendParcelToModel(Map<String, dynamic> backendParcel, int worksheetId, Map<String, dynamic> worksheet) {
    // Extrai coordenadas da geometria GeoJSON
    List<List<double>> coordinates = [];
    
    if (backendParcel['geometry'] != null && backendParcel['geometry']['coordinates'] != null) {
      final geomCoords = backendParcel['geometry']['coordinates'];
      
      if (backendParcel['geometry']['type'] == 'Polygon' && geomCoords is List && geomCoords.isNotEmpty) {
        // Para polígonos, pega o primeiro anel (exterior)
        final List<dynamic> ring = geomCoords[0];
        coordinates = ring.map<List<double>>((coord) {
          if (coord is List && coord.length >= 2) {
            // As coordenadas podem estar em sistema português (EPSG:3763 - ETRS89 / Portugal TM06)
            // ou outro sistema de coordenadas projetado
            double x = coord[0].toDouble();
            double y = coord[1].toDouble();
            
            // Converte coordenadas portuguesas para WGS84 (lat/lng)
            List<double> latLng = _convertPortugueseCoordinatesToWGS84(x, y);
            double latitude = latLng[0];
            double longitude = latLng[1];
            
            // Validação das coordenadas convertidas
            if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
              print('Coordenadas convertidas inválidas: lat=$latitude, lng=$longitude (original: x=$x, y=$y)');
              return [38.7223, -9.1393]; // Lisboa como fallback
            }
            
            return [latitude, longitude];
          }
          return [38.7223, -9.1393]; // Lisboa como fallback
        }).toList();
        
        // Remove coordenadas duplicadas no final (comum em polígonos GeoJSON)
        if (coordinates.length > 1 && 
            coordinates.first[0] == coordinates.last[0] && 
            coordinates.first[1] == coordinates.last[1]) {
          coordinates.removeLast();
        }
      }
    }
    
    // Se não conseguiu extrair coordenadas, usa coordenadas padrão
    if (coordinates.isEmpty) {
      print('Usando coordenadas padrão para parcela ${backendParcel['polygonId']}');
      coordinates = [
        [38.7223, -9.1393], // Lisboa
        [38.7233, -9.1383],
        [38.7243, -9.1403],
        [38.7233, -9.1413],
      ];
    }
    
    // Debug: imprime as coordenadas convertidas
    print('Parcela ${backendParcel['polygonId']}: ${coordinates.length} coordenadas convertidas');
    if (coordinates.isNotEmpty) {
      print('Primeira coordenada convertida: [${coordinates.first[0]}, ${coordinates.first[1]}]');
    }
    
    return Parcel(
      id: '${worksheetId}_${backendParcel['polygonId'] ?? 0}',
      name: 'Parcela ${backendParcel['polygonId'] ?? 0} - FO $worksheetId',
      description: 'AIGP: ${backendParcel['aigp'] ?? 'N/A'}\nID Rural: ${backendParcel['ruralPropertyId'] ?? 'N/A'}\nFolha: ${worksheet['posa']?['description'] ?? 'N/A'}',
      coordinates: coordinates,
      color: _getColorForWorksheet(worksheetId),
    );
  }

  /// Converte coordenadas do sistema português (EPSG:3763 - ETRS89 / Portugal TM06) para WGS84
  /// Esta é uma conversão aproximada - para maior precisão, seria necessária uma biblioteca de projeção
  static List<double> _convertPortugueseCoordinatesToWGS84(double x, double y) {
    // Verifica se as coordenadas já estão em formato WGS84 (lat/lng)
    if (x >= -180 && x <= 180 && y >= -90 && y <= 90) {
      // Coordenadas já estão em WGS84, mas podem estar invertidas
      // Se x está na faixa de longitude e y na faixa de latitude, assume [lng, lat]
      return [y, x]; // Retorna [lat, lng]
    }
    
    // Se as coordenadas estão em valores muito grandes, assume sistema projetado português
    if (x > 1000 || y > 1000) {
      // Conversão aproximada do sistema EPSG:3763 (Portugal TM06) para WGS84
      // Parâmetros aproximados para Portugal continental
      
      // Origem do sistema TM06
      double falseEasting = 0.0;
      double falseNorthing = 0.0;
      double centralMeridian = -8.133108; // Meridiano central de Portugal
      double latitudeOfOrigin = 39.66825833; // Latitude de origem
      
      // Conversão aproximada (simplificada)
      // Esta é uma aproximação - para precisão total seria necessário usar proj4 ou similar
      double deltaX = x - falseEasting;
      double deltaY = y - falseNorthing;
      
      // Fatores de escala aproximados para Portugal
      double scaleX = 1.0 / 111320.0; // metros por grau de longitude (aproximado)
      double scaleY = 1.0 / 110540.0; // metros por grau de latitude (aproximado)
      
      double longitude = centralMeridian + (deltaX * scaleX);
      double latitude = latitudeOfOrigin + (deltaY * scaleY);
      
      // Ajustes para Portugal continental
      if (longitude < -10 || longitude > -6) {
        longitude = math.max(-10, math.min(-6, longitude));
      }
      if (latitude < 36 || latitude > 42) {
        latitude = math.max(36, math.min(42, latitude));
      }
      
      print('Conversão de coordenadas: ($x, $y) -> ($latitude, $longitude)');
      return [latitude, longitude];
    }
    
    // Se não conseguir identificar o sistema, usa coordenadas de Lisboa
    print('Sistema de coordenadas não identificado: ($x, $y), usando Lisboa como fallback');
    return [38.7223, -9.1393];
  }

  /// Gera uma cor baseada no ID da folha de obra
  static String _getColorForWorksheet(int worksheetId) {
    final colors = [
      '#FF0000', // Vermelho
      '#00FF00', // Verde
      '#0000FF', // Azul
      '#FFA500', // Laranja
      '#800080', // Roxo
      '#FFFF00', // Amarelo
      '#FF69B4', // Rosa
      '#00FFFF', // Ciano
    ];
    return colors[worksheetId % colors.length];
  }

  /// Dados de exemplo caso a API não esteja disponível
  static List<Parcel> getMockParcels() {
    return [
      Parcel(
        id: '1',
        name: 'Parcela 1 - FO Exemplo A',
        description: 'Área de reflorestação norte\nAIGP: EX001\nID Rural: RUR001',
        coordinates: [
          [38.7223, -9.1393], // Lisboa
          [38.7233, -9.1383],
          [38.7243, -9.1403],
          [38.7233, -9.1413],
        ],
        color: '#FF0000',
      ),
      Parcel(
        id: '2',
        name: 'Parcela 2 - FO Exemplo B',
        description: 'Área de manutenção sul\nAIGP: EX002\nID Rural: RUR002',
        coordinates: [
          [38.7180, -9.1350],
          [38.7190, -9.1340],
          [38.7200, -9.1360],
          [38.7190, -9.1370],
        ],
        color: '#00FF00',
      ),
      Parcel(
        id: '3',
        name: 'Parcela 3 - FO Exemplo C',
        description: 'Área de monitorização leste\nAIGP: EX003\nID Rural: RUR003',
        coordinates: [
          [38.7150, -9.1300],
          [38.7160, -9.1290],
          [38.7170, -9.1310],
          [38.7160, -9.1320],
        ],
        color: '#0000FF',
      ),
    ];
  }
}