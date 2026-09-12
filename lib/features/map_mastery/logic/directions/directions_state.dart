import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../data/models/place_details_model.dart';
import '../../data/models/route_direction_model.dart';

enum DirectionsStatus { idle, loading, ready, invalidInput, failure }

// ── Per-mode result ───────────────────────────────────────────────────────────

sealed class RouteResult {
  const RouteResult();
}

final class RouteReady extends RouteResult {
  final RouteDirectionModel route;
  const RouteReady(this.route);
}

final class RouteLoading extends RouteResult {
  const RouteLoading();
}

final class RouteFailed extends RouteResult {
  final String message;
  const RouteFailed(this.message);
}

// ── State ─────────────────────────────────────────────────────────────────────

/// Immutable view state for [DirectionsCubit].
///
/// - [modeResults] holds one [RouteResult] per [TravelMode]; partial failures
///   are preserved and displayed alongside successful modes.
/// - [activeRoute] returns the selected mode's route or null if not yet ready.
/// - [routeBounds] is set from the [selectedMode]'s result for camera fitting.
@immutable
class DirectionsState {
  final DirectionsStatus status;
  final PlaceDetailsModel? origin;
  final PlaceDetailsModel? destination;
  final Map<TravelMode, RouteResult> modeResults;
  final TravelMode selectedMode;
  final LatLngBounds? routeBounds;
  final String? errorMessage;

  const DirectionsState({
    this.status = DirectionsStatus.idle,
    this.origin,
    this.destination,
    this.modeResults = const {},
    this.selectedMode = TravelMode.driving,
    this.routeBounds,
    this.errorMessage,
  });

  RouteDirectionModel? get activeRoute {
    final result = modeResults[selectedMode];
    return result is RouteReady ? result.route : null;
  }

  DirectionsState copyWith({
    DirectionsStatus? status,
    PlaceDetailsModel? origin,
    PlaceDetailsModel? destination,
    Map<TravelMode, RouteResult>? modeResults,
    TravelMode? selectedMode,
    LatLngBounds? routeBounds,
    String? errorMessage,
    bool clearOrigin = false,
    bool clearDestination = false,
    bool clearBounds = false,
    bool clearError = false,
  }) {
    return DirectionsState(
      status: status ?? this.status,
      origin: clearOrigin ? null : (origin ?? this.origin),
      destination:
          clearDestination ? null : (destination ?? this.destination),
      modeResults: modeResults ?? this.modeResults,
      selectedMode: selectedMode ?? this.selectedMode,
      routeBounds: clearBounds ? null : (routeBounds ?? this.routeBounds),
      errorMessage:
          clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
