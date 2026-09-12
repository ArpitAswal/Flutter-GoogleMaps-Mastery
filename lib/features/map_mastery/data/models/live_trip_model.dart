import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// ── Status ────────────────────────────────────────────────────────────────────

enum TripStatus {
  inProgress('in_progress'),
  completed('completed'),
  cancelled('cancelled');

  final String firestoreValue;
  const TripStatus(this.firestoreValue);

  static TripStatus fromString(String? value) {
    return TripStatus.values.firstWhere(
      (s) => s.firestoreValue == value,
      orElse: () => TripStatus.inProgress,
    );
  }
}

// ── Nested DTOs ───────────────────────────────────────────────────────────────

@immutable
class DriverLocationData {
  final double latitude;
  final double longitude;
  final double bearing;
  final double speedMps;

  const DriverLocationData({
    required this.latitude,
    required this.longitude,
    required this.bearing,
    required this.speedMps,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  factory DriverLocationData.fromMap(Map<String, dynamic>? map) {
    final m = map ?? {};
    return DriverLocationData(
      latitude: (m['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (m['longitude'] as num?)?.toDouble() ?? 0.0,
      bearing: (m['bearing'] as num?)?.toDouble() ?? 0.0,
      speedMps: (m['speedMps'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() => {
        'latitude': latitude,
        'longitude': longitude,
        'bearing': bearing,
        'speedMps': speedMps,
      };
}

@immutable
class TripPlaceData {
  final double latitude;
  final double longitude;
  final String name;

  const TripPlaceData({
    required this.latitude,
    required this.longitude,
    required this.name,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  factory TripPlaceData.fromMap(Map<String, dynamic>? map) {
    final m = map ?? {};
    return TripPlaceData(
      latitude: (m['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (m['longitude'] as num?)?.toDouble() ?? 0.0,
      name: m['name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'latitude': latitude,
        'longitude': longitude,
        'name': name,
      };
}

// ── Root model ────────────────────────────────────────────────────────────────

/// Immutable DTO for the Firestore `active_trips/{tripId}` document.
///
/// Field names match the schema exactly:
///   tripId, status,
///   driverLocation {latitude, longitude, bearing, speedMps},
///   destination {latitude, longitude, name},
///   origin {latitude, longitude, name},
///   overviewPolyline, selectedTravelMode,
///   remainingDistance, remainingDuration,
///   createdAt, updatedAt
@immutable
class LiveTripModel {
  final String tripId;
  final TripStatus status;
  final DriverLocationData driverLocation;
  final TripPlaceData destination;
  final TripPlaceData origin;
  final String overviewPolyline;
  final String selectedTravelMode;
  final String remainingDistance;
  final String remainingDuration;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const LiveTripModel({
    required this.tripId,
    required this.status,
    required this.driverLocation,
    required this.destination,
    required this.origin,
    required this.overviewPolyline,
    required this.selectedTravelMode,
    required this.remainingDistance,
    required this.remainingDuration,
    this.createdAt,
    this.updatedAt,
  });

  /// Deserialises a Firestore snapshot. Throws [StateError] only if the document
  /// has no data at all; individual field failures fall back to safe defaults.
  factory LiveTripModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Firestore document \${doc.id} has no data');
    }
    return LiveTripModel(
      tripId: data['tripId'] as String? ?? doc.id,
      status: TripStatus.fromString(data['status'] as String?),
      driverLocation: DriverLocationData.fromMap(
          data['driverLocation'] as Map<String, dynamic>?),
      destination: TripPlaceData.fromMap(
          data['destination'] as Map<String, dynamic>?),
      origin:
          TripPlaceData.fromMap(data['origin'] as Map<String, dynamic>?),
      overviewPolyline: data['overviewPolyline'] as String? ?? '',
      selectedTravelMode:
          data['selectedTravelMode'] as String? ?? 'driving',
      remainingDistance: data['remainingDistance'] as String? ?? '',
      remainingDuration: data['remainingDuration'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Serialises to Firestore. [createdAt]/[updatedAt] use server timestamps on write.
  Map<String, dynamic> toFirestore() => {
        'tripId': tripId,
        'status': status.firestoreValue,
        'driverLocation': driverLocation.toMap(),
        'destination': destination.toMap(),
        'origin': origin.toMap(),
        'overviewPolyline': overviewPolyline,
        'selectedTravelMode': selectedTravelMode,
        'remainingDistance': remainingDistance,
        'remainingDuration': remainingDuration,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  LiveTripModel copyWith({
    TripStatus? status,
    DriverLocationData? driverLocation,
    String? remainingDistance,
    String? remainingDuration,
  }) {
    return LiveTripModel(
      tripId: tripId,
      status: status ?? this.status,
      driverLocation: driverLocation ?? this.driverLocation,
      destination: destination,
      origin: origin,
      overviewPolyline: overviewPolyline,
      selectedTravelMode: selectedTravelMode,
      remainingDistance: remainingDistance ?? this.remainingDistance,
      remainingDuration: remainingDuration ?? this.remainingDuration,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  bool get isTerminal =>
      status == TripStatus.completed || status == TripStatus.cancelled;
}
