import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../data/models/live_trip_model.dart';
import '../../data/models/route_direction_model.dart';

enum LiveTrackingStatus {
  idle,
  creatingTrip,
  driverTracking,
  viewerConnecting,
  viewerTracking,
  completed,
  cancelled,
  failure,
}

/// Immutable view state for [LiveTrackingCubit].
///
/// Both driver and viewer session data live in the same state object.
/// [isTerminal] is true for completed/cancelled/failure — streams are stopped
/// but final route/metrics are retained for the session summary.
@immutable
class LiveTrackingState {
  final LiveTrackingStatus status;

  /// Firestore trip ID — set once the document is successfully created.
  final String? tripId;

  /// Full Firestore document (used primarily by the viewer path).
  final LiveTripModel? trip;

  /// Latest accepted driver position for the vehicle marker.
  final LatLng? driverPosition;

  /// Vehicle heading in degrees clockwise from north, normalised to [0, 360).
  final double bearing;

  final String? remainingDistance;
  final String? remainingDuration;

  /// Route used for polyline rendering and remaining-distance calculation.
  final RouteDirectionModel? route;

  final String? errorMessage;

  const LiveTrackingState({
    this.status = LiveTrackingStatus.idle,
    this.tripId,
    this.trip,
    this.driverPosition,
    this.bearing = 0.0,
    this.remainingDistance,
    this.remainingDuration,
    this.route,
    this.errorMessage,
  });

  bool get isTerminal =>
      status == LiveTrackingStatus.completed ||
      status == LiveTrackingStatus.cancelled ||
      status == LiveTrackingStatus.failure;

  LiveTrackingState copyWith({
    LiveTrackingStatus? status,
    String? tripId,
    LiveTripModel? trip,
    LatLng? driverPosition,
    double? bearing,
    String? remainingDistance,
    String? remainingDuration,
    RouteDirectionModel? route,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LiveTrackingState(
      status: status ?? this.status,
      tripId: tripId ?? this.tripId,
      trip: trip ?? this.trip,
      driverPosition: driverPosition ?? this.driverPosition,
      bearing: bearing ?? this.bearing,
      remainingDistance: remainingDistance ?? this.remainingDistance,
      remainingDuration: remainingDuration ?? this.remainingDuration,
      route: route ?? this.route,
      errorMessage:
          clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
