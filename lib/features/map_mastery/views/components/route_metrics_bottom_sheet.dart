import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../logic/directions/directions_cubit.dart';
import '../../logic/directions/directions_state.dart';

class RouteMetricsBottomSheet extends StatelessWidget {
  const RouteMetricsBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DirectionsCubit, DirectionsState>(
      builder: (context, state) {
        final route = state.activeRoute;
        if (state.status != DirectionsStatus.ready || route == null) {
          return const SizedBox.shrink();
        }

        IconData modeIcon;
        switch (route.mode.name) {
          case 'driving': modeIcon = Icons.directions_car; break;
          case 'transit': modeIcon = Icons.directions_transit; break;
          case 'walking': modeIcon = Icons.directions_walk; break;
          case 'twoWheeler': modeIcon = Icons.two_wheeler; break;
          default: modeIcon = Icons.directions;
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(modeIcon, color: Theme.of(context).primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          route.durationInTrafficText ?? route.durationText,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        context.read<DirectionsCubit>().clear();
                      },
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      route.distanceText,
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    const Text('•', style: TextStyle(color: Colors.grey)),
                    const SizedBox(width: 8),
                    Text(
                      'via ${route.mode.name.toUpperCase()}',
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),

              ],
            ),
          ),
        );
      },
    );
  }
}
