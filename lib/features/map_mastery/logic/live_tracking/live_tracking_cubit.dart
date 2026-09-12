import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/live_trip_model.dart';
import '../../data/models/place_details_model.dart';
import '../../data/models/route_direction_model.dart';
import '../../data/repositories/tracking_repository.dart';
import '../../utils/location_math_helper.dart';
import '../../utils/map_result.dart';
import 'live_tracking_state.dart';

/// Owns both driver and viewer session lifecycles.
///
/// All [StreamSubscription] instances are stored and cancelled in [close].
/// The view may animate already-emitted marker positions but must never
/// calculate heading or write tracking data directly.
class LiveTrackingCubit extends Cubit<LiveTrackingState> {
  final TrackingRepository _repository;

  StreamSubscription<Position>? _positionSub;
  StreamSubscription<LiveTripModel?>? _firestoreSub;

  DateTime? _lastWrite;
  LatLng? _lastAcceptedPosition;

  static const _minMoveMetres = 3.0;
  static const _maxAccuracyMetres = 15.0;
  static const _writeThrottle = Duration(seconds: 1);

  LiveTrackingCubit({required TrackingRepository repository})
      : _repository = repository,
        super(const LiveTrackingState());

  // ── Driver mode ───────────────────────────────────────────────────────────

  /// Creates the Firestore document then begins streaming GPS updates.
  /// [route] defines the polyline; [origin]/[destination] populate the document.
  Future<void> startDriverSession({
    required RouteDirectionModel route,
    required PlaceDetailsModel origin,
    required PlaceDetailsModel destination,
  }) async {
    emit(state.copyWith(status: LiveTrackingStatus.creatingTrip));

    final tripId = const Uuid().v4();
    final trip = LiveTripModel(
      tripId: tripId,
      status: TripStatus.inProgress,
      driverLocation: const DriverLocationData(
        latitude: 0,
        longitude: 0,
        bearing: 0,
        speedMps: 0,
      ),
      origin: TripPlaceData(
        latitude: origin.coordinate.latitude,
        longitude: origin.coordinate.longitude,
        name: origin.name,
      ),
      destination: TripPlaceData(
        latitude: destination.coordinate.latitude,
        longitude: destination.coordinate.longitude,
        name: destination.name,
      ),
      overviewPolyline: route.encodedPolyline,
      selectedTravelMode: route.mode.apiValue,
      remainingDistance: route.distanceText,
      remainingDuration: route.durationText,
    );

    final result = await _repository.createTrip(trip);
    switch (result) {
      case MapSuccess():
        emit(state.copyWith(
          status: LiveTrackingStatus.driverTracking,
          tripId: tripId,
          route: route,
          trip: trip,
          clearError: true,
        ));
        _startPositionStream(tripId, route.decodedPoints);
      case MapFailure(:final message):
        emit(state.copyWith(
          status: LiveTrackingStatus.failure,
          errorMessage: message,
        ));
    }
  }

  void _startPositionStream(String tripId, List<LatLng> routePoints) {
    _positionSub = _repository.positionStream().listen(
      (pos) => _onNewPosition(tripId, pos, routePoints),
      onError: (_) {
        if (!isClosed && !state.isTerminal) {
          emit(state.copyWith(
            status: LiveTrackingStatus.failure,
            errorMessage:
                'Location stream interrupted. Check location permissions.',
          ));
        }
      },
    );
  }

