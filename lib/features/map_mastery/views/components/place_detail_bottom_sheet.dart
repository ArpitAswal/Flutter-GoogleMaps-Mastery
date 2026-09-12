import 'package:flutter/material.dart';
import '../../data/models/place_details_model.dart';

/// A draggable bottom sheet that displays rich Place Details.
/// It renders dynamic elements conditionally (e.g., hiding rating/phone if null).
class PlaceDetailBottomSheet extends StatelessWidget {
  final PlaceDetailsModel place;

  const PlaceDetailBottomSheet({super.key, required this.place});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Wrap content tightly.
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Place Name
          Text(
            place.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),

          // Conditionally render the rating row if data exists.
          if (place.rating != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 20),
                const SizedBox(width: 4),
                Text(
                  place.rating.toString(),
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),

          // Place Address
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, color: Colors.grey, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(place.address)),
            ],
          ),

          // Conditionally render the phone number row if data exists.
          if (place.phoneNumber != null) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.phone, color: Colors.grey, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(place.phoneNumber!)),
              ],
            ),
          ],

          const SizedBox(height: 24),

          // Primary Call-To-Action Button (Phase 4 Hook).
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                // TODO Phase 4: Implement directions and routing flow.
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Directions coming in Phase 4')),
                );
              },
              child: const Text('Get Directions'),
            ),
          ),

          // Apply padding at the bottom to account for iOS Home Indicators / Android gesture bars.
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
