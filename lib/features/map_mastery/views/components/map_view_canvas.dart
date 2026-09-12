import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../logic/map_core/map_core_cubit.dart';
import '../../logic/map_core/map_core_state.dart';
import '../../data/models/place_details_model.dart';
import '../../data/repositories/map_repository.dart';
import '../../utils/map_result.dart';

/// The core Google Map rendering component.
/// This widget listens to [MapCoreCubit] to draw markers and animate the camera,
/// ensuring the UI remains purely reactive with zero `setState` usage.
class MapViewCanvas extends StatefulWidget {
  const MapViewCanvas({super.key});

  @override
  State<MapViewCanvas> createState() => _MapViewCanvasState();
}

class _MapViewCanvasState extends State<MapViewCanvas> {
  // Controller to programmatically move the map camera.
  GoogleMapController? _mapController;

  // Fallback position if the user's location is unavailable.
  static const CameraPosition _fallbackPosition = CameraPosition(
    target: LatLng(28.6139, 77.2090),
    zoom: 10.0,
  );

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  /// Handles long-press gestures on the map to drop a dynamic marker.
  /// It reverses the coordinate into a Google Place ID, then fetches rich POI data.
  Future<void> _onMapLongPress(LatLng point) async {
    final mapRepo = context.read<MapRepository>();
    
    // Step 1: Reverse geocode the coordinate to get the nearest valid Google Place ID.
    final result = await mapRepo.reverseGeocodePlaceId(point);
    
    if (result is MapSuccess<String>) {
      final placeId = result.data;
      
      // Step 2: Use the Place ID to fetch rich details (Name, Rating, Phone, Address).
      final detailsResult = await mapRepo.getPlaceDetails(placeId);
      
      if (detailsResult is MapSuccess<PlaceDetailsModel>) {
        if (!mounted) return;
        // Step 3: Tell the Cubit to set this as the focal place, updating the map marker and bottom sheet.
        context.read<MapCoreCubit>().onFocalPlaceSelected(detailsResult.data);
        return;
      }
    }
    
    // Fallback: If no Place ID exists for this raw coordinate (e.g., middle of the ocean),
    // drop a custom marker with raw lat/lng text.
    final fallbackDetails = PlaceDetailsModel(
      id: 'custom_${point.latitude}_${point.longitude}',
      name: 'Dropped Pin',
      coordinate: point,
      address: 'Lat: ${point.latitude.toStringAsFixed(4)}, Lng: ${point.longitude.toStringAsFixed(4)}',
    );
    
    if (!mounted) return;
    context.read<MapCoreCubit>().onFocalPlaceSelected(fallbackDetails);
  }

  @override
  Widget build(BuildContext context) {
    // Read the initial position once on build. Future camera moves use `animateCamera`.
    final initialPos = context.read<MapCoreCubit>().state.currentPosition;
    final startPosition = initialPos != null
        ? CameraPosition(target: initialPos, zoom: 15.0)
        : _fallbackPosition;

    return BlocConsumer<MapCoreCubit, MapCoreState>(
      // Listen ONLY for new camera movement commands.
      listenWhen: (previous, current) =>
          previous.cameraCommand != current.cameraCommand &&
          current.cameraCommand != null,
      listener: (context, state) {
        final command = state.cameraCommand;
        if (command != null && _mapController != null) {
          // Execute the camera animation.
          _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: command.target,
                zoom: command.zoom,
              ),
            ),
          );
          // Consume the command so it doesn't fire again on unrelated rebuilds.
          context.read<MapCoreCubit>().consumeCameraCommand();
        }
      },
      // Rebuild the GoogleMap widget ONLY when the focal place (marker) changes.
      buildWhen: (previous, current) => previous.focalPlace != current.focalPlace,
      builder: (context, state) {
        final Set<Marker> markers = {};
        
        // If a focal place is selected, render its marker on the map.
        if (state.focalPlace != null) {
          markers.add(
            Marker(
              markerId: const MarkerId('focal_place'),
              position: state.focalPlace!.coordinate,
              infoWindow: InfoWindow(title: state.focalPlace!.name),
            ),
          );
        }

        return GoogleMap(
          // Padding pushes the map's native UI (My Location button, Google Logo)
          // below our custom Search Bar so they don't overlap.
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 70,
            bottom: 16,
          ),
          initialCameraPosition: startPosition,
          mapType: MapType.normal,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: false,
          markers: markers,
          // Tapping anywhere on the map clears the current selection and dismisses the bottom sheet.
          onTap: (_) {
            context.read<MapCoreCubit>().clearFocalPlace();
          },
          onLongPress: _onMapLongPress,
          onMapCreated: (controller) {
            _mapController = controller;
          },
        );
      },
    );
  }
}
