import 'dart:ui' as ui;
import 'package:custom_info_window/custom_info_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class CustomMarkersScreen extends StatefulWidget {
  const CustomMarkersScreen({super.key});

  @override
  State<CustomMarkersScreen> createState() => _CustomMarkersScreenState();
}

class _CustomMarkersScreenState extends State<CustomMarkersScreen> {
  late GoogleMapController _controller;
  final Set<Marker> _markers = {};
  // Initialize the controller that bridges the Map and the Flutter UI
  final CustomInfoWindowController _customInfoWindowController =
      CustomInfoWindowController();

  // Starting coordinates
  static const LatLng _center = LatLng(28.6139, 77.2090); // New Delhi

  // Dynamic state for interactive draggable pin
  LatLng _draggablePosition = const LatLng(28.6494, 77.2101);
  String _draggedAddressStatus = 'Hold and drag the car to relocate';
  static const LatLng _restaurantLocation = LatLng(28.6139, 77.2090);

  @override
  void initState() {
    super.initState();
    _initializeMarkers();
  }

  @override
  void dispose() {
    // 3. Always dispose the controller to prevent memory leaks
    _customInfoWindowController.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Converts a standard asset image into a BitmapDescriptor for the map
  Future<BitmapDescriptor> _getCustomMarker(String path, int width) async {
    final ByteData data = await rootBundle.load(path);
    final ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: width,
    );
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final ByteData? byteData = await frameInfo.image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  Future<void> _initializeMarkers() async {
    // Load the manual asset image we added to the pubspec.yaml
    final BitmapDescriptor customIcon = await _getCustomMarker(
      'assets/icons/delivery_bike.png',
      40, // Adjust this width to scale your icon perfectly
    );

    final BitmapDescriptor carIcon = await _getCustomMarker(
      'assets/icons/taxi.png',
      40,
    );

    setState(() {
      _markers.clear();
      // 1. Standard Default Marker with InfoWindow
      _markers.add(
        Marker(
          markerId: const MarkerId('standard_pin'),
          position: const LatLng(28.6129, 77.2294), // India Gate
          zIndexInt: 1,
          infoWindow: const InfoWindow(
            title: 'India Gate',
            snippet: 'Tap to see this popup',
          ),
        ),
      );

      // 2. Color-Tinted Marker (Hue Shift)
      _markers.add(
        Marker(
          markerId: const MarkerId('tinted_pin'),
          position: const LatLng(28.6565, 77.2429), // Red Fort
          // Shifts the default red pin to a custom hue (e.g., Cyan, Green, Azure)
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
          infoWindow: InfoWindow(
            title: 'Red Fort',
            snippet: 'Custom camera animation on tap',
            onTap: () {
              // Programmatically zoom in when the user taps this specific marker
              _controller.animateCamera(
                CameraUpdate.newLatLngZoom(const LatLng(28.6250, 77.2100), 16),
              );
            },
          ),
        ),
      );

      // 3. Custom Image Marker (e.g., Delivery Partner)
      _markers.add(
        Marker(
          markerId: const MarkerId('custom_image_pin'),
          position: const LatLng(28.5536, 77.2591), // Lotus Temple
          icon: customIcon,
          // Centers the image exactly on the coordinate. (0.5, 0.5) is the middle.
          anchor: const Offset(0.5, 0.5),
          flat: true, // Lies flat on the map surface
          rotation: 45.0, // Oriented 45° North-East along heading
          zIndexInt: 3, // Renders on top of other markers
          infoWindow: const InfoWindow(
            title: 'Delivery Partner',
            snippet: 'Custom asset marker',
          ),
        ),
      );

      // 4. User-Draggable Pin for Precision Coordinate Selection
      _markers.add(
        Marker(
          markerId: const MarkerId('draggable_pin'),
          position: _draggablePosition,
          draggable: true,
          icon: carIcon,
          zIndexInt: 2,
          infoWindow: const InfoWindow(
            title: 'Drop-off Pinpoint',
            snippet: 'Long press and drag to relocate',
          ),
          onDragEnd: (LatLng newCoord) {
            setState(() {
              _draggablePosition = newCoord;
              _draggedAddressStatus =
                  'Dropped at: ${newCoord.latitude.toStringAsFixed(4)}, ${newCoord.longitude.toStringAsFixed(4)}';
            });
          },
        ),
      );

      // 5. Inactive / Ghost Marker (Altered Alpha)
      _markers.add(
        Marker(
          markerId: const MarkerId('ghost_marker'),
          position: const LatLng(28.5244, 77.1852), // Qutb Minar
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
          alpha: 0.45, // Translucent opacity
          infoWindow: const InfoWindow(
            title: 'Inactive Driver',
            snippet: 'Alpha reduced to 0.45',
          ),
        ),
      );

      // Custom Info Window Marker
      _markers.add(
        Marker(
          markerId: const MarkerId('gourmet_kitchen'),
          position: _restaurantLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          // 2. Suppress the default native info window and trigger ours
          onTap: () {
            _customInfoWindowController.addInfoWindow!(
              _buildCustomRestaurantCard(),
              _restaurantLocation,
            );
          },
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('02: Custom Markers & Callouts')),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _center,
              zoom: 13,
            ),
            markers: _markers, // Inject the set of markers here
            onMapCreated: (controller) {
              _controller = controller;
              _customInfoWindowController.googleMapController = controller;
            },
            compassEnabled: true, // Enable the compass.
            trafficEnabled: true, // Enable traffic overlay.
            tiltGesturesEnabled: true, // Enable tilt gestures.
            scrollGesturesEnabled: true, // Enable scroll gestures.
            zoomGesturesEnabled: true, // Enable zoom gestures.
            zoomControlsEnabled:
                false, // Disable default zoom controls (consider custom controls).
            onCameraMove: (position) {
              // Rapidly updates the widget's X/Y pixels as the map pans
              _customInfoWindowController.onCameraMove!();
            },
            onTap: (position) {
              // Dismiss the custom window if the user taps empty map space
              _customInfoWindowController.hideInfoWindow!();
            },
          ),
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.touch_app, color: Colors.deepPurple),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _draggedAddressStatus,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 6. The actual overlay manager that renders your custom widget
          CustomInfoWindow(
            controller: _customInfoWindowController,
            height: 180,
            width: 220,
            // Offset shifts the box up so it doesn't cover the physical pin
            offset: 50,
          ),
        ],
      ),
    );
  }

  /// Builds a rich Flutter widget to float above the map pin
  Widget _buildCustomRestaurantCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Image.network(
                'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=300&q=80',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const ContainerColor(color: Colors.grey),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gourmet Kitchen',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Row(
                  children: const [
                    Icon(Icons.star, color: Colors.orange, size: 14),
                    Text(' 4.8 (120 reviews)', style: TextStyle(fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  height: 30,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () {
                      debugPrint('Navigate to order screen');
                    },
                    child: const Text(
                      'View Menu',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Helper for image fallback
class ContainerColor extends StatelessWidget {
  final Color color;
  const ContainerColor({super.key, required this.color});
  @override
  Widget build(BuildContext context) => Container(color: color);
}
