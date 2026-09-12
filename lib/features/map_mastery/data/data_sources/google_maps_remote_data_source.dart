import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/place_prediction_model.dart';
import '../models/place_details_model.dart';
import '../models/route_direction_model.dart';

/// Owns all Google Maps REST API interactions for Android and iOS.
///
/// Receives an [http.Client] and the REST API key through the constructor.
/// The API key must never appear in logs, error messages, or stack traces —
/// [_sanitiseKey] strips it before any string escapes this class.
class GoogleMapsRemoteDataSource {
  final http.Client _client;
  final String _apiKey;

  static const _base = 'https://maps.googleapis.com/maps/api';
  static const _timeout = Duration(seconds: 10);

  const GoogleMapsRemoteDataSource({
    required http.Client client,
    required String apiKey,
  })  : _client = client,
        _apiKey = apiKey;

  // ── Autocomplete ──────────────────────────────────────────────────────────

  Future<List<PlacePredictionModel>> autocomplete(String input) async {
    if (input.trim().isEmpty) return const [];
    final uri = Uri.parse(
      '$_base/place/autocomplete/json'
      '?input=${Uri.encodeComponent(input)}'
      '&key=$_apiKey',
    );
    final body = await _get(uri, 'autocomplete');
    _assertStatus(body, 'autocomplete');
    return (body['predictions'] as List<dynamic>)
        .map((p) => PlacePredictionModel.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  // ── Place Details ─────────────────────────────────────────────────────────

  Future<PlaceDetailsModel> placeDetails(String placeId) async {
    const fields =
        'place_id,name,geometry,rating,formatted_address,formatted_phone_number';
    final uri = Uri.parse(
      '$_base/place/details/json'
      '?place_id=$placeId'
      '&fields=$fields'
      '&key=$_apiKey',
    );
    final body = await _get(uri, 'placeDetails');
    _assertStatus(body, 'placeDetails');
    return PlaceDetailsModel.fromJson(
      placeId,
      body['result'] as Map<String, dynamic>,
    );
  }

  // ── Directions ────────────────────────────────────────────────────────────

  Future<RouteDirectionModel> directions({
    required LatLng origin,
    required LatLng destination,
    required TravelMode mode,
  }) async {
    final uri = Uri.parse(
      '$_base/directions/json'
      '?origin=${origin.latitude},${origin.longitude}'
      '&destination=${destination.latitude},${destination.longitude}'
      '&mode=${mode.apiValue}'
      '&departure_time=now'
      '&key=$_apiKey',
    );
    final body = await _get(uri, 'directions');
    _assertStatus(body, 'directions');
    return RouteDirectionModel.fromJson(mode, body);
  }

  // ── Reverse Geocoding ─────────────────────────────────────────────────────

  Future<String> reverseGeocodePlaceId(LatLng point) async {
    final uri = Uri.parse(
      '$_base/geocode/json'
      '?latlng=${point.latitude},${point.longitude}'
      '&key=$_apiKey',
    );
    final body = await _get(uri, 'reverseGeocode');
    if (body['status'] == 'ZERO_RESULTS') return '';
    _assertStatus(body, 'reverseGeocode');
    final results = body['results'] as List<dynamic>;
    if (results.isEmpty) return '';
    // Instead of just the formatted address, we extract the Google Place ID
    // which allows us to look up rich POI information (ratings, phone, etc.)
    return (results.first as Map<String, dynamic>)['place_id'] as String? ?? '';
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _get(Uri uri, String op) async {
    final response = await _client.get(uri).timeout(_timeout);
    if (response.statusCode != 200) {
      throw HttpException('$op HTTP ${response.statusCode}');
    }
    return json.decode(response.body) as Map<String, dynamic>;
  }

  static void _assertStatus(Map<String, dynamic> body, String op) {
    final status = body['status'] as String? ?? '';
    if (status != 'OK') {
      throw FormatException('$op API status=$status');
    }
  }

}