  void _onNewPosition(
      String tripId, Position pos, List<LatLng> routePoints) {
    // Reject inaccurate fixes
    if (pos.accuracy > _maxAccuracyMetres) { return; }

    final current = LatLng(pos.latitude, pos.longitude);
    final last = _lastAcceptedPosition;

    // Reject micro-jitter
    if (last != null &&
        LocationMathHelper.haversineDistance(last, current) <
            _minMoveMetres) { return; }

    // Compute heading using shortest angular delta to prevent spin
    final double newBearing;
    if (last != null) {
      final raw = LocationMathHelper.bearingBetween(last, current);
      final delta =
          LocationMathHelper.shortestAngularDelta(state.bearing, raw);
      newBearing = (state.bearing + delta + 360) % 360;
    } else {
      newBearing = state.bearing;
    }

    _lastAcceptedPosition = current;
    emit(state.copyWith(driverPosition: current, bearing: newBearing));

    // Throttle Firestore writes to <= 1 per second
    final now = DateTime.now();
    if (_lastWrite == null ||
        now.difference(_lastWrite!) >= _writeThrottle) {
      _lastWrite = now;
      _repository.updateDriverLocation(tripId, {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'bearing': newBearing,
        'speedMps': pos.speed < 0 ? 0.0 : pos.speed,
      });

      // Update remaining distance from route projection
      if (routePoints.isNotEmpty) {
        final distM =
            LocationMathHelper.remainingRouteDistance(current, routePoints);
        emit(state.copyWith(
          remainingDistance: '${(distM / 1000).toStringAsFixed(1)} km',
        ));
      }
    }
  }

  Future<void> endTrip() async {
    final tripId = state.tripId;
    if (tripId == null) { return; }
    await _cancelSubscriptions();
    await _repository.completeTrip(tripId);
    if (!isClosed) {
      emit(state.copyWith(status: LiveTrackingStatus.completed));
    }
  }

  // ── Viewer mode ───────────────────────────────────────────────────────────

  void startViewerSession(String tripId) {
    emit(state.copyWith(
      status: LiveTrackingStatus.viewerConnecting,
      tripId: tripId,
    ));
    _firestoreSub = _repository.watchTrip(tripId).listen(
      _onTripUpdate,
      onError: (_) {
        if (!isClosed && !state.isTerminal) {
          emit(state.copyWith(
            status: LiveTrackingStatus.failure,
            errorMessage: 'Connection lost. Tap Retry to reconnect.',
          ));
        }
      },
    );
  }

  void _onTripUpdate(LiveTripModel? trip) {
    if (isClosed) { return; }

    if (trip == null) {
      // Malformed document — retain last valid data; show non-fatal banner
      if (!state.isTerminal) {
        emit(state.copyWith(
            errorMessage: 'Received an unreadable update. Retrying…'));
      }
      return;
    }

    final driverPos = trip.driverLocation.latLng;
    final last = state.driverPosition;

    final double bearing;
    if (last != null) {
      final raw = LocationMathHelper.bearingBetween(last, driverPos);
      final delta =
          LocationMathHelper.shortestAngularDelta(state.bearing, raw);
      bearing = (state.bearing + delta + 360) % 360;
    } else {
      bearing = trip.driverLocation.bearing;
    }

    final newStatus = switch (trip.status) {
      TripStatus.completed => LiveTrackingStatus.completed,
      TripStatus.cancelled => LiveTrackingStatus.cancelled,
      TripStatus.inProgress => LiveTrackingStatus.viewerTracking,
    };

    emit(state.copyWith(
      status: newStatus,
      trip: trip,
      driverPosition: driverPos,
      bearing: bearing,
      remainingDistance: trip.remainingDistance,
      remainingDuration: trip.remainingDuration,
      clearError: true,
    ));

    if (newStatus == LiveTrackingStatus.completed ||
        newStatus == LiveTrackingStatus.cancelled) {
      _cancelSubscriptions();
    }
  }

  void retryViewerConnection() {
    final tripId = state.tripId;
    if (tripId == null) { return; }
    _firestoreSub?.cancel();
    _firestoreSub = null;
    startViewerSession(tripId);
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> _cancelSubscriptions() async {
    await _positionSub?.cancel();
    await _firestoreSub?.cancel();
    _positionSub = null;
    _firestoreSub = null;
  }

  @override
  Future<void> close() async {
    await _cancelSubscriptions();
    return super.close();
  }
}
