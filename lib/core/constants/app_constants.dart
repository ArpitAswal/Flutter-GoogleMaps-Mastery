import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  // Read web API key from .env file
  static String get googleMapsApiKey =>
      dotenv.env['GOOGLE_MAPS_WEB_API_KEY'] ?? '';
}