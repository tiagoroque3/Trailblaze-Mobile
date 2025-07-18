import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapUtils {
  /// Checks if a geographical point is inside a polygon using the Ray Casting algorithm.
  static bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) {
      // A polygon must have at least 3 vertices
      return false;
    }

    int crossings = 0;
    for (int i = 0; i < polygon.length; i++) {
      LatLng p1 = polygon[i];
      LatLng p2 = polygon[(i + 1) % polygon.length];

      // Check if the ray from the point intersects with the edge (p1, p2)
      if (((p1.latitude <= point.latitude && point.latitude < p2.latitude) ||
          (p2.latitude <= point.latitude && point.latitude < p1.latitude))) {
        // Calculate the x-coordinate (longitude) of the intersection
        double intersectionLongitude = (point.latitude - p1.latitude) *
                (p2.longitude - p1.longitude) /
                (p2.latitude - p1.latitude) +
            p1.longitude;

        // If the intersection is to the right of the point, it's a crossing
        if (point.longitude < intersectionLongitude) {
          crossings++;
        }
      }
    }

    // An odd number of crossings means the point is inside the polygon
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
    return LatLngBounds(
        northeast: LatLng(x1!, y1!), southwest: LatLng(x0!, y0!));
  }
}