import 'dart:math' as math;
import '../models/trail.dart';
import '../models/parcel.dart';
import '../services/parcel_service.dart';

class ProximityDetector {
  static const double proximityThresholdKm = 5.0;

  /// Detecta proximidade entre pontos do trilho e polígonos de worksheets
  static Future<List<WorksheetProximity>> detectWorksheetProximities({
    required List<TrailPoint> trailPoints,
    String? jwtToken,
  }) async {
    if (trailPoints.isEmpty) return [];

    try {
      // Buscar todas as worksheets com parcelas
      final result = await ParcelService.fetchWorksheetsWithParcels(
        jwtToken: jwtToken,
      );

      final List<Map<String, dynamic>> worksheets = 
          List<Map<String, dynamic>>.from(result['worksheets'] ?? []);

      List<WorksheetProximity> proximities = [];

      for (final worksheet in worksheets) {
        final worksheetId = worksheet['id'].toString();
        final worksheetName = worksheet['posa']?['description'] ?? 'Worksheet $worksheetId';
        final posp = worksheet['posp']?['description'] ?? 'N/A';
        final List<Parcel> parcels = List<Parcel>.from(worksheet['parcels'] ?? []);

        double minDistance = double.infinity;

        // Verificar distância mínima entre pontos do trilho e polígonos desta worksheet
        for (final trailPoint in trailPoints) {
          for (final parcel in parcels) {
            final distance = _calculateMinDistanceToPolygon(trailPoint, parcel.coordinates);
            if (distance < minDistance) {
              minDistance = distance;
            }
          }
        }

        // Se a distância mínima for <= 5km, adicionar à lista de proximidades
        if (minDistance <= proximityThresholdKm) {
          proximities.add(WorksheetProximity(
            worksheetId: worksheetId,
            worksheetName: worksheetName,
            posp: posp,
            distanceKm: minDistance,
          ));
        }
      }

      // Ordenar por distância (mais próximo primeiro)
      proximities.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

      return proximities;
    } catch (e) {
      print('Erro ao detectar proximidades: $e');
      return [];
    }
  }

  /// Calcula a distância mínima entre um ponto e um polígono
  static double _calculateMinDistanceToPolygon(
    TrailPoint point, 
    List<List<double>> polygonCoordinates
  ) {
    if (polygonCoordinates.isEmpty) return double.infinity;

    double minDistance = double.infinity;

    // Verificar distância para cada vértice do polígono
    for (final coord in polygonCoordinates) {
      if (coord.length >= 2) {
        final distance = _calculateDistance(
          point.latitude, 
          point.longitude, 
          coord[0], 
          coord[1]
        );
        if (distance < minDistance) {
          minDistance = distance;
        }
      }
    }

    // Verificar distância para cada aresta do polígono
    for (int i = 0; i < polygonCoordinates.length; i++) {
      final current = polygonCoordinates[i];
      final next = polygonCoordinates[(i + 1) % polygonCoordinates.length];
      
      if (current.length >= 2 && next.length >= 2) {
        final distance = _calculateDistanceToLineSegment(
          point.latitude,
          point.longitude,
          current[0],
          current[1],
          next[0],
          next[1],
        );
        if (distance < minDistance) {
          minDistance = distance;
        }
      }
    }

    return minDistance;
  }

  /// Calcula a distância entre dois pontos geográficos em quilómetros
  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Raio da Terra em km

    final lat1Rad = _degToRad(lat1);
    final lat2Rad = _degToRad(lat2);
    final deltaLatRad = _degToRad(lat2 - lat1);
    final deltaLonRad = _degToRad(lon2 - lon1);

    final a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.sin(deltaLonRad / 2) * math.sin(deltaLonRad / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  /// Calcula a distância de um ponto para um segmento de linha
  static double _calculateDistanceToLineSegment(
    double px, double py,
    double x1, double y1,
    double x2, double y2,
  ) {
    final A = px - x1;
    final B = py - y1;
    final C = x2 - x1;
    final D = y2 - y1;

    final dot = A * C + B * D;
    final lenSq = C * C + D * D;

    if (lenSq == 0) {
      // O segmento é um ponto
      return _calculateDistance(px, py, x1, y1);
    }

    final param = dot / lenSq;

    double xx, yy;

    if (param < 0) {
      xx = x1;
      yy = y1;
    } else if (param > 1) {
      xx = x2;
      yy = y2;
    } else {
      xx = x1 + param * C;
      yy = y1 + param * D;
    }

    return _calculateDistance(px, py, xx, yy);
  }

  static double _degToRad(double deg) => deg * math.pi / 180;
}