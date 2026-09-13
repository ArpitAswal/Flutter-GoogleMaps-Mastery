import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../data/models/place_details_model.dart';

enum MapCoreStatus {
  initial,
  checkingPermission,
  serviceDisabled,
  permissionDenied,
  permissionPermanentlyDenied,
  loading,
  ready,
  failure,
}

/// One-shot camera animation command emitted by [MapCoreCubit] and consumed by
/// a [BlocListener] in the view. Must be cleared after the animation fires so
/// re-builds do not re-trigger the same animation.
@immutable
class CameraCommand {
  final LatLng target;
  final double zoom;
  const CameraCommand({required this.target, this.zoom = 15.0});
}

/// Immutable view state for [MapCoreCubit].
///
/// - [currentPosition]: valid only when [status] is [MapCoreStatus.ready].
/// - [focalPlace]: the currently highlighted POI (null = none selected).
/// - [cameraCommand]: a pending one-shot camera animation; [null] after consumed.
/// - [errorMessage]: set only for [MapCoreStatus.failure].
@immutable
class MapCoreState {
  final MapCoreStatus status;
  final LatLng? currentPosition;
  final PlaceDetailsModel? focalPlace;
  final CameraCommand? cameraCommand;
  final String? errorMessage;
  final bool trafficEnabled;

  const MapCoreState({
    this.status = MapCoreStatus.initial,
    this.currentPosition,
    this.focalPlace,
    this.cameraCommand,
    this.errorMessage,
    this.trafficEnabled = false,
  });

  MapCoreState copyWith({
    MapCoreStatus? status,
    LatLng? currentPosition,
    PlaceDetailsModel? focalPlace,
    CameraCommand? cameraCommand,
    String? errorMessage,
    bool? trafficEnabled,
    bool clearFocalPlace = false,
    bool clearCameraCommand = false,
    bool clearError = false,
  }) {
    return MapCoreState(
      status: status ?? this.status,
      currentPosition: currentPosition ?? this.currentPosition,
      focalPlace: clearFocalPlace ? null : (focalPlace ?? this.focalPlace),
      cameraCommand:
          clearCameraCommand ? null : (cameraCommand ?? this.cameraCommand),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      trafficEnabled: trafficEnabled ?? this.trafficEnabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapCoreState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          currentPosition == other.currentPosition &&
          focalPlace == other.focalPlace &&
          cameraCommand == other.cameraCommand &&
          errorMessage == other.errorMessage &&
          trafficEnabled == other.trafficEnabled;

  @override
  int get hashCode => Object.hash(
        status, currentPosition, focalPlace, cameraCommand, errorMessage, trafficEnabled);
}
