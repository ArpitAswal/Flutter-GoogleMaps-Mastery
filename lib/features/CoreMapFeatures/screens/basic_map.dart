import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class BasicMapScreen extends StatefulWidget {
  const BasicMapScreen({super.key});

  @override
  State<BasicMapScreen> createState() => _BasicMapScreenState();
}

class _BasicMapScreenState extends State<BasicMapScreen> {
  GoogleMapController? _mapController;
  MapType _currentMapType = MapType.normal;

  bool _hasLocationPermission = false;
  // This state locks the UI until the permission prompt is resolved
  bool _isCheckingPermission = true;

  static const CameraPosition _fallbackPosition = CameraPosition(
    target: LatLng(28.6139, 77.2090),
    zoom: 10.0,
  );

  static const LatLng _tokyoLocation = LatLng(35.6895, 139.6917);

  @override
  void initState() {
    super.initState();
    _resolvePermissionsAndLocation();
  }

  Future<void> _resolvePermissionsAndLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    // Step 1: Permission flow is finished. Update state to build the Map.
    setState(() {
      _hasLocationPermission = (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always);
      _isCheckingPermission = false;
    });

    // Step 2: If granted, fetch the actual GPS coordinates in the background.
    if (_hasLocationPermission) {
      try {
        Position position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high)
        );

        // Step 3: Animate the camera from the fallback position to the real location
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 16.0,
              tilt: 0.0,
              bearing: 0.0,
            ),
          ),
        );
      } catch (e) {
        debugPrint('Failed to get location: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('01: Basic Map & Camera'),
        actions: [
          PopupMenuButton<MapType>(
            onSelected: (type) => setState(() => _currentMapType = type),
            itemBuilder: (_) => [
              const PopupMenuItem(value: MapType.normal, child: Text('Normal')),
              const PopupMenuItem(value: MapType.satellite, child: Text('Satellite')),
              const PopupMenuItem(value: MapType.terrain, child: Text('Terrain')),
              const PopupMenuItem(value: MapType.hybrid, child: Text('Hybrid')),
            ],
            icon: const Icon(Icons.layers),
          ),
        ],
      ),
      // If still waiting on the permission prompt, show a loading spinner
      body: _isCheckingPermission
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _fallbackPosition,
            mapType: _currentMapType,
            myLocationEnabled: _hasLocationPermission,
            myLocationButtonEnabled: _hasLocationPermission,
            zoomControlsEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
            },
          ),
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.flight_takeoff),
                  label: const Text('Fly to Tokyo'),
                  onPressed: () {
                    _mapController?.animateCamera(
                      CameraUpdate.newCameraPosition(
                        const CameraPosition(
                          target: _tokyoLocation,
                          zoom: 14.0,
                          tilt: 0.0,
                          bearing: 0.0,
                        ),
                      ),
                    );
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.my_location),
                  label: const Text('My Location'),
                  onPressed: () {
                    // Allow the custom button to trigger the camera move again
                    if (_hasLocationPermission) {
                      _resolvePermissionsAndLocation();
                    } else{
                      _mapController?.animateCamera(
                        CameraUpdate.newCameraPosition(
                          _fallbackPosition)
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}