import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Produces and caches [BitmapDescriptor] assets using [Canvas].
///
/// Visual convention: all icons are drawn pointing **north** (bearing 0°).
/// Heading rotation is applied via [Marker.rotation] in the view layer.
/// Any icon that does not naturally point north must declare a fixed visual
/// correction offset as a named constant inside its factory method.
class CustomMarkerPainter {
  CustomMarkerPainter._();

  static final Map<String, BitmapDescriptor> _cache = {};

  // ── Vehicle marker ────────────────────────────────────────────────────────

  /// Filled circle with a north-pointing arrow — used as the driver vehicle icon.
  /// [pixelRatio] should match [MediaQuery.devicePixelRatioOf(context)].
  static Future<BitmapDescriptor> vehicleMarker({
    double pixelRatio = 3.0,
    Color color = Colors.blue,
    int logicalSize = 60,
  }) async {
    final key = 'vehicle_\${color.value}_\${logicalSize}_\$pixelRatio';
    if (_cache.containsKey(key)) return _cache[key]!;

    final size = logicalSize * pixelRatio;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Shadow
    canvas.drawCircle(
      Offset(size / 2, size / 2 + 2),
      size / 2,
      Paint()..color = Colors.black.withValues(alpha: 0.25),
    );
    // Body
    canvas.drawCircle(
      Offset(size / 2, size / 2), size / 2 - 2, Paint()..color = color,
    );
    // White border
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2 - 2,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.05,
    );
    // North-pointing arrow (visual offset = 0°; no correction constant needed)
    final arrow = Path()
      ..moveTo(size / 2, size * 0.12)
      ..lineTo(size * 0.68, size * 0.62)
      ..lineTo(size / 2, size * 0.52)
      ..lineTo(size * 0.32, size * 0.62)
      ..close();
    canvas.drawPath(arrow, Paint()..color = Colors.white);

    final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final descriptor = BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
    _cache[key] = descriptor;
    return descriptor;
  }

  // ── Destination marker ────────────────────────────────────────────────────

  /// Teardrop pin — used for origin and destination place markers.
  static Future<BitmapDescriptor> destinationMarker({
    double pixelRatio = 3.0,
    Color color = Colors.red,
    int logicalSize = 56,
  }) async {
    final key = 'destination_\${color.value}_\${logicalSize}_\$pixelRatio';
    if (_cache.containsKey(key)) return _cache[key]!;

    final size = logicalSize * pixelRatio;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final cx = size / 2;
    final r = size * 0.35;

    canvas.drawCircle(Offset(cx, r), r, Paint()..color = color);
    final stem = Path()
      ..moveTo(cx - r * 0.5, r * 1.6)
      ..lineTo(cx + r * 0.5, r * 1.6)
      ..lineTo(cx, size * 0.96)
      ..close();
    canvas.drawPath(stem, Paint()..color = color);
    canvas.drawCircle(Offset(cx, r), r * 0.4, Paint()..color = Colors.white);

    final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final descriptor = BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
    _cache[key] = descriptor;
    return descriptor;
  }

  // ── Cache management ──────────────────────────────────────────────────────

  /// Releases in-memory cache. Call from the app's low-memory callback.
  static void clearCache() => _cache.clear();
}
