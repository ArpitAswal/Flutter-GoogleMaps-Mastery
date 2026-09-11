import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/service/google_map_service.dart';

class PlaceSearchScreen extends StatefulWidget {
  const PlaceSearchScreen({super.key});

  @override
  State<PlaceSearchScreen> createState() => _PlaceSearchScreenState();
}

class _PlaceSearchScreenState extends State<PlaceSearchScreen> {
  final GoogleMapsService _mapsService = GoogleMapsService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  late GoogleMapController _mapController;
  List<Map<String, String>> _predictions = [];
  final Set<Marker> _markers = {};
  String _currentReverseAddress = 'Tap anywhere to resolve address';

  void _onSearchChanged(String value) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _predictions = [];
      });
      return;
    }

    // Wait 500ms after the user stops typing before making the network request
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      final results = await _mapsService.searchPlaces(value);
      setState(() => _predictions = results);
    });
  }

  void _selectPlace(String placeId, String description) async {
    final LatLng? coords = await _mapsService.getPlaceCoordinates(placeId);
    if (coords != null) {
      setState(() {
        _predictions.clear();
        _searchController.text = description;
        _currentReverseAddress = description;
        _markers.clear();
        _markers.add(
          Marker(
            markerId: const MarkerId('searched_place'),
            position: coords,
            infoWindow: InfoWindow(title: description),
          ),
        );
      });

      _mapController.animateCamera(CameraUpdate.newLatLngZoom(coords, 15));
    }
  }

  void _handleMapTap(LatLng point) async {
    setState(() => _currentReverseAddress = 'Resolving address...');
    final address = await _mapsService.getAddressFromCoordinates(point);
    setState(() {
      _currentReverseAddress = address;
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('tapped_location'),
          position: point,
          infoWindow: InfoWindow(title: 'Selected Point', snippet: address),
        ),
      );
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('03: Search & Geocoding')),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(28.6139, 77.2090),
              zoom: 12,
            ),
            markers: _markers,
            onMapCreated: (c) => _mapController = c,
            onTap: _handleMapTap,
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search place name or landmark...',
                    fillColor: Colors.white,
                    filled: true,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _predictions.clear());
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              // if (_predictions.isNotEmpty)
              //   Container(
              //     color: Colors.white,
              //     margin: const EdgeInsets.symmetric(horizontal: 12),
              //     constraints: const BoxConstraints(maxHeight: 240),
              //     child: ListView.builder(
              //       shrinkWrap: true,
              //       itemCount: _predictions.length,
              //       itemBuilder: (context, index) {
              //         final item = _predictions[index];
              //         return ListTile(
              //           leading: const Icon(Icons.location_on),
              //           title: Text(item['description'] ?? ''),
              //           onTap: () => _selectPlace(
              //             item['place_id']!,
              //             item['description']!,
              //           ),
              //         );
              //       },
              //     ),
              //   ),
              // Autocomplete Result Dropdown
              if (_predictions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: Material(
                    elevation: 6, // Replaces the BoxShadow
                    borderRadius: BorderRadius.circular(8),
                    color: Colors
                        .white, // The background color is now on the Material widget
                    clipBehavior: Clip
                        .antiAlias, // Ensures the ripple effect respects the rounded corners
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _predictions.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = _predictions[index];
                        return ListTile(
                          leading: const Icon(
                            Icons.location_on_outlined,
                            color: Colors.blueGrey,
                          ),
                          title: Text(
                            item['main_text'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            item['description'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onTap: () => _selectPlace(
                            item['place_id']!,
                            item['description']!,
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _currentReverseAddress,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
