import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/place_details_model.dart';
import '../../data/repositories/map_repository.dart';
import '../../utils/map_result.dart';
import 'search_places_state.dart';

/// Manages debounced autocomplete search and place selection.
///
/// Rules enforced here:
/// - Debounce interval: exactly 500 ms.
/// - Empty/whitespace queries emit [SearchStatus.idle] immediately.
/// - A stale-request token prevents an older response from overwriting a newer query.
/// - All [Timer] instances are cancelled in [close].
class SearchPlacesCubit extends Cubit<SearchPlacesState> {
  final MapRepository _repository;
  Timer? _debounceTimer;
  int _requestToken = 0;

  static const _debounce = Duration(milliseconds: 500);

  SearchPlacesCubit({required MapRepository repository})
      : _repository = repository,
        super(const SearchPlacesState());

  // ── Query ─────────────────────────────────────────────────────────────────

  void onQueryChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      emit(state.copyWith(
          status: SearchStatus.idle,
          predictions: const [],
          clearError: true));
      return;
    }
    _debounceTimer = Timer(_debounce, () => _performSearch(query));
  }

  Future<void> _performSearch(String query) async {
    final token = ++_requestToken;
    emit(state.copyWith(status: SearchStatus.loading, clearError: true));

    final result = await _repository.searchPlaces(query);

    // Discard if a newer query has already started
    if (token != _requestToken || isClosed) return;

    switch (result) {
      case MapSuccess(:final data):
        emit(state.copyWith(
          status: data.isEmpty ? SearchStatus.empty : SearchStatus.results,
          predictions: data,
        ));
      case MapFailure(:final message):
        emit(state.copyWith(
            status: SearchStatus.failure, errorMessage: message));
    }
  }

  // ── Selection ─────────────────────────────────────────────────────────────

  /// Fetches full place details for the selected prediction.
  /// Returns [null] on failure so the view can show a snackbar instead of crashing.
  Future<PlaceDetailsModel?> selectPrediction(String placeId) async {
    final result = await _repository.getPlaceDetails(placeId);
    return switch (result) {
      MapSuccess(:final data) => data,
      MapFailure() => null,
    };
  }

  // ── Overlay control ───────────────────────────────────────────────────────

  void openOverlay() =>
      emit(state.copyWith(isOverlayVisible: true));

  void closeOverlay() {
    _debounceTimer?.cancel();
    _requestToken++; // invalidate any in-flight request
    emit(state.copyWith(
      isOverlayVisible: false,
      status: SearchStatus.idle,
      predictions: const [],
      clearError: true,
    ));
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    return super.close();
  }
}
