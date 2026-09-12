import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Immutable DTO for full Place Details API result.
@immutable
class PlaceDetailsModel {
  final String id;
  final String name;
  final LatLng coordinate;
  final double? rating;
  final String address;
  final String? phoneNumber;

  const PlaceDetailsModel({
    required this.id,
    required this.name,
    required this.coordinate,
    this.rating,
    required this.address,
    this.phoneNumber,
  });

  factory PlaceDetailsModel.fromJson(
      String placeId, Map<String, dynamic> result) {
    final geom = result['geometry'] as Map<String, dynamic>;
    final loc = geom['location'] as Map<String, dynamic>;
    return PlaceDetailsModel(
      id: placeId,
      name: result['name'] as String? ?? '',
      coordinate: LatLng(
        (loc['lat'] as num).toDouble(),
        (loc['lng'] as num).toDouble(),
      ),
      rating: (result['rating'] as num?)?.toDouble(),
      address: result['formatted_address'] as String? ??
          result['vicinity'] as String? ??
          '',
      phoneNumber: result['formatted_phone_number'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaceDetailsModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'PlaceDetailsModel(id: \$id, name: \$name, address: \$address)';
}
