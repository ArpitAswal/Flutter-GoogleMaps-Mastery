import 'package:geolocator/geolocator.dart';
import '../data_sources/trip_firestore_data_source.dart';
import '../models/live_trip_model.dart';
import '../../utils/map_result.dart';

/// Wraps [TripFirestoreDataSource] and the [Geolocator] GPS stream.
/// Converts Firestore/platform failures into typed [MapResult] values.
class TrackingRepository {
  final TripFirestoreDataSource _dataSource;

  /// GPS accuracy and distance filter applied to the foreground stream.
  static const _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 3, // emit only when the device has moved >= 3 m
  );

  const TrackingRepository({required TripFirestoreDataSource dataSource})
      : _dataSource = dataSource;

  // ── Trip lifecycle ────────────────────────────────────────────────────────

  /// Creates the trip document first; returns the [tripId] on success.
  /// The Cubit must not start location streaming until this succeeds.
  Future<MapResult<String>> createTrip(LiveTripModel trip) async {
    try {
      await _dataSource.createTrip(trip);
      return MapSuccess(trip.tripId);
    } catch (e) {
      return MapFailure('Failed to start trip: ${e.runtimeType}');
    }
  }

  /// Merge-updates driver location telemetry.
  /// Throttling to <= 1 Hz is enforced by [LiveTrackingCubit].
  Future<MapResult<void>> updateDriverLocation(
    String tripId,
    Map<String, dynamic> locationData,
  ) async {
    try {
      await _dataSource.updateDriverLocation(tripId, locationData);
      return const MapSuccess(null);
    } catch (e) {
      return MapFailure('Location update failed: ${e.runtimeType}');
    }
  }

  /// Marks trip completed (terminal state).
  Future<MapResult<void>> completeTrip(String tripId) async {
    try {
      await _dataSource.completeTrip(tripId);
      return const MapSuccess(null);
    } catch (e) {
      return MapFailure('End trip failed: ${e.runtimeType}');
    }
  }

  /// Marks trip cancelled (terminal state).
  Future<MapResult<void>> cancelTrip(String tripId) async {
    try {
      await _dataSource.cancelTrip(tripId);
      return const MapSuccess(null);
    } catch (e) {
      return MapFailure('Cancel trip failed: ${e.runtimeType}');
    }
  }

  // ── Streams ───────────────────────────────────────────────────────────────

  /// Real-time Firestore updates for [tripId].
  /// Emits [null] for missing or malformed documents — see [TripFirestoreDataSource].
  Stream<LiveTripModel?> watchTrip(String tripId) =>
      _dataSource.watchTrip(tripId);

  /// Foreground hardware GPS position stream.
  Stream<Position> positionStream() =>
      Geolocator.getPositionStream(locationSettings: _locationSettings);
}
