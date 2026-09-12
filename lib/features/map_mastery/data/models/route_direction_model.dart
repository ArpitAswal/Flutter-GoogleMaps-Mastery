import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

/// Travel modes supported by the Directions API for Android/iOS.
enum TravelMode {
  driving('driving'),
  transit('transit'),
  walking('walking'),
  twoWheeler('TWO_WHEELER');

  final String apiValue;
  const TravelMode(this.apiValue);
}

/// Immutable DTO for a single-mode Directions API response.
@immutable
class RouteDirectionModel {
  final TravelMode mode;
  final String encodedPolyline;
  final List<LatLng> decodedPoints;
  final LatLngBounds bounds;
  final String distanceText;
  final String durationText;

  /// Non-null only for driving/two-wheeler when departure_time=now.
  final String? durationInTrafficText;

  const RouteDirectionModel({
    required this.mode,
    required this.encodedPolyline,
    required this.decodedPoints,
    required this.bounds,
    required this.distanceText,
    required this.durationText,
    this.durationInTrafficText,
  });

  factory RouteDirectionModel.fromJson(
      TravelMode mode, Map<String, dynamic> json) {
    final route =
        (json['routes'] as List<dynamic>).first as Map<String, dynamic>;
    final leg =
        (route['legs'] as List<dynamic>).first as Map<String, dynamic>;
    final encoded =
        (route['overview_polyline'] as Map<String, dynamic>)['points']
            as String;

    final decoded = PolylinePoints.decodePolyline(encoded)
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    final boundsJson = route['bounds'] as Map<String, dynamic>;
    final ne = boundsJson['northeast'] as Map<String, dynamic>;
    final sw = boundsJson['southwest'] as Map<String, dynamic>;

    return RouteDirectionModel(
      mode: mode,
      encodedPolyline: encoded,
      decodedPoints: List.unmodifiable(decoded),
      bounds: LatLngBounds(
        southwest: LatLng(
          (sw['lat'] as num).toDouble(),
          (sw['lng'] as num).toDouble(),
        ),
        northeast: LatLng(
          (ne['lat'] as num).toDouble(),
          (ne['lng'] as num).toDouble(),
        ),
      ),
      distanceText:
          (leg['distance'] as Map<String, dynamic>)['text'] as String? ?? '',
      durationText:
          (leg['duration'] as Map<String, dynamic>)['text'] as String? ?? '',
      durationInTrafficText: leg['duration_in_traffic'] != null
          ? (leg['duration_in_traffic'] as Map<String, dynamic>)['text']
              as String?
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RouteDirectionModel &&
          runtimeType == other.runtimeType &&
          mode == other.mode &&
          encodedPolyline == other.encodedPolyline;

  @override
  int get hashCode => Object.hash(mode, encodedPolyline);
}
