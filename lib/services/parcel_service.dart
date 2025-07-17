// lib/services/parcel_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import '../models/parcel.dart';
import 'package:proj4dart/proj4dart.dart';
import '../utils/role_manager.dart';


class ParcelService {
  static const String baseUrl = 'https://trailblaze-460312.appspot.com/rest';

  /// Busca todas as worksheets genéricas
  static Future<List<Map<String, dynamic>>> fetchWorksheets({String? jwtToken}) async {
    try {
      final Uri url = Uri.parse('$baseUrl/fo/search/generic');
      
      final Map<String, String> headers = {
        'Content-Type': 'application/json; charset=UTF-8',
      };
      
      if (jwtToken != null) {
        headers['Authorization'] = 'Bearer $jwtToken';
      }

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> worksheetsJson = jsonDecode(response.body);
        
        print('=== WORKSHEETS ENCONTRADAS ===');
        print('Total de worksheets: ${worksheetsJson.length}');
        
        List<Map<String, dynamic>> worksheets = worksheetsJson.map((ws) {
          print('Worksheet ID: ${ws['id']}, POSA: ${ws['posa']?['description'] ?? 'N/A'}');
          return Map<String, dynamic>.from(ws);
        }).toList();
        
        print('===============================');
        return worksheets;
      } else {
        print('Erro ao buscar worksheets: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Erro na requisição de worksheets: $e');
      return [];
    }
  }

  /// Busca todas as folhas de obra e extrai as parcelas
  static Future<Map<String, dynamic>> fetchWorksheetsWithParcels({String? jwtToken}) async {
    try {
      // Busca todas as worksheets genéricas
      List<Map<String, dynamic>> worksheets = await fetchWorksheets(jwtToken: jwtToken);
      
      if (worksheets.isEmpty) {
        return {'worksheets': [], 'parcels': []};
      }

      List<Map<String, dynamic>> worksheetsWithParcels = [];
      List<Parcel> allParcels = [];
      
      // Para cada worksheet, busca os detalhes com parcelas
      for (var worksheet in worksheets) {
        final int worksheetId = worksheet['id'];
        
        print('\n--- Processando Worksheet $worksheetId ---');
        final parcelsFromWorksheet = await _fetchParcelsFromWorksheet(worksheetId, jwtToken);
        print('Parcelas encontradas na worksheet $worksheetId: ${parcelsFromWorksheet.length}');
        
        // Adiciona as parcelas à worksheet
        Map<String, dynamic> worksheetWithParcels = Map<String, dynamic>.from(worksheet);
        worksheetWithParcels['parcels'] = parcelsFromWorksheet;
        worksheetsWithParcels.add(worksheetWithParcels);
        
        allParcels.addAll(parcelsFromWorksheet);
      }
      
      print('\n=== RESUMO FINAL ===');
      print('Total de worksheets: ${worksheetsWithParcels.length}');
      print('Total de parcelas: ${allParcels.length}');
      print('==================');
      
      return {
        'worksheets': worksheetsWithParcels,
        'parcels': allParcels,
      };
    } catch (e) {
      print('Erro ao buscar worksheets com parcelas: $e');
      return {'worksheets': [], 'parcels': []};
    }
  }

