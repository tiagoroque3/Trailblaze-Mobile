// lib/services/parcel_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/parcel.dart';

class ParcelService {
  static const String baseUrl = 'https://trailblaze-460312.appspot.com/rest';

  /// Busca todas as parcelas/folhas de obra
  static Future<List<Parcel>> fetchParcels({String? jwtToken}) async {
    try {
      final Uri url = Uri.parse('$baseUrl/parcels'); // Endpoint hipotético para buscar parcelas
      
      final Map<String, String> headers = {
        'Content-Type': 'application/json; charset=UTF-8',
      };
      
      if (jwtToken != null) {
        headers['Authorization'] = 'Bearer $jwtToken';
      }

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((json) => Parcel.fromJson(json)).toList();
      } else {
        print('Erro ao buscar parcelas: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Erro na requisição de parcelas: $e');
      return [];
    }
  }

  /// Dados de exemplo caso a API não esteja disponível
  static List<Parcel> getMockParcels() {
    return [
      Parcel(
        id: '1',
        name: 'Folha de Obra A',
        description: 'Área de reflorestação norte',
        coordinates: [
          [40.7128, -74.0060], // Nova York como exemplo
          [40.7138, -74.0050],
          [40.7148, -74.0070],
          [40.7138, -74.0080],
        ],
        color: '#FF0000',
      ),
      Parcel(
        id: '2',
        name: 'Folha de Obra B',
        description: 'Área de manutenção sul',
        coordinates: [
          [40.7100, -74.0100],
          [40.7110, -74.0090],
          [40.7120, -74.0110],
          [40.7110, -74.0120],
        ],
        color: '#00FF00',
      ),
      Parcel(
        id: '3',
        name: 'Folha de Obra C',
        description: 'Área de monitorização leste',
        coordinates: [
          [40.7080, -74.0020],
          [40.7090, -74.0010],
          [40.7100, -74.0030],
          [40.7090, -74.0040],
        ],
        color: '#0000FF',
      ),
    ];
  }
}