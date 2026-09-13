import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../data/models/place_details_model.dart';
import 'map_core_state.dart';

/// Owns the permission and location resolution lifecycle.
///
/// Views must never call Geolocator or platform APIs directly — instead they
/// listen for state changes via [BlocListener] and call cubit methods such as
/// [openLocationSettings] or [openAppSettings] in response.
class MapCoreCubit extends Cubit<MapCoreState> {
  MapCoreCubit() : super(const MapCoreState());

  // ── Initialisation ────────────────────────────────────────────────────────

  Future<void> initialize() async {
    emit(state.copyWith(status: MapCoreStatus.checkingPermission));

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      emit(state.copyWith(status: MapCoreStatus.serviceDisabled));
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    switch (permission) {
      case LocationPermission.deniedForever:
        emit(state.copyWith(
            status: MapCoreStatus.permissionPermanentlyDenied));
        return;
      case LocationPermission.denied:
        emit(state.copyWith(status: MapCoreStatus.permissionDenied));
        return;
      default:
        break;
    }

    await _fetchCurrentLocation();
  }

  Future<void> _fetchCurrentLocation() async {
    emit(state.copyWith(status: MapCoreStatus.loading));
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      emit(state.copyWith(
        status: MapCoreStatus.ready,
        currentPosition: LatLng(position.latitude, position.longitude),
        clearError: true,
      ));
    } catch (_) {
      emit(state.copyWith(
        status: MapCoreStatus.failure,
        errorMessage: 'Could not determine your location. Please try again.',
      ));
    }
  }

  // ── Focal place & camera ──────────────────────────────────────────────────

  void onFocalPlaceSelected(PlaceDetailsModel place) {
    emit(state.copyWith(
      focalPlace: place,
      cameraCommand: CameraCommand(target: place.coordinate),
    ));
  }

  void clearFocalPlace() {
    emit(state.copyWith(clearFocalPlace: true));
  }

  /// Called by the view's [BlocListener] after it executes the camera animation.
  void consumeCameraCommand() {
    emit(state.copyWith(clearCameraCommand: true));
  }

  // ── Permission recovery (executed by view listener) ───────────────────────

  Future<void> openLocationSettings() =>
      Geolocator.openLocationSettings();

  Future<void> openAppSettings() => Geolocator.openAppSettings();

  /// Re-runs the full initialisation flow — used after returning from settings.
  Future<void> retryInitialization() => initialize();

  void toggleTraffic() {
    emit(state.copyWith(trafficEnabled: !state.trafficEnabled));
  }
}
