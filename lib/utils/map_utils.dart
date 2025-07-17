import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapUtils {
  /// Checks if a geographical point is inside a polygon using the Ray Casting algorithm.
  static bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.isEmpty) {
      return false;
    }

    int crossings = 0;
    for (int i = 0; i < polygon.length; i++) {
      final p1 = polygon[i];
      final p2 = polygon[(i + 1) % polygon.length];

      if (p1.latitude == p2.latitude) continue;

      if (point.latitude < p1.latitude.clamp(p2.latitude, p1.latitude) ||
          point.latitude > p1.latitude.clamp(p1.latitude, p2.latitude)) {
        continue;
      }

      final double x = (point.latitude - p1.latitude) *
              (p2.longitude - p1.longitude) /
              (p2.latitude - p1.latitude) +
          p1.longitude;

      if (x > point.longitude) {
        crossings++;
      }
    }
    return crossings % 2 == 1;
  }

  /// Calculates the LatLngBounds from a list of points.
  static LatLngBounds boundsFromLatLngList(List<LatLng> list) {
    assert(list.isNotEmpty);
    double? x0, x1, y0, y1;
    for (LatLng latLng in list) {
      if (x0 == null) {
        x0 = x1 = latLng.latitude;
        y0 = y1 = latLng.longitude;
      } else {
        if (latLng.latitude > x1!) x1 = latLng.latitude;
        if (latLng.latitude < x0) x0 = latLng.latitude;
        if (latLng.longitude > y1!) y1 = latLng.longitude;
        if (latLng.longitude < y0!) y0 = latLng.longitude;
      }
    }
    return LatLngBounds(northeast: LatLng(x1!, y1!), southwest: LatLng(x0!, y0!));
  }
}