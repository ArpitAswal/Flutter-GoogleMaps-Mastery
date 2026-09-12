import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_constants.dart';
import '../data/data_sources/google_maps_remote_data_source.dart';
import '../data/data_sources/trip_firestore_data_source.dart';
import '../data/repositories/map_repository.dart';
import '../data/repositories/tracking_repository.dart';
import '../logic/directions/directions_cubit.dart';
import '../logic/live_tracking/live_tracking_cubit.dart';
import '../logic/map_core/map_core_cubit.dart';
import '../logic/map_core/map_core_state.dart';
import '../logic/search_places/search_places_cubit.dart';
import 'components/map_view_canvas.dart';

class MapMasteryScreen extends StatelessWidget {
  const MapMasteryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<MapRepository>(
          create: (_) => MapRepository(
            dataSource: GoogleMapsRemoteDataSource(
              client: http.Client(),
              apiKey: AppConstants.googleMapsApiKey,
            ),
          ),
        ),
        RepositoryProvider<TrackingRepository>(
          create: (_) => TrackingRepository(
            dataSource: TripFirestoreDataSource(
              firestore: FirebaseFirestore.instance,
            ),
          ),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => MapCoreCubit()..initialize()),
          BlocProvider(
            create: (context) => SearchPlacesCubit(
              repository: context.read<MapRepository>(),
            ),
          ),
          BlocProvider(
            create: (context) => DirectionsCubit(
              repository: context.read<MapRepository>(),
            ),
          ),
          BlocProvider(
            create: (context) => LiveTrackingCubit(
              repository: context.read<TrackingRepository>(),
            ),
          ),
        ],
        child: const _MapMasteryBody(),
      ),
    );
  }
}

class _MapMasteryBody extends StatefulWidget {
  const _MapMasteryBody();

  @override
  State<_MapMasteryBody> createState() => _MapMasteryBodyState();
}

class _MapMasteryBodyState extends State<_MapMasteryBody> with WidgetsBindingObserver {
  bool _wentToSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _wentToSettings) {
      _wentToSettings = false;
      context.read<MapCoreCubit>().retryInitialization();
    }
  }

  void _openSettings(Future<void> Function() action) {
    _wentToSettings = true;
    action();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MapCoreCubit, MapCoreState>(
      builder: (context, state) {
        if (state.status == MapCoreStatus.ready) {
          return Scaffold(
            body: Stack(
              children: [
                const MapViewCanvas(),
                Positioned(
                  top: 16,
                  left: 16,
                  child: SafeArea(
                    child: CircleAvatar(
                      backgroundColor: Colors.white,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.black),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Map Mastery')),
          body: switch (state.status) {
            MapCoreStatus.initial ||
            MapCoreStatus.checkingPermission ||
            MapCoreStatus.loading =>
              const Center(child: CircularProgressIndicator()),
            MapCoreStatus.serviceDisabled => _RecoveryMessage(
                icon: Icons.location_disabled,
                message:
                    'Location services are disabled.\nPlease enable them in Settings.',
                action: 'Open Settings',
                onAction: () => _openSettings(
                  () => context.read<MapCoreCubit>().openLocationSettings(),
                ),
              ),
            MapCoreStatus.permissionDenied => _RecoveryMessage(
                icon: Icons.location_off,
                message:
                    'Location permission was denied.\nTap below to grant access.',
                action: 'Retry',
                onAction: () =>
                    context.read<MapCoreCubit>().retryInitialization(),
              ),
            MapCoreStatus.permissionPermanentlyDenied => _RecoveryMessage(
                icon: Icons.lock,
                message:
                    'Location permission is permanently denied.\nOpen App Settings to grant access.',
                action: 'Open App Settings',
                onAction: () => _openSettings(
                  () => context.read<MapCoreCubit>().openAppSettings(),
                ),
              ),
            MapCoreStatus.failure => _RecoveryMessage(
                icon: Icons.error_outline,
                message: state.errorMessage ?? 'An unknown error occurred.',
                action: 'Retry',
                onAction: () =>
                    context.read<MapCoreCubit>().retryInitialization(),
              ),
            MapCoreStatus.ready => const SizedBox.shrink(), // Handled above
          },
        );
      },
    );
  }
}

class _RecoveryMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final String action;
  final VoidCallback onAction;

  const _RecoveryMessage({
    required this.icon,
    required this.message,
    required this.action,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: onAction, child: Text(action)),
          ],
        ),
      ),
    );
  }
}
