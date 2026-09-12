import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../logic/map_core/map_core_cubit.dart';
import '../../logic/map_core/map_core_state.dart';

class MapViewCanvas extends StatefulWidget {
  const MapViewCanvas({super.key});

  @override
  State<MapViewCanvas> createState() => _MapViewCanvasState();
}

class _MapViewCanvasState extends State<MapViewCanvas> {
  GoogleMapController? _mapController;

  static const CameraPosition _fallbackPosition = CameraPosition(
    target: LatLng(28.6139, 77.2090), // Default fallback
    zoom: 10.0,
  );

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initialPos = context.read<MapCoreCubit>().state.currentPosition;
    final startPosition = initialPos != null
        ? CameraPosition(target: initialPos, zoom: 15.0)
        : _fallbackPosition;

    return BlocListener<MapCoreCubit, MapCoreState>(
      listenWhen: (previous, current) =>
          previous.cameraCommand != current.cameraCommand &&
          current.cameraCommand != null,
      listener: (context, state) {
        final command = state.cameraCommand;
        if (command != null && _mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: command.target,
                zoom: command.zoom,
              ),
            ),
          );
          context.read<MapCoreCubit>().consumeCameraCommand();
        }
      },
      child: GoogleMap(
        // Map padding ensures the map controls (like the My Location button and Google logo)
        // are pushed down below the status bar/notch while the map canvas remains full screen.
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          bottom: 16,
        ),
        initialCameraPosition: startPosition,
        mapType: MapType.normal,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        zoomControlsEnabled: false,
        onMapCreated: (controller) {
          _mapController = controller;
        },
      ),
    );
  }
}
