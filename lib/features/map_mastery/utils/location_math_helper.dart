import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Pure geometry helpers used by Cubits and repositories.
class LocationMathHelper {
  LocationMathHelper._();

  /// Geographic bearing in degrees clockwise from true north, normalised to [0, 360).
  static double bearingBetween(LatLng from, LatLng to) {
    final lat1 = _toRad(from.latitude);
    final lat2 = _toRad(to.latitude);
    final dLng = _toRad(to.longitude - from.longitude);
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return (_toDeg(math.atan2(y, x)) + 360) % 360;
  }

  /// Shortest angular delta from [from] to [to] in degrees.
  /// Prevents a 359°→0° transition from spinning the marker a full revolution.
  static double shortestAngularDelta(double from, double to) {
    double delta = (to - from + 360) % 360;
    if (delta > 180) delta -= 360;
    return delta;
  }

  /// Haversine great-circle distance between two coordinates in metres.
  static double haversineDistance(LatLng a, LatLng b) {
    const earthRadiusM = 6371000.0;
    final dLat = _toRad(b.latitude - a.latitude);
    final dLng = _toRad(b.longitude - a.longitude);
    final sinDLat = math.sin(dLat / 2);
    final sinDLng = math.sin(dLng / 2);
    final c = sinDLat * sinDLat +
        math.cos(_toRad(a.latitude)) *
            math.cos(_toRad(b.latitude)) *
            sinDLng *
            sinDLng;
    return earthRadiusM * 2 * math.atan2(math.sqrt(c), math.sqrt(1 - c));
  }

  /// Projects [current] onto [route] by finding the nearest vertex, then sums
  /// remaining segment lengths from that vertex to the end. Returns 0 for < 2 points.
  static double remainingRouteDistance(LatLng current, List<LatLng> route) {
    if (route.length < 2) return 0;
    int closestIndex = 0;
    double minDist = double.infinity;
    for (int i = 0; i < route.length; i++) {
      final d = haversineDistance(current, route[i]);
      if (d < minDist) {
        minDist = d;
        closestIndex = i;
      }
    }
    double remaining = 0;
    for (int i = closestIndex; i < route.length - 1; i++) {
      remaining += haversineDistance(route[i], route[i + 1]);
    }
    return remaining;
  }

  /// Linear interpolation between two [LatLng] points. [t] must be in [0.0, 1.0].
  static LatLng interpolateLatLng(LatLng a, LatLng b, double t) {
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
  }

  static double _toRad(double deg) => deg * math.pi / 180;
  static double _toDeg(double rad) => rad * 180 / math.pi;
}
