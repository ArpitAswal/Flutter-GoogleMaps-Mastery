import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/service/google_map_service.dart';

class RoutePolylinesScreen extends StatefulWidget {
  const RoutePolylinesScreen({super.key});

  @override
  State<RoutePolylinesScreen> createState() => _RoutePolylinesScreenState();
}

class _RoutePolylinesScreenState extends State<RoutePolylinesScreen> {
  final GoogleMapsService _mapsService = GoogleMapsService();
  late GoogleMapController? _mapController;
  late String? _activeSearchField; // 'origin' or 'destination'

  // Origin and Destination Coordinates
  static LatLng _origin = LatLng(28.828, 77.569); // Modinagar
  static LatLng _destination = LatLng(28.6692, 77.4538); // Ghaziabad

  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destController = TextEditingController();
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  List<Map<String, String>> _predictions = [];
  String _distance = '';
  String _trafficDuration = '';
  String _normalDuration = '';
  bool _isLoadingRoute = false;
  String _travelMode = 'driving'; // default mode

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _setupMarkers(null, true);
    _setupMarkers(null, false);
    _calculateRouteWithTraffic();
  }

  @override
  void dispose() {
    _originController.dispose();
    _destController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query, String field) {
    _activeSearchField = field;
    if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();

    if (query.trim().isEmpty) {
      _isLoadingRoute = false;
      setState(() => _predictions = []);
      return;
    }

    try {
      setState(() {
        _isLoadingRoute = true;
      });
      // Wait 500ms after the user stops typing before making the network request
      _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
        final results = await _mapsService.searchPlaces(query);
        setState(() {
          _predictions = results;
        });
      });
    } catch (e) {
      debugPrint('Autocomplete error: $e');
    } finally {
      setState(() {
        _isLoadingRoute = false;
      });
    }
  }

  Future<void> _selectPlace(String placeId, String description) async {
    FocusScope.of(context).unfocus();
    final LatLng? coords = await _mapsService.getPlaceCoordinates(placeId);

    try {
      if (coords != null) {
        setState(() {
          if (_activeSearchField == 'origin') {
            _originController.text = description;
            _origin = coords;
            _setupMarkers(coords, true);
          } else {
            _destController.text = description;
            _destination = coords;
            _setupMarkers(coords, false);
          }
          _predictions.clear();
        });

        // Move camera to selected point immediately
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(coords, 14));

        // If both points are selected, calculate the route
        _calculateRouteWithTraffic();
      }
    } catch (e) {
      debugPrint('Place details error: $e');
    }
  }

  // ==========================================
  // ROUTE & TRAFFIC LOGIC
  // ==========================================

  Future<void> _calculateRouteWithTraffic() async {
    setState(() {
      _isLoadingRoute = true;
      _polylines.clear(); // Clear previous route
    });

    try {
      final routeData = await _mapsService.getDirections(
        origin: _origin,
        destination: _destination,
        mode: _travelMode,
      );
      if (routeData != null) {
        final List<LatLng> points = routeData['points'];

        setState(() {
          _distance = routeData['distance'];
          _trafficDuration = routeData['traffic_duration'];
          _normalDuration = routeData['normal_duration'];

          _polylines.add(
            Polyline(
              polylineId: const PolylineId('dynamic_route'),
              points: points,
              color: Colors.blueAccent,
              width: 5, // Thickness of the line on the map
              jointType: JointType.round, // Smooth corners
            ),
          );
        });

        _fitCameraToBounds(routeData['bounds']);
        // _fitPolylineBounds(points);
      }
    } catch (e) {
      debugPrint('Routing error: $e');
    } finally {
      setState(() => _isLoadingRoute = false);
    }
  }

  void _setupMarkers(LatLng? coords, bool isOrigin) {
    if (isOrigin) {
      _markers.removeWhere((m) => m.markerId.value == 'origin');
      _markers.add(
        Marker(
          markerId: const MarkerId('origin'),
          position: coords ?? _origin,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: const InfoWindow(title: 'Origin'),
        ),
      );
    } else {
      _markers.removeWhere((m) => m.markerId.value == 'destination');
      _markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: coords ?? _destination,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Destination'),
        ),
      );
    }
  }

  void _fitCameraToBounds(Map<String, dynamic> bounds) {
    if (_mapController == null) return;

    final northeast = bounds['northeast'];
    final southwest = bounds['southwest'];

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          northeast: LatLng(northeast['lat'], northeast['lng']),
          southwest: LatLng(southwest['lat'], southwest['lng']),
        ),
        80.0, // Added padding so UI elements don't overlap the route ends
      ),
    );
  }

  /// Calculates the geographical boundaries of the route and updates the camera viewport
  void _fitPolylineBounds(List<LatLng> points) {
    if (points.isEmpty || _mapController == null) return;
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    // Animate camera to contain the bounds with a 50-pixel padding
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80, // Padding
      ),
    );
  }

  Widget _buildSearchField(
    TextEditingController controller,
    String field,
    String hint,
    IconData icon,
  ) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      child: TextField(
        controller: controller,
        onEditingComplete: () =>
            _onSearchChanged(controller.text.trim(), field),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(
            icon,
            color: field == 'origin' ? Colors.green : Colors.red,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('04: Route Polylines & Metrics'),
        actions: [
          // Travel mode selector
          Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(30),
            color: Colors.white,
            child: ToggleButtons(
              borderRadius: BorderRadius.circular(30),
              isSelected: [
                _travelMode == 'driving',
                _travelMode == 'two_wheeler',
                _travelMode == 'walking',
              ],
              onPressed: (index) {
                setState(() {
                  if (index == 0) _travelMode = 'driving';
                  if (index == 1) _travelMode = 'two_wheeler';
                  if (index == 2) _travelMode = 'walking';
                });
                _calculateRouteWithTraffic();
              },
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.directions_car),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.two_wheeler),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.directions_walk),
                ),
              ],
            ),
          ),
        ],
      ),
      resizeToAvoidBottomInset: true,
      bottomNavigationBar:
          // Metrics Card Display
          (!_isLoadingRoute && _distance.isNotEmpty && _predictions.isEmpty)
          ? SizedBox(
              height: MediaQuery.of(context).size.height * 0.12,
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadiusGeometry.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                margin: EdgeInsets.zero,
                elevation: 6,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Distance',
                          style: TextStyle(color: Colors.grey),
                        ),
                        Text(
                          _distance,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    const VerticalDivider(),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'EST. Traffic TIME',
                          style: TextStyle(color: Colors.grey),
                        ),
                        Text(
                          _trafficDuration,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const VerticalDivider(),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'EST. Normal TIME',
                          style: TextStyle(color: Colors.grey),
                        ),
                        Text(
                          _normalDuration,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          : SizedBox.shrink(),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _origin, zoom: 16),
            markers: _markers,
            polylines: _polylines,
            zoomControlsEnabled: false,
            myLocationEnabled: true,
            trafficEnabled: true,
            onMapCreated: (c) => _mapController = c,
          ),
          if (_isLoadingRoute)
            const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),

          // Search Inputs
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                _buildSearchField(
                  _originController,
                  'origin',
                  'Search Starting Point...',
                  Icons.my_location,
                ),
                const SizedBox(height: 8),
                _buildSearchField(
                  _destController,
                  'destination',
                  'Search Destination...',
                  Icons.location_on,
                ),
                const SizedBox(height: 8),
                // Autocomplete Dropdown
                if (_predictions.isNotEmpty)
                  Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _predictions.length,
                      itemBuilder: (context, index) {
                        final item = _predictions[index];
                        return ListTile(
                          title: Text(
                            item['description']!,
                            style: const TextStyle(fontSize: 13),
                          ),
                          onTap: () => _selectPlace(
                            item['place_id']!,
                            item['description']!,
                          ),
                        );
                      },
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
