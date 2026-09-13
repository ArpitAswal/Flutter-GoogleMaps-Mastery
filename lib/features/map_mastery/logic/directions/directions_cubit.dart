import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../data/models/place_details_model.dart';
import '../../data/models/route_direction_model.dart';
import '../../data/repositories/map_repository.dart';
import '../../utils/map_result.dart';
import 'directions_state.dart';

/// Manages multi-modal route comparison, mode selection, and active route state.
///
/// All four modes are fetched concurrently with [Future.wait]; partial failures
/// are preserved in [DirectionsState.modeResults] rather than aborting.
class DirectionsCubit extends Cubit<DirectionsState> {
  final MapRepository _repository;

  DirectionsCubit({required MapRepository repository})
      : _repository = repository,
        super(const DirectionsState());

  // ── Input ─────────────────────────────────────────────────────────────────

  void setOrigin(PlaceDetailsModel place) =>
      emit(state.copyWith(origin: place, clearError: true));

  void setDestination(PlaceDetailsModel place) =>
      emit(state.copyWith(destination: place, clearError: true));

  /// Swaps origin and destination atomically.
  void swapOriginDestination() {
    if (state.origin == null || state.destination == null) return;
    final tempOrigin  = state.origin;
    emit(state.copyWith(
      origin: state.destination,
      destination: tempOrigin,
      clearError: true,
    ));
  }

  void selectMode(TravelMode mode) {
    final bounds = _boundsForMode(state.modeResults, mode);
    emit(state.copyWith(selectedMode: mode, routeBounds: bounds));
  }

  // ── Fetch ─────────────────────────────────────────────────────────────────

  Future<void> fetchAllRoutes() async {
    final origin = state.origin;
    final destination = state.destination;

    if (origin == null || destination == null) {
      emit(state.copyWith(
        status: DirectionsStatus.invalidInput,
        errorMessage: 'Please set both an origin and a destination.',
      ));
      return;
    }

    // Mark all modes as loading simultaneously
    emit(state.copyWith(
      status: DirectionsStatus.loading,
      modeResults: {for (final m in TravelMode.values) m: const RouteLoading()},
      clearBounds: true,
      clearError: true,
    ));

    // Concurrently fetch all four modes; eagerError:false preserves partial results
    final futures = TravelMode.values
        .map((mode) => _repository.getDirections(
              origin: origin.coordinate,
              destination: destination.coordinate,
              mode: mode,
            ))
        .toList();

    final results = await Future.wait(futures, eagerError: false);

    final updated = <TravelMode, RouteResult>{};
    for (int i = 0; i < TravelMode.values.length; i++) {
      final mode = TravelMode.values[i];
      updated[mode] = switch (results[i]) {
        MapSuccess(:final data) => RouteReady(data),
        MapFailure(:final message) => RouteFailed(message),
      };
    }

    final bounds =
        _boundsForMode(updated, state.selectedMode);

    emit(state.copyWith(
      status: DirectionsStatus.ready,
      modeResults: updated,
      routeBounds: bounds,
    ));
  }

  // ── Reset ─────────────────────────────────────────────────────────────────

  void clear() => emit(const DirectionsState());

  // ── Private ───────────────────────────────────────────────────────────────

  static LatLngBounds? _boundsForMode(
      Map<TravelMode, RouteResult> results, TravelMode mode) {
    final preferred = results[mode];
    if (preferred is RouteReady) return preferred.route.bounds;
    // Fall back to first available successful mode
    for (final r in results.values) {
      if (r is RouteReady) return r.route.bounds;
    }
    return null;
  }
}
