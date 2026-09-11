import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/service/google_map_service.dart';
import '../../../core/utils/map_helper.dart';

class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen>
    with SingleTickerProviderStateMixin {
  late GoogleMapController? _mapController;
  late MapHelpers _helpers;
  // Animation & Interpolation
  late AnimationController _animationController;

  Marker? _driverMarker;
  LatLng? _previousPosition;
  String _distance = '';
  String _trafficDuration = '';

  // The subscription that listens to live GPS updates
  StreamSubscription<Position>? _positionStreamSubscription;
  LatLng? originLoc;

  final Set<Polyline> _polylines = {};
  final GoogleMapsService _mapsService = GoogleMapsService();

  double _previousBearing = 0.0;
  // The bitmap faces east. Google Maps marker rotation is clockwise from north.
  static const double _vehicleAssetBearingOffset = -90.0;
  String _travelPref = 'deliver';
  LatLng deliverPreference = LatLng(28.866577617226547, 77.59964060638056);
  LatLng userPreference = LatLng(28.85554587878866, 77.59031153863529);
  double _totalDistanceMeters = 0.0;
  int _initialDurationSeconds = 0;
  List<LatLng> _routePoints = [];

  @override
  void initState() {
    super.initState();
    _helpers = MapHelpers();
    //Initialize the Animation Controller (runs over 1.5 seconds to match typical GPS intervals)
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fetchRouteAndStartTracking();
  }

  Future<void> _fetchRouteAndStartTracking() async {
    await _startLiveTracking();
  }

  // ==========================================
  // ROUTE FETCHING (Module 4 Integration)
  // ==========================================
  Future<void> _fetchPolylineRoute({required LatLng origin}) async {
    setState(() {
      _polylines.clear(); // Clear previous route
    });
    try {
      final routeData = await _mapsService.getDirections(
        origin: _travelPref == 'deliver' ? deliverPreference : origin,
        destination: _travelPref == 'deliver'
            ? userPreference
            : deliverPreference,
        mode: 'two_wheeler',
      );
      if (routeData != null) {
        final List<LatLng> points = routeData['points'];

        // Extract total distance in meters
        double calculatedTotalMeters = 0.0;
        for (int i = 0; i < points.length - 1; i++) {
          calculatedTotalMeters += Geolocator.distanceBetween(
            points[i].latitude,
            points[i].longitude,
            points[i + 1].latitude,
            points[i + 1].longitude,
          );
        }

        // Parse duration into raw seconds (assuming default ~15-20 mins if unavailable)
        int parsedSeconds = 900; // default 15 mins fallback
        if (routeData['duration'] != null) {
          final String durText = routeData['duration'].toString().toLowerCase();
          final int? mins = int.tryParse(
            RegExp(r'\d+').stringMatch(durText) ?? '',
          );
          if (mins != null) parsedSeconds = mins * 60;
        }

        setState(() {
          _distance = routeData['distance'];
          _trafficDuration = routeData['traffic_duration'];
          _routePoints = points;
          _totalDistanceMeters = calculatedTotalMeters;
          _initialDurationSeconds = parsedSeconds;
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
      }
    } catch (e) {
      debugPrint('Routing error: $e');
    }
  }

  // ==========================================
  // CORE TRACKING LOGIC
  // ==========================================
  Future<void> _startLiveTracking() async {
    // 1. Verify Permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return; // Handle permission denial gracefully in production
      }
    }

    final vehicleIcon = await _helpers.getVehicleIcon();
    _positionStreamSubscription?.cancel();

    Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    originLoc = LatLng(position.latitude, position.longitude);
    await _fetchPolylineRoute(origin: originLoc!);

    // 2. Listen to the simulated route stream. For production GPS, replace this
    // with Geolocator.getPositionStream using a 2 m distance filter.
    // _positionStreamSubscription =
    //     Geolocator.getPositionStream(
    //       locationSettings: locationSettings,
    //     ).

    /// Replace Geolocator with the mock stream
    _positionStreamSubscription =
        createStaticRouteStream(
          routePoints: _routePoints,
          interval: const Duration(seconds: 10), // Adjust tick speed here
        ).listen((Position position) {
          final LatLng newPosition = LatLng(
            position.latitude,
            position.longitude,
          );

          // --- DYNAMIC METRIC UPDATES ON EVERY TICK ---
          final double remainingMeters = _helpers.calculateRemainingMeters(
            currentPos: newPosition,
            polylinePoints: _routePoints,
          );

          final String updatedDistance = _helpers.formatMeters(remainingMeters);
          final String updatedDuration = _helpers.computeRemainingTime(
            remainingMeters: remainingMeters,
            totalMeters: _totalDistanceMeters,
            initialSeconds: _initialDurationSeconds,
          );

          if (_previousPosition == null) {
            // Point the initial marker at the next simulated route point so it
            // does not appear to face east while waiting for the second fix.
            final double initialBearing = _initialBearingFor(newPosition);
            _previousPosition = newPosition;
            _previousBearing = initialBearing;
            _updateMarkerAndCamera(newPosition, initialBearing, vehicleIcon);
            setState(() {
              _distance = updatedDistance;
              _trafficDuration = updatedDuration;
            });
            return;
          }

          // Bearing is geographic (clockwise from north), so a flat marker
          // remains correct when the user rotates the map with its compass.
          final double rawBearing = _helpers.calculateBearing(
            _previousPosition!,
            newPosition,
          );
          final double correctedBearing = _normalizeBearing(
            rawBearing + _vehicleAssetBearingOffset,
          );

          // 3. Trigger the Glide Animation between the old coordinate and new coordinate
          _animateMarkerGlide(
            _previousPosition!,
            newPosition,
            _previousBearing,
            correctedBearing,
            vehicleIcon,
          );
          setState(() {
            _distance = updatedDistance;
            _trafficDuration = updatedDuration;
          });

          _previousPosition = newPosition;
          _previousBearing = correctedBearing;
        });
  }

  @override
  void dispose() {
    // CRITICAL: Always cancel the stream when leaving the screen to prevent memory leaks and battery drain
    _positionStreamSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Stream<Position> createStaticRouteStream({
    required List<LatLng> routePoints,
    required Duration interval,
  }) {
    late StreamController<Position> controller;
    Timer? timer;
    int currentIndex = 0;

    controller = StreamController<Position>(
      onListen: () {
        if (routePoints.isEmpty) {
          controller.close();
          return;
        }

        timer = Timer.periodic(interval, (t) {
          // Emit current coordinate
          controller.add(
            Position(
              longitude: routePoints[currentIndex].longitude,
              latitude: routePoints[currentIndex].latitude,
              timestamp: DateTime.now(),
              accuracy: 1.0,
              altitude: 0.0,
              heading: 0.0,
              speed: 0.0,
              speedAccuracy: 0.0,
              altitudeAccuracy: 0.0,
              headingAccuracy: 0.0,
            ),
          );

          // If we reached the final coordinate, stop the simulation
          if (currentIndex >= routePoints.length - 1) {
            t.cancel();
            controller.close();
          } else {
            currentIndex++;
          }
        });
      },
      onCancel: () {
        timer?.cancel();
      },
    );

    return controller.stream;
  }

  double _initialBearingFor(LatLng position) {
    if (_routePoints.length < 2) return _previousBearing;

    final LatLng nextPosition = _routePoints[1];
    return _normalizeBearing(
      _helpers.calculateBearing(position, nextPosition) +
          _vehicleAssetBearingOffset,
    );
  }

  double _normalizeBearing(double bearing) => (bearing + 360.0) % 360.0;

  // ==========================================
  // ANIMATION & CAMERA UPDATES
  // ==========================================
  void _animateMarkerGlide(
    LatLng startPos,
    LatLng endPos,
    double startBearing,
    double endBearing,
    BitmapDescriptor icon,
  ) {
    _animationController.reset();

    Animation<double> animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.linear,
    );

    // Calculate shortest rotation path to avoid the marker spinning completely around
    double rotationDiff = (endBearing - startBearing) % 360;
    if (rotationDiff > 180) {
      rotationDiff -= 360;
    } else if (rotationDiff < -180) {
      rotationDiff += 360;
    }
    final double finalBearing = startBearing + rotationDiff;

    animation.addListener(() {
      final double t = animation.value;

      // Math to find the exact coordinate between the two points at this specific millisecond
      final double interpolatedLat =
          startPos.latitude + (endPos.latitude - startPos.latitude) * t;
      final double interpolatedLng =
          startPos.longitude + (endPos.longitude - startPos.longitude) * t;
      // Keep the starting bearing in the interpolation. Omitting it made the
      // icon jump back toward zero degrees on every position update.
      final double interpolatedBearing = _normalizeBearing(
        startBearing + (finalBearing - startBearing) * t,
      );

      _updateMarkerAndCamera(
        LatLng(interpolatedLat, interpolatedLng),
        interpolatedBearing,
        icon,
      );
    });

    _animationController.forward();
  }

  void _updateMarkerAndCamera(
    LatLng position,
    double bearing,
    BitmapDescriptor icon,
  ) {
    setState(() {
      _driverMarker = Marker(
        markerId: const MarkerId('live_driver'),
        position: position,
        rotation: bearing,
        anchor: const Offset(0.5, 0.5),
        flat: true,
        icon: icon,
        zIndexInt: 5,
        infoWindow: InfoWindow(
          title: 'Courier Partner',
          snippet: 'Bearing: ${bearing.toStringAsFixed(1)}°',
        ),
      );
    });

    // Recenter without changing camera bearing, tilt, or zoom. The user's map
    // orientation is therefore respected, while `flat: true` keeps the marker
    // aligned with its real-world heading on the rotated map.
    _mapController?.animateCamera(CameraUpdate.newLatLng(position));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('05: Live Tracking Stream'),
        actions: [
          // Travel mode selector
          Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(30),
            color: Colors.white,
            child: ToggleButtons(
              borderRadius: BorderRadius.circular(30),
              isSelected: [_travelPref == 'user', _travelPref == 'deliver'],
              onPressed: (index) {
                setState(() {
                  if (index == 0) _travelPref = 'user';
                  if (index == 1) _travelPref = 'deliver';
                  _startLiveTracking();
                });
              },
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.home),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.delivery_dining),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: originLoc ?? LatLng(28.6129, 77.2295),
              zoom: 14,
            ),
            markers: _driverMarker != null ? {_driverMarker!} : {},
            polylines: _polylines,
            zoomControlsEnabled: false,
            myLocationEnabled:
                false, // We disable the native blue dot to use our custom marker
            myLocationButtonEnabled: false,
            compassEnabled:
                true, // The user can tap it to instantly reset the map to face true North.
            onMapCreated: (c) => _mapController = c,
          ),
          // Live Status Card
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Colors.greenAccent,
                      radius: 8,
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Wrap(
                          runSpacing: 4,
                          children: [
                            const Text(
                              'Live GPS Stream Active',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const VerticalDivider(),
                            Text(
                              _previousPosition != null
                                  ? '${_previousPosition!.latitude.toStringAsFixed(5)}, ${_previousPosition!.longitude.toStringAsFixed(5)}'
                                  : 'Waiting for satellite fix...',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        if (_distance.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text('Distance : $_distance'),
                              const VerticalDivider(),
                              Text('Time : $_trafficDuration'),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
