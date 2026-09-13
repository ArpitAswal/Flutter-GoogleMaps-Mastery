import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../logic/map_core/map_core_cubit.dart';
import '../../data/models/place_details_model.dart';
import '../../logic/map_core/map_core_state.dart';
import '../../logic/directions/directions_cubit.dart';
import '../../logic/directions/directions_state.dart';
import '../../logic/search_places/search_places_cubit.dart';
import 'directions_selection_modal.dart';

class MapFloatingActionButtons extends StatelessWidget {
  const MapFloatingActionButtons({super.key});

  void _openModal(BuildContext context, {bool fetchRoutesOnInit = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: context.read<DirectionsCubit>()),
          BlocProvider.value(value: context.read<SearchPlacesCubit>()),
        ],
        child: DirectionsSelectionModal(fetchRoutesOnInit: fetchRoutesOnInit),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DirectionsCubit, DirectionsState>(
      builder: (context, dirState) {
        return BlocBuilder<MapCoreCubit, MapCoreState>(
          builder: (context, state) {
            final hasRoute =
                dirState.status == DirectionsStatus.ready &&
                dirState.activeRoute != null;
            final hasOriginAndDest =
                dirState.origin != null && dirState.destination != null;

            return Positioned(
              bottom: hasRoute ? 120 : 16,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FloatingActionButton(
                    heroTag: 'traffic_fab',
                    onPressed: () =>
                        context.read<MapCoreCubit>().toggleTraffic(),
                    backgroundColor: state.trafficEnabled
                        ? Theme.of(context).primaryColor
                        : Colors.white,
                    foregroundColor: state.trafficEnabled
                        ? Colors.white
                        : Colors.grey[700],
                    child: const Icon(Icons.traffic),
                  ),
                  const SizedBox(height: 16),
                  if (hasOriginAndDest) ...[
                    FloatingActionButton(
                      heroTag: 'edit_route_fab',
                      onPressed: () => _openModal(context, fetchRoutesOnInit: false),
                      child: const Icon(Icons.directions),
                    ),
                    const SizedBox(height: 16),
                  ] else if (state.focalPlace != null) ...[
                    FloatingActionButton.extended(
                      heroTag: 'directions_fab',
                      onPressed: () {
                        final dirCubit = context.read<DirectionsCubit>();
                        dirCubit.setDestination(state.focalPlace!);
                        if (state.currentPosition != null) {
                          dirCubit.setOrigin(
                            PlaceDetailsModel(
                              id: 'current_location',
                              name: 'Your location',
                              coordinate: state.currentPosition!,
                              address: 'Your location',
                            ),
                          );
                        }
                        _openModal(context, fetchRoutesOnInit: true);
                      },
                      icon: const Icon(Icons.directions),
                      label: const Text('Directions'),
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (hasRoute)
                    FloatingActionButton.extended(
                      heroTag: 'start_navigation_fab',
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Phase 5: Live tracking coming soon'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.navigation),
                      label: Text(
                        'Start Navigation',
                      ),
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
