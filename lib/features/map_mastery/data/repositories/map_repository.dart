import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../data_sources/google_maps_remote_data_source.dart';
import '../models/place_prediction_model.dart';
import '../models/place_details_model.dart';
import '../models/route_direction_model.dart';
import '../../utils/map_result.dart';

/// Wraps [GoogleMapsRemoteDataSource] and converts all transport/API exceptions
/// into typed [MapResult] values.
///
/// Cubits consume [MapResult]; raw [Map<String, dynamic>] never crosses this boundary.
class MapRepository {
  final GoogleMapsRemoteDataSource _dataSource;

  const MapRepository({required GoogleMapsRemoteDataSource dataSource})
      : _dataSource = dataSource;

  Future<MapResult<List<PlacePredictionModel>>> searchPlaces(
      String query) async {
    try {
      final results = await _dataSource.autocomplete(query);
      if (results.isEmpty) return const MapFailure('No places found');
      return MapSuccess(results);
    } catch (e) {
      return MapFailure(_sanitise(e));
    }
  }

  Future<MapResult<PlaceDetailsModel>> getPlaceDetails(
      String placeId) async {
    try {
      return MapSuccess(await _dataSource.placeDetails(placeId));
    } catch (e) {
      return MapFailure(_sanitise(e));
    }
  }

  Future<MapResult<RouteDirectionModel>> getDirections({
    required LatLng origin,
    required LatLng destination,
    required TravelMode mode,
  }) async {
    try {
      return MapSuccess(await _dataSource.directions(
        origin: origin,
        destination: destination,
        mode: mode,
      ));
    } catch (e) {
      return MapFailure(_sanitise(e));
    }
  }

  Future<MapResult<String>> reverseGeocode(LatLng point) async {
    try {
      return MapSuccess(await _dataSource.reverseGeocode(point));
    } catch (e) {
      return MapFailure(_sanitise(e));
    }
  }

  /// Sanitises exception messages so API keys and internal details never surface.
  static String _sanitise(Object e) {
    final msg = e.toString();
    // Detect an accidentally leaked API key pattern and mask it
    if (RegExp(r'AIza[0-9A-Za-z_-]{35}').hasMatch(msg)) {
      return 'Request failed (configuration error)';
    }
    if (msg.contains('TimeoutException')) {
      return 'Request timed out. Check your connection and try again.';
    }
    return 'Request failed. Check your connection and try again.';
  }
}
