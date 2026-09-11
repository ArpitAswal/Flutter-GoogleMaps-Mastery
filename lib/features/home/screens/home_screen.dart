import 'package:flutter/material.dart';

import '../../CoreMapFeatures/screens/basic_map.dart';
import '../../CustomMarkers/Screens/markers_screen.dart';
import '../../LiveTracking/screens/live_tracking_location.dart';
import '../../NavigationTurn/screens/navigation_screen.dart';
import '../../PlaceSearchGeocoding/screens/place_search.dart';
import '../../RoutesPolyline/screens/route_polyline.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final modules = [
      {
        'title': '1. Core Map & Camera Control',
        'subtitle': 'Initialize map, map types, and programmatic camera moves',
        'page': const BasicMapScreen(),
      },
      {
        'title': '2. Custom Markers & Info Windows',
        'subtitle': 'Asset markers, hue tints, custom metadata info windows',
        'page': const CustomMarkersScreen(),
      },
      {
        'title': '3. Place Search & Reverse Geocoding',
        'subtitle':
            'Places API Autocomplete, Place Details, and LatLng translation',
        'page': const PlaceSearchScreen(),
      },
      {
        'title': '4. Route Calculation & Polylines',
        'subtitle':
            'Directions API overview polyline decoding & distance metrics',
        'page': const RoutePolylinesScreen(),
      },
      {
        'title': '5. Real-Time Tracking & Simulation',
        'subtitle':
            'GPS stream listener and smooth vehicle bearing interpolation',
        'page': LiveTrackingScreen(),
      },
      {
        'title': '6. Turn-by-Turn Navigation Trigger',
        'subtitle':
            'Launch native Google Maps / Apple Maps external navigation',
        'page': const NavigationLauncherScreen(),
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Maps Mastery Suite'),
        elevation: 2,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: modules.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, index) {
          final item = modules[index];
          return ListTile(
            leading: CircleAvatar(child: Text('${index + 1}')),
            title: Text(
              item['title'] as String,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(item['subtitle'] as String),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => item['page'] as Widget),
            ),
          );
        },
      ),
    );
  }
}
