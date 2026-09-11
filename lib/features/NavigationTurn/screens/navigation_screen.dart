import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class NavigationLauncherScreen extends StatefulWidget {
  const NavigationLauncherScreen({super.key});

  @override
  State<NavigationLauncherScreen> createState() => _NavigationLauncherScreenState();
}

class _NavigationLauncherScreenState extends State<NavigationLauncherScreen> {
  // Example Destination: A customer's delivery address
  final LatLng _customerDestination = const LatLng(28.6129, 77.2294); // India Gate

  // Selectable travel mode
  String _travelMode = 'd'; // 'd' = driving, 'l' = two-wheeler (Android), 'w' = walking

  Future<void> _launchNativeNavigation() async {
    final double lat = _customerDestination.latitude;
    final double lng = _customerDestination.longitude;

    if (Platform.isAndroid) {
      // 1. Android: Try launching native Google Maps Navigation intent
      final Uri androidIntentUri = Uri.parse('google.navigation:q=$lat,$lng&mode=$_travelMode');

      if (await canLaunchUrl(androidIntentUri)) {
        await launchUrl(androidIntentUri);
      } else {
        // Fallback to web browser routing if Google Maps app is disabled/missing
        _launchWebFallback(lat, lng);
      }
    } else if (Platform.isIOS) {
      // 2. iOS: Try launching Google Maps first
      final String iosDirectionsMode = _travelMode == 'w' ? 'walking' : 'driving';
      final Uri iosGoogleMapsUri = Uri.parse('comgooglemaps://?saddr=28.6200,77.2050&daddr=$lat,$lng&directionsmode=$iosDirectionsMode');

      if (await canLaunchUrl(iosGoogleMapsUri)) {
        await launchUrl(iosGoogleMapsUri);
      } else {
        // 3. iOS: Fallback to Apple Maps if Google Maps is not installed
        final String appleDirFlg = _travelMode == 'w' ? 'w' : 'd';
        final Uri appleMapsUri = Uri.parse('maps://?saddr=28.6200,77.2050&daddr=$lat,$lng&dirflg=$appleDirFlg');

        if (await canLaunchUrl(appleMapsUri)) {
          await launchUrl(appleMapsUri);
        } else {
          // Final Fallback to web browser
          _launchWebFallback(lat, lng);
        }
      }
    }
  }

  Future<void> _launchWebFallback(double lat, double lng) async {
    final Uri webUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    if (await canLaunchUrl(webUrl)) {
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch navigation')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('06: Turn-by-Turn Navigation'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.explore, size: 80, color: Colors.blue),
              ),
              const SizedBox(height: 24),
              const Text(
                'Customer Destination:',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 4),
              const Text(
                'India Gate, New Delhi',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '${_customerDestination.latitude}, ${_customerDestination.longitude}',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),

              // Travel Mode Selector
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'd', icon: Icon(Icons.directions_car), label: Text('Car')),
                  ButtonSegment(value: 'l', icon: Icon(Icons.two_wheeler), label: Text('Bike')),
                  ButtonSegment(value: 'w', icon: Icon(Icons.directions_walk), label: Text('Walk')),
                ],
                selected: {_travelMode},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _travelMode = newSelection.first;
                  });
                },
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.navigation),
                  label: const Text('Start Navigation', style: TextStyle(fontSize: 16)),
                  onPressed: _launchNativeNavigation,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}