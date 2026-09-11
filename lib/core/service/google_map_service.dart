import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

class GoogleMapsService {
  final http.Client _client = http.Client();

  /// Fetch route points, total distance, and duration between two coordinates
  Future<Map<String, dynamic>?> getDirections({
    required LatLng origin,
    required LatLng destination,
    required String mode,
  }) async {
    final String url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&mode=$mode&departure_time=now&key=${AppConstants.googleMapsApiKey}';
    // departure_time=now is REQUIRED to get live traffic data

    final response = await _client.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK' && (data['routes'] as List).isNotEmpty) {
        final route = data['routes'][0];
        // Extract distance and duration for the UI
        final String encodedPolyline = route['overview_polyline']['points'];
        // Decode the string into coordinate points
        // final PolylinePoints polylinePoints = PolylinePoints(
        //   apiKey: AppConstants.googleMapsApiKey,
        // );
        final List<PointLatLng> decodedPoints = PolylinePoints.decodePolyline(
          encodedPolyline,
        );
        // Convert PointLatLng to Google Maps LatLng
        final List<LatLng> coordinates = decodedPoints
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();

        final leg = route['legs'][0];
        return {
          'points': coordinates,
          'distance': leg['distance']['text'],
          // Check for duration_in_traffic. It only exists if departure_time=now and the travel mode is driving or two-wheeler.
          'traffic_duration': (leg['duration_in_traffic'] != null)
              ? leg['duration_in_traffic']['text']
              : '', // Fallback to standard duration for walking/transit
          'normal_duration': leg['duration']['text'],
          'bounds': route['bounds'],
        };
      }
    }
    return null;
  }

  /// Search places by text query (Places Autocomplete API)
  Future<List<Map<String, String>>> searchPlaces(String query) async {
    if (query.isEmpty) return [];
    final String url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(query)}&key=${AppConstants.googleMapsApiKey}';

    final response = await _client.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List predictions = data['predictions'];
      return predictions.map<Map<String, String>>((item) {
        return {
          'place_id': item['place_id'] as String,
          'description': item['description'] as String,
          'main_text':
              item['structured_formatting']['main_text'] as String? ??
              item['description'],
        };
      }).toList();
    }
    return [];
  }

  /// Convert place_id to LatLng coordinates (Place Details API)
  Future<LatLng?> getPlaceCoordinates(String placeId) async {
    final String url =
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=geometry&key=${AppConstants.googleMapsApiKey}';

    final response = await _client.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final location = data['result']['geometry']['location'];
      return LatLng(location['lat'], location['lng']);
    }
    return null;
  }

  /// Convert LatLng coordinates to readable address (Reverse Geocoding API)
  Future<String> getAddressFromCoordinates(LatLng point) async {
    final String url =
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=${point.latitude},${point.longitude}&key=${AppConstants.googleMapsApiKey}';

    final response = await _client.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if ((data['results'] as List).isNotEmpty) {
        return data['results'][0]['formatted_address'];
      }
    }
    return 'Address not found';
  }

  Future<List<LatLng>> getRouteCoordinates({
    required LatLng origin,
    required LatLng destination,
  }) async {
    List<LatLng> polylineCoordinates = [];
    PolylinePoints polylinePoints = PolylinePoints(
      apiKey: AppConstants.googleMapsApiKey,
    );

    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      request: PolylineRequest(
        origin: PointLatLng(origin.latitude, origin.longitude),
        destination: PointLatLng(destination.latitude, destination.longitude),
        mode: TravelMode.twoWheeler,
      ),
    );

    if (result.points.isNotEmpty) {
      for (var point in result.points) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      }
    }

    return polylineCoordinates;
  }
}
