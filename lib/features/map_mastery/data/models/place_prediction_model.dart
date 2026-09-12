import 'package:flutter/foundation.dart';

/// Immutable DTO for a single Places Autocomplete prediction.
@immutable
class PlacePredictionModel {
  final String placeId;
  final String primaryText;
  final String secondaryText;
  final String displayText;

  const PlacePredictionModel({
    required this.placeId,
    required this.primaryText,
    required this.secondaryText,
    required this.displayText,
  });

  factory PlacePredictionModel.fromJson(Map<String, dynamic> json) {
    final structured =
        json['structured_formatting'] as Map<String, dynamic>? ?? {};
    final primary =
        structured['main_text'] as String? ?? json['description'] as String? ?? '';
    final secondary = structured['secondary_text'] as String? ?? '';
    return PlacePredictionModel(
      placeId: json['place_id'] as String? ?? '',
      primaryText: primary,
      secondaryText: secondary,
      displayText: json['description'] as String? ?? primary,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlacePredictionModel &&
          runtimeType == other.runtimeType &&
          placeId == other.placeId;

  @override
  int get hashCode => placeId.hashCode;

  @override
  String toString() =>
      'PlacePredictionModel(placeId: \$placeId, displayText: \$displayText)';
}
