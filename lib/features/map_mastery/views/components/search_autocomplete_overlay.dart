import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../logic/map_core/map_core_cubit.dart';
import '../../logic/search_places/search_places_cubit.dart';
import '../../logic/search_places/search_places_state.dart';
import '../../data/models/place_prediction_model.dart';

/// A full-screen overlay that displays search results dynamically.
/// It floats above the map but below the search bar.
class SearchAutocompleteOverlay extends StatelessWidget {
  const SearchAutocompleteOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SearchPlacesCubit, SearchPlacesState>(
      // Only listen for error messages to show a snackbar.
      listenWhen: (previous, current) =>
          previous.errorMessage != current.errorMessage &&
          current.errorMessage != null,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(state.errorMessage!)));
      },
      // Only rebuild the overlay when visibility, status, or prediction lists change.
      buildWhen: (previous, current) =>
          previous.isOverlayVisible != current.isOverlayVisible ||
          previous.status != current.status ||
          previous.predictions != current.predictions,
      builder: (context, state) {
        // If not visible, render nothing.
        if (!state.isOverlayVisible) return const SizedBox.shrink();

        return Positioned(
          top: MediaQuery.of(context).padding.top + 70, // Start just below the search bar
          left: 16,
          right: 16,
          bottom: 16,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            // Offload the internal view state (loading vs results) to a helper method.
            child: _buildContent(context, state),
          ),
        );
      },
    );
  }

  /// Evaluates the current [SearchStatus] and returns the appropriate UI widget.
  Widget _buildContent(BuildContext context, SearchPlacesState state) {
    switch (state.status) {
      case SearchStatus.idle:
        return const Center(
          child: Text(
            'Type an address to search',
            style: TextStyle(color: Colors.grey),
          ),
        );
      case SearchStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case SearchStatus.empty:
        return const Center(child: Text('No results found.'));
      case SearchStatus.failure:
        return const Center(child: Text('Search failed.'));
      case SearchStatus.results:
        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: state.predictions.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final prediction = state.predictions[index];
            return ListTile(
              leading: const Icon(Icons.place, color: Colors.grey),
              title: Text(prediction.primaryText),
              subtitle: Text(
                prediction.secondaryText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _onPredictionTapped(context, prediction),
            );
          },
        );
    }
  }

  /// Handles the user selecting a search prediction.
  Future<void> _onPredictionTapped(
      BuildContext context, PlacePredictionModel prediction) async {
    final searchCubit = context.read<SearchPlacesCubit>();
    final mapCoreCubit = context.read<MapCoreCubit>();
    
    // Fetch full Place Details (Lat/Lng, Rating, etc.) using the Place ID.
    final details = await searchCubit.selectPrediction(prediction.placeId);
    if (details != null) {
      // Instruct the map core to drop a marker and focus on this new location.
      mapCoreCubit.onFocalPlaceSelected(details);
    }
    // Close the search overlay after a selection is made.
    searchCubit.closeOverlay();
  }
}
