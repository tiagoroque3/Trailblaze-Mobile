// lib/services/parcel_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
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
            // GeoJSON usa [longitude, latitude], mas queremos [latitude, longitude]
            return [coord[1].toDouble(), coord[0].toDouble()];
          }
          return [0.0, 0.0];
        }).toList();
      }
    }
    
    // Se não conseguiu extrair coordenadas, usa coordenadas padrão
    if (coordinates.isEmpty) {
      coordinates = [
        [38.7223, -9.1393], // Lisboa
        [38.7233, -9.1383],
        [38.7243, -9.1403],
        [38.7233, -9.1413],
      ];
    }
    
    return Parcel(
      id: '${worksheetId}_${backendParcel['polygonId'] ?? 0}',
      name: 'Parcela ${backendParcel['polygonId'] ?? 0} - FO $worksheetId',
      description: 'AIGP: ${backendParcel['aigp'] ?? 'N/A'}\nID Rural: ${backendParcel['ruralPropertyId'] ?? 'N/A'}\nFolha: ${worksheet['posa']?['description'] ?? 'N/A'}',
      coordinates: coordinates,
      color: _getColorForWorksheet(worksheetId),
    );
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
          [38.7200, -9.1400],
          [38.7210, -9.1390],
          [38.7220, -9.1410],
          [38.7210, -9.1420],
        ],
        color: '#00FF00',
      ),
      Parcel(
        id: '3',
        name: 'Parcela 3 - FO Exemplo C',
        description: 'Área de monitorização leste\nAIGP: EX003\nID Rural: RUR003',
        coordinates: [
          [38.7180, -9.1320],
          [38.7190, -9.1310],
          [38.7200, -9.1330],
          [38.7190, -9.1340],
        ],
        color: '#0000FF',
      ),
    ];
  }
}