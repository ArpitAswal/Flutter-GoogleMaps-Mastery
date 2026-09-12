import 'package:flutter/foundation.dart';
import '../../data/models/place_prediction_model.dart';

enum SearchStatus { idle, loading, results, empty, failure }

/// Immutable view state for [SearchPlacesCubit].
@immutable
class SearchPlacesState {
  final SearchStatus status;
  final List<PlacePredictionModel> predictions;
  final bool isOverlayVisible;
  final String? errorMessage;

  const SearchPlacesState({
    this.status = SearchStatus.idle,
    this.predictions = const [],
    this.isOverlayVisible = false,
    this.errorMessage,
  });

  SearchPlacesState copyWith({
    SearchStatus? status,
    List<PlacePredictionModel>? predictions,
    bool? isOverlayVisible,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SearchPlacesState(
      status: status ?? this.status,
      predictions: predictions ?? this.predictions,
      isOverlayVisible: isOverlayVisible ?? this.isOverlayVisible,
      errorMessage:
          clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchPlacesState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          predictions == other.predictions &&
          isOverlayVisible == other.isOverlayVisible &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode =>
      Object.hash(status, predictions, isOverlayVisible, errorMessage);
}