  /// Método de compatibilidade para buscar apenas parcelas
  static Future<List<Parcel>> fetchParcels({String? jwtToken}) async {
    final result = await fetchWorksheetsWithParcels(jwtToken: jwtToken);
    return List<Parcel>.from(result['parcels'] ?? []);
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

        
        print('Detalhes da folha $worksheetId:');
        print('- POSA: ${worksheetDetail['posa']?['description'] ?? 'N/A'}');
        print('- Parcelas no JSON: ${worksheetDetail['parcels']?.length ?? 0}');
        
        // Debug: mostra a estrutura completa da primeira parcela se existir
        if (worksheetDetail['parcels'] != null && worksheetDetail['parcels'].isNotEmpty) {
          print('- Estrutura da primeira parcela:');
          var firstParcel = worksheetDetail['parcels'][0];
          print('  * polygonId: ${firstParcel['polygonId']}');
          print('  * aigp: ${firstParcel['aigp']}');
          print('  * ruralPropertyId: ${firstParcel['ruralPropertyId']}');
          print('  * geometry type: ${firstParcel['geometry']?['type']}');
          print('  * coordinates length: ${firstParcel['geometry']?['coordinates']?.length}');
          if (firstParcel['geometry']?['coordinates'] != null) {
            var coords = firstParcel['geometry']['coordinates'];
            if (coords is List && coords.isNotEmpty && coords[0] is List) {
              print('  * first ring length: ${coords[0].length}');
              if (coords[0].isNotEmpty) {
                print('  * first coordinate: ${coords[0][0]}');
              }
            }
          }
        }
        
        final List<dynamic> parcelsJson = worksheetDetail['parcels'] ?? [];
        
        List<Parcel> convertedParcels = [];
        for (int i = 0; i < parcelsJson.length; i++) {
          try {
            var parcelJson = parcelsJson[i];
            print('Convertendo parcela ${i + 1}/${parcelsJson.length} da folha $worksheetId...');
            var convertedParcel = _convertBackendParcelToModel(parcelJson, worksheetId, worksheetDetail);
            convertedParcels.add(convertedParcel);
            print('✓ Parcela ${convertedParcel.id} convertida com sucesso');
          } catch (e) {
            print('✗ Erro ao converter parcela ${i + 1} da folha $worksheetId: $e');
            print('Dados da parcela problemática: ${parcelsJson[i]}');
          }
        }
        
        return convertedParcels;
      } else {
        print('Erro ao buscar detalhes da folha $worksheetId: ${response.statusCode}');
        print('Response body: ${response.body}');

        return [];
      }
    } catch (e) {
      print('Erro ao buscar parcelas da folha $worksheetId: $e');
      return [];
    }
  }

  /// Converte uma parcela do backend para o modelo do frontend
  static Parcel _convertBackendParcelToModel(Map<String, dynamic> backendParcel, int worksheetId, Map<String, dynamic> worksheet) {

    print('\n--- Convertendo Parcela ---');
    print('Folha: $worksheetId, PolygonId: ${backendParcel['polygonId']}');
    

    // Extrai coordenadas da geometria GeoJSON
    List<List<double>> coordinates = [];
    
    if (backendParcel['geometry'] != null && backendParcel['geometry']['coordinates'] != null) {
      final geomCoords = backendParcel['geometry']['coordinates'];

      final geomType = backendParcel['geometry']['type'];
      
      print('Tipo de geometria: $geomType');
      print('Estrutura de coordenadas: ${geomCoords.runtimeType}');
      
      if (geomType == 'Polygon' && geomCoords is List && geomCoords.isNotEmpty) {
        // Para polígonos, pega o primeiro anel (exterior)
        final List<dynamic> ring = geomCoords[0];
        print('Anel exterior tem ${ring.length} coordenadas');
        
        if (ring.isNotEmpty) {
          print('Primeira coordenada original: ${ring[0]}');
          print('Última coordenada original: ${ring[ring.length - 1]}');
        }
        

        coordinates = ring.map<List<double>>((coord) {
          if (coord is List && coord.length >= 2) {
            // As coordenadas podem estar em sistema português (EPSG:3763 - ETRS89 / Portugal TM06)
            // ou outro sistema de coordenadas projetado
            double x = coord[0].toDouble();
            double y = coord[1].toDouble();
            

            print('Coordenada original: [$x, $y]');
            

            // Converte coordenadas portuguesas para WGS84 (lat/lng)
            List<double> latLng = _convertPortugueseCoordinatesToWGS84(x, y);
            double latitude = latLng[0];
            double longitude = latLng[1];
            

            print('Coordenada convertida: [$latitude, $longitude]');
            
            // Validação das coordenadas convertidas
            if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
              print('Coordenadas convertidas inválidas: lat=$latitude, lng=$longitude (original: x=$x, y=$y)');
              return [38.7223, -9.1393]; // Lisboa como fallback
            }
            
            return [latitude, longitude];
          }

          print('Coordenada inválida ignorada: $coord');

          return [38.7223, -9.1393]; // Lisboa como fallback
        }).toList();
        
        // Remove coordenadas duplicadas no final (comum em polígonos GeoJSON)
        if (coordinates.length > 1 && 
            coordinates.first[0] == coordinates.last[0] && 
            coordinates.first[1] == coordinates.last[1]) {
          coordinates.removeLast();

          print('Removida coordenada duplicada no final');
        }
      } else if (geomType == 'MultiPolygon' && geomCoords is List && geomCoords.isNotEmpty) {
        print('Processando MultiPolygon...');
        // Para MultiPolygon, pega o primeiro polígono e seu primeiro anel
        if (geomCoords[0] is List && geomCoords[0].isNotEmpty) {
          final List<dynamic> firstPolygon = geomCoords[0];
          final List<dynamic> ring = firstPolygon[0];
          print('Primeiro polígono do MultiPolygon tem ${ring.length} coordenadas');
          
          coordinates = ring.map<List<double>>((coord) {
            if (coord is List && coord.length >= 2) {
              double x = coord[0].toDouble();
              double y = coord[1].toDouble();
              
              List<double> latLng = _convertPortugueseCoordinatesToWGS84(x, y);
              double latitude = latLng[0];
              double longitude = latLng[1];
              
              if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
                print('Coordenadas convertidas inválidas: lat=$latitude, lng=$longitude (original: x=$x, y=$y)');
                return [38.7223, -9.1393];
              }
              
              return [latitude, longitude];
            }
            return [38.7223, -9.1393];
          }).toList();
          
          if (coordinates.length > 1 && 
              coordinates.first[0] == coordinates.last[0] && 
              coordinates.first[1] == coordinates.last[1]) {
            coordinates.removeLast();
          }
        }
      } else {
        print('Tipo de geometria não suportado ou estrutura inválida: $geomType');
        print('Estrutura completa: $geomCoords');
      }
    } else {
      print('Geometria não encontrada ou inválida');

    }
    
    // Se não conseguiu extrair coordenadas, usa coordenadas padrão
    if (coordinates.isEmpty) {

      print('⚠️ AVISO: Usando coordenadas padrão para parcela ${backendParcel['polygonId']} da folha $worksheetId');

      coordinates = [
        [38.7223, -9.1393], // Lisboa
        [38.7233, -9.1383],
        [38.7243, -9.1403],
        [38.7233, -9.1413],
      ];
    }
    
    // Debug: imprime as coordenadas convertidas

    print('✓ Parcela ${backendParcel['polygonId']}: ${coordinates.length} coordenadas convertidas');
    if (coordinates.isNotEmpty) {
      print('  Primeira: [${coordinates.first[0]}, ${coordinates.first[1]}]');
      print('  Última: [${coordinates.last[0]}, ${coordinates.last[1]}]');
      
      // Calcula e mostra o centro
      double avgLat = coordinates.map((coord) => coord[0]).reduce((a, b) => a + b) / coordinates.length;
      double avgLng = coordinates.map((coord) => coord[1]).reduce((a, b) => a + b) / coordinates.length;
      print('  Centro: [$avgLat, $avgLng]');
    }
    print('-------------------------');

    
    return Parcel(
      id: '${worksheetId}_${backendParcel['polygonId'] ?? 0}',
      name: 'Parcela ${backendParcel['polygonId'] ?? 0}',
      description: 'AIGP: ${backendParcel['aigp'] ?? 'N/A'}\nID Rural: ${backendParcel['ruralPropertyId'] ?? 'N/A'}\nFolha: ${worksheet['posa']?['description'] ?? 'N/A'}',
      coordinates: coordinates,
      color: _getColorForWorksheet(worksheetId),
    );
  }

  /// Converte coordenadas do sistema português (EPSG:3763 - ETRS89 / Portugal TM06) para WGS84
  /// Esta é uma conversão aproximada - para maior precisão, seria necessária uma biblioteca de projeção
  static List<double> _convertPortugueseCoordinatesToWGS84(double x, double y) {
  // Define a projeção portuguesa EPSG:3763 (ETRS89/PT-TM06)
  final portugueseProjection = Projection.add('EPSG:3763',
      '+proj=tmerc +lat_0=39.66825833333333 +lon_0=-8.133108333333334 '
      '+k=1 +x_0=0 +y_0=0 +ellps=GRS80 +units=m +no_defs');

  // Define a projeção padrão WGS84 (EPSG:4326)
  final wgs84Projection = Projection.WGS84;

  // Ponto original no sistema português
  var point = Point(x: x, y: y);

  // Realiza a conversão
  var wgs84Point = portugueseProjection.transform(wgs84Projection, point);

  print('Conversão proj4: ($x, $y) -> (${wgs84Point.y}, ${wgs84Point.x})');

  // Retorna [latitude, longitude]
  return [wgs84Point.y, wgs84Point.x];
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
        name: 'Parcela 1',
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
        name: 'Parcela 2',
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
        name: 'Parcela 3',
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

  /// Dados de exemplo para worksheets
  static List<Map<String, dynamic>> getMockWorksheets() {
    return [
      {
        'id': 1,
        'startingDate': '2025-03-01T00:00:00',
        'finishingDate': '2025-06-30T00:00:00',
        'issueDate': '2025-02-15T00:00:00',
        'awardDate': '2025-02-20T00:00:00',
        'serviceProviderId': 1001,
        'posa': {
          'code': 'POSA001',
          'description': 'Reflorestação Norte'
        },
        'posp': {
          'code': 'POSP001',
          'description': 'Pastagens Melhoradas'
        },
        'parcels': getMockParcels().where((p) => p.id.contains('1')).toList(),
      },
      {
        'id': 2,
        'startingDate': '2025-04-15T00:00:00',
        'finishingDate': '2025-08-15T00:00:00',
        'issueDate': '2025-04-01T00:00:00',
        'awardDate': '2025-04-05T00:00:00',
        'serviceProviderId': 1002,
        'posa': {
          'code': 'POSA002',
          'description': 'Manutenção Sul'
        },
        'posp': {
          'code': 'POSP002',
          'description': 'Conservação Florestal'
        },
        'parcels': getMockParcels().where((p) => p.id.contains('2')).toList(),
      },
      {
        'id': 3,
        'startingDate': '2025-06-02T00:00:00',
        'finishingDate': '2025-09-15T00:00:00',
        'issueDate': '2025-05-20T00:00:00',
        'awardDate': '2025-05-25T00:00:00',
        'serviceProviderId': 1003,
        'posa': {
          'code': 'POSA003',
          'description': 'Monitorização Leste'
        },
        'posp': {
          'code': 'POSP003',
          'description': 'Vigilância Ambiental'
        },
        'parcels': getMockParcels().where((p) => p.id.contains('3')).toList(),
      },
    ];
  }
}