import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../logic/search_places/search_places_cubit.dart';
import '../../logic/search_places/search_places_state.dart';

/// A floating search bar pinned to the top of the screen.
/// Routes typing input into the [SearchPlacesCubit] to fetch autocomplete predictions.
class MapSearchBarHeader extends StatefulWidget {
  const MapSearchBarHeader({super.key});

  @override
  State<MapSearchBarHeader> createState() => _MapSearchBarHeaderState();
}

class _MapSearchBarHeaderState extends State<MapSearchBarHeader> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Listen for focus changes to automatically open the search overlay.
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    // When the user taps the text field, instruct the Cubit to show the full-screen overlay.
    if (_focusNode.hasFocus) {
      context.read<SearchPlacesCubit>().openOverlay();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SearchPlacesCubit, SearchPlacesState>(
      // Monitor the overlay visibility state from the Cubit.
      listenWhen: (previous, current) =>
          previous.isOverlayVisible != current.isOverlayVisible,
      listener: (context, state) {
        // If the overlay is closed programmatically (e.g., selection made), drop keyboard focus.
        if (!state.isOverlayVisible) {
          _focusNode.unfocus();
        }
      },
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(32),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    final cubit = context.read<SearchPlacesCubit>();
                    // If the overlay is open, back button closes it. Otherwise, it pops the screen.
                    if (cubit.state.isOverlayVisible) {
                      cubit.closeOverlay();
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                  tooltip: 'Back',
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    decoration: const InputDecoration(
                      hintText: 'Search here',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                    // onChanged: (value) {
                    //   // Forward query changes to the Cubit (which handles the 500ms debounce).
                    //   context.read<SearchPlacesCubit>().onQueryChanged(value);
                    // },
                    onEditingComplete: () {
                      context.read<SearchPlacesCubit>().onQueryChanged(
                        _controller.text,
                      );
                    },
                  ),
                ),
                // Rebuild only the trailing icon when text changes (show 'clear' X if text exists).
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (context, value, child) {
                    if (value.text.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.only(right: 16.0),
                        child: Icon(Icons.search, color: Colors.grey),
                      );
                    }
                    return IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        // Clear the text field and reset search results.
                        _controller.clear();
                        context.read<SearchPlacesCubit>().onQueryChanged('');
                      },
                      tooltip: 'Clear',
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
