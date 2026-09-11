import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapHelpers {
  /// Calculates the rotation angle so the vehicle marker faces forward
  double calculateBearing(LatLng start, LatLng end) {
    final double startLat = start.latitude * (math.pi / 180.0);
    final double startLng = start.longitude * (math.pi / 180.0);
    final double endLat = end.latitude * (math.pi / 180.0);
    final double endLng = end.longitude * (math.pi / 180.0);

    final double dLng = endLng - startLng;
    final double y = math.sin(dLng) * math.cos(endLat);
    final double x = math.cos(startLat) * math.sin(endLat) -
        math.sin(startLat) * math.cos(endLat) * math.cos(dLng);

    return (math.atan2(y, x) * (180.0 / math.pi) + 360.0) % 360.0;
  }

  /// Convert an asset image into a resized BitmapDescriptor marker
  /// Manually loads and scales the custom asset for the map marker
  Future<BitmapDescriptor> getVehicleIcon() async {
    try {
      final ByteData data = await rootBundle.load(
        'assets/icons/delivery_bike.png',
      );
      final ui.Codec codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: 60, // Adjust for perfect map proportions
      );
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ByteData? byteData = await frameInfo.image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
    } catch (_) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    }
  }

  /// Calculates the remaining distance in meters along the polyline ahead of the driver
  double calculateRemainingDistanceInMeters({
    required LatLng currentPos,
    required List<LatLng> polylinePoints,
  }) {
    if (polylinePoints.isEmpty) return 0.0;

    // 1. Find the point on the polyline closest to the driver's current position
    int closestIndex = 0;
    double shortestDistance = double.infinity;

    for (int i = 0; i < polylinePoints.length; i++) {
      final double dist = Geolocator.distanceBetween(
        currentPos.latitude,
        currentPos.longitude,
        polylinePoints[i].latitude,
        polylinePoints[i].longitude,
      );
      if (dist < shortestDistance) {
        shortestDistance = dist;
        closestIndex = i;
      }
    }

    // 2. Sum up the distance from current position to the upcoming polyline points
    double remainingDistance = Geolocator.distanceBetween(
      currentPos.latitude,
      currentPos.longitude,
      polylinePoints[closestIndex].latitude,
      polylinePoints[closestIndex].longitude,
    );

    for (int i = closestIndex; i < polylinePoints.length - 1; i++) {
      remainingDistance += Geolocator.distanceBetween(
        polylinePoints[i].latitude,
        polylinePoints[i].longitude,
        polylinePoints[i + 1].latitude,
        polylinePoints[i + 1].longitude,
      );
    }

    return remainingDistance;
  }

  /// Formats raw meters into human-readable distance (e.g., "850 m" or "2.4 km")
  String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toInt()} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }

  /// Estimates remaining duration based on proportional distance progress
  String calculateRemainingDuration({
    required double remainingDistanceMeters,
    required double totalDistanceMeters,
    required int initialDurationSeconds,
  }) {
    if (totalDistanceMeters <= 0 || remainingDistanceMeters <= 0) {
      return 'Arrived';
    }

    // Calculate ratio: remainingDistance / totalDistance
    final double ratio = (remainingDistanceMeters / totalDistanceMeters).clamp(0.0, 1.0);
    final int remainingSeconds = (initialDurationSeconds * ratio).toInt();

    final int minutes = (remainingSeconds / 60).ceil();
    if (minutes < 1) {
      return '< 1 min';
    } else if (minutes >= 60) {
      final int hours = minutes ~/ 60;
      final int remMins = minutes % 60;
      return '${hours}h ${remMins}m';
    } else {
      return '$minutes mins';
    }
  }

  // ==========================================
  // LOCAL CLIENT-SIDE METRICS CALCULATIONS
  // ==========================================
  double calculateRemainingMeters({
    required LatLng currentPos,
    required List<LatLng> polylinePoints,
  }) {
    if (polylinePoints.isEmpty) return 0.0;

    int closestIndex = 0;
    double shortestDistance = double.infinity;

    for (int i = 0; i < polylinePoints.length; i++) {
      final double dist = Geolocator.distanceBetween(
        currentPos.latitude,
        currentPos.longitude,
        polylinePoints[i].latitude,
        polylinePoints[i].longitude,
      );
      if (dist < shortestDistance) {
        shortestDistance = dist;
        closestIndex = i;
      }
    }

    double remainingDistance = Geolocator.distanceBetween(
      currentPos.latitude,
      currentPos.longitude,
      polylinePoints[closestIndex].latitude,
      polylinePoints[closestIndex].longitude,
    );

    for (int i = closestIndex; i < polylinePoints.length - 1; i++) {
      remainingDistance += Geolocator.distanceBetween(
        polylinePoints[i].latitude,
        polylinePoints[i].longitude,
        polylinePoints[i + 1].latitude,
        polylinePoints[i + 1].longitude,
      );
    }

    return remainingDistance;
  }

  String formatMeters(double meters) {
    if (meters < 50) return 'Arrived';
    if (meters < 1000) return '${meters.toInt()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String computeRemainingTime({
    required double remainingMeters,
    required double totalMeters,
    required int initialSeconds,
  }) {
    if (remainingMeters < 50 || totalMeters <= 0) return 'Arriving now';

    final double ratio = (remainingMeters / totalMeters).clamp(0.0, 1.0);
    final int secondsLeft = (initialSeconds * ratio).toInt();
    final int minutes = (secondsLeft / 60).ceil();

    if (minutes <= 1) return '< 1 min';
    return '$minutes mins';
  }
}
