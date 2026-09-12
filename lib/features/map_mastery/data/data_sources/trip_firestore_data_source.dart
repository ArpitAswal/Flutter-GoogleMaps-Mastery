import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/live_trip_model.dart';

/// Owns all Firestore I/O for the `active_trips` collection.
/// Receives a [FirebaseFirestore] instance through the constructor.
///
/// ─── Suggested Firestore security rules ────────────────────────────────────
/// rules_version = '2';
/// service cloud.firestore {
///   match /databases/{database}/documents {
///     match /active_trips/{tripId} {
///       // Only authenticated users may create a trip document.
///       allow create: if request.auth != null
///                     && request.resource.data.tripId == tripId;
///       // Only the trip creator may update telemetry.
///       allow update: if request.auth != null
///                     && request.auth.uid == resource.data.creatorUid;
///       // Any authenticated user (viewer with trip ID) may read.
///       allow read: if request.auth != null;
///     }
///   }
/// }
/// ───────────────────────────────────────────────────────────────────────────
class TripFirestoreDataSource {
  final FirebaseFirestore _firestore;

  static const _collection = 'active_trips';

  const TripFirestoreDataSource({required FirebaseFirestore firestore})
      : _firestore = firestore;

  DocumentReference<Map<String, dynamic>> _ref(String tripId) =>
      _firestore.collection(_collection).doc(tripId);

  // ── Write operations ──────────────────────────────────────────────────────

  /// Creates a new trip document. Must complete before location streaming begins.
  Future<void> createTrip(LiveTripModel trip) =>
      _ref(trip.tripId).set(trip.toFirestore());

  /// Merge-updates driver telemetry only, preserving all other trip fields.
  Future<void> updateDriverLocation(
    String tripId,
    Map<String, dynamic> locationData,
  ) =>
      _ref(tripId).set(
        {
          'driverLocation': locationData,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

  /// Merge-updates remaining distance/duration metrics.
  Future<void> updateMetrics(
    String tripId, {
    required String remainingDistance,
    required String remainingDuration,
  }) =>
      _ref(tripId).set(
        {
          'remainingDistance': remainingDistance,
          'remainingDuration': remainingDuration,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

  /// Marks the trip completed (terminal state — no further writes expected).
  Future<void> completeTrip(String tripId) => _ref(tripId).update({
        'status': TripStatus.completed.firestoreValue,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// Marks the trip cancelled (terminal state).
  Future<void> cancelTrip(String tripId) => _ref(tripId).update({
        'status': TripStatus.cancelled.firestoreValue,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  // ── Read operations ───────────────────────────────────────────────────────

  /// Real-time stream for [tripId].
  /// Emits [null] when the document is missing or cannot be deserialised
  /// (malformed document) rather than throwing.
  Stream<LiveTripModel?> watchTrip(String tripId) {
    return _ref(tripId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      try {
        return LiveTripModel.fromFirestore(snapshot);
      } catch (_) {
        return null; // Viewer sees a retained last-valid state + error banner
      }
    });
  }
}
