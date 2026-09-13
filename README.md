# 🗺️ Google Maps in Flutter — Complete Learning Project

> A fully annotated Flutter project implementing **every core concept** of the `google_maps_flutter` package and Google Maps Web Services APIs. Built as an interactive educational hub to teach you exactly how to build advanced location-based apps.

📱 **Cross-Platform Ready**: This project perfectly supports and is optimized for **Android** and **iOS**. You can easily learn and explore the concepts by running it directly on any of these platforms!

---

## 📖 What You Will Learn

This project teaches you **6 advanced Google Maps concepts** and how to tie them together in a production-level application, entirely through working, commented code:

| # | Concept | File(s) |
|---|---------|---------|
| 1 | Basic Map & Camera Controls | `features/CoreMapFeatures/screens/basic_map.dart` |
| 2 | Custom Markers & Info Windows | `features/CustomMarkers/screens/markers_screen.dart` |
| 3 | Place Search & Geocoding | `features/PlaceSearchGeocoding/screens/place_search.dart` |
| 4 | Drawing Routes & Polylines | `features/RoutesPolyline/screens/route_polyline.dart` |
| 5 | Live Location Tracking | `features/LiveTracking/screens/live_tracking_location.dart` |
| 6 | Turn-by-Turn Navigation | `features/NavigationTurn/screens/navigation_screen.dart` |
| 7 | Map Mastery (Production Module) | `features/map_mastery/views/map_mastery_screen.dart` |

---

## 🗂️ Project Structure

```
lib/
├── main.dart                          # App entry point & Theme setup
├── core/                              
│   ├── constants/app_constants.dart   # 🔑 Env variable management
│   ├── service/google_map_service.dart# 🌐 API calls for Directions, Places & Geocoding
│   └── service/location_service.dart  # 📍 Hardware GPS and permissions management
├── features/
│   ├── home/                          # 🏠 Hub screen — links to all map demos
│   ├── CoreMapFeatures/               # 🗺️ Basic maps, styling, and camera movement
│   ├── CustomMarkers/                 # 📍 Custom icons, clustering, and InfoWindows
│   ├── PlaceSearchGeocoding/          # 🔍 Autocomplete API and Lat/Lng translation
│   ├── RoutesPolyline/                # 🛣️ Directions API and Polyline drawing
│   ├── LiveTracking/                  # 🚶‍♂️ Real-time GPS stream and marker updating
│   ├── NavigationTurn/                # 🧭 Step-by-step navigation logic
│   └── map_mastery/                   # 🚀 Production-ready map implementation (MVVM/Cubit)
```

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.x+)
- Dart 3.x
- A Google Cloud Platform (GCP) account with Maps APIs enabled (Maps SDK for Android/iOS, Places API, Directions API, Geocoding API).

### 🔑 How to Add Your API Keys
This project is built with **military-grade security configurations**. Your keys are injected natively so they are never accidentally pushed to GitHub.

When you clone this project, you must create three files locally to inject your keys:

**1. For Android**
Create or edit `android/local.properties` and add:
```properties
GOOGLE_MAPS_ANDROID_API_KEY=your_android_key_here
```

**2. For iOS**
Create a new file at `ios/Flutter/APIKeys.xcconfig` and add:
```text
GOOGLE_MAPS_IOS_API_KEY=your_ios_key_here
```

**3. For Dart REST Services (Directions, Places API)**
Create a `.env` file in the root of the project and add:
```text
GOOGLE_MAPS_API_KEY=your_rest_api_key_here
```

**4. For Firebase (Map Mastery Module)**
This project uses Firebase for the Map Mastery live tracking module. Since `lib/firebase_options.dart` is intentionally excluded from version control, you must generate your own by connecting your Firebase project:
```bash
# Install the FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure your project (this generates lib/firebase_options.dart)
flutterfire configure
```
*Note: The app will fail to compile if `lib/firebase_options.dart` is missing, as `main.dart` requires it for `Firebase.initializeApp()`.*

### Run the App

```bash
# Clone and navigate to the project
cd google_map_one_for_all

# Install dependencies
flutter pub get

# Run the app (Works on iOS and Android)
flutter run
```

---

## 📚 Concepts Deep Dive

### 1. Basic Maps & Camera
Learn how to instantiate the `GoogleMap` widget, handle the `onMapCreated` controller, switch map types (Satellite, Hybrid, Terrain), and programmatically animate the camera to new coordinates.

### 2. Custom Markers
Standard red pins are boring! This module teaches you how to convert Image assets or raw ByteData into custom `BitmapDescriptor` markers, and how to capture tap events to show custom InfoWindows.

### 3. Place Search (Autocomplete) & Geocoding
Typing an address shouldn't be hard. This module connects to the **Google Places API** to provide real-time search suggestions. Selecting a place uses the **Geocoding API** to instantly snap the map camera to the correct Latitude and Longitude.

### 4. Routes & Polylines
Give the map an Origin and Destination, and this module will hit the **Google Directions API**, parse the complex JSON geometry, and draw a beautiful, glowing `Polyline` directly on the road network.

### 5. Live Tracking
Uses the `geolocator` package to request hardware GPS permissions, subscribe to the user's live location stream, and dynamically update a marker's position on the map as the user walks around.

### 6. Navigation
Combines Polylines, Live Tracking, and Camera updates to simulate a real turn-by-turn navigation experience, keeping the user's "puck" centered on the route.

### 7. Map Mastery (Production Module)
A production-ready MVVM/Cubit-based module demonstrating advanced patterns: resilient location permission handling, multi-modal concurrent routing (Driving, Transit, Walking, Two-Wheeler), debounced place autocomplete, and real-time live driver tracking using Firestore with an anonymous authentication architecture.

---

## 🚀 Map Mastery — Production Module

The existing learning demos remain intact. We are currently implementing a new Cubit/MVVM-based Map Mastery module intended for production-level stability. It covers permission recovery, traffic and POIs, debounced place search, multi-modal routing, Firestore driver tracking, and remote trip viewing for Android and iOS.

**Status: Phase 4 Completed** ✅
- **Phase 1 & 2 (Foundation & Core):** Firebase and MVVM project structure initialized, immutable models and Repository/DataSource stubs created, and robust location permission recovery flow implemented using purely reactive BLoC/Cubit state management.
- **Phase 3 (Discovery):** Implemented debounced Google Places autocomplete search, dynamic full-screen overlay for search predictions, and rich Point of Interest (POI) bottom sheet details driven by reverse-geocoding place IDs on map gestures.
- **Phase 4 (Routing):** Implemented multi-modal directions (Driving, Transit, Walking, Two-Wheeler), active route polyline rendering, smart floating action button state management, and real-time route metrics display.

> [!NOTE]
> **Map Tap vs. Place Search**
> The `google_maps_flutter` plugin does not natively support capturing the exact Place ID of built-in points of interest (POIs) when tapped. Long-pressing the map canvas utilizes the Reverse Geocoding API, which resolves to the *nearest street address or generic point*. 
> For exact POI details (like a specific university, restaurant, or business), please use the **Place Search (Autocomplete)** feature at the top of the screen.


---

## 📦 Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  google_maps_flutter: ^2.x.x
  geolocator: ^10.x.x
  flutter_dotenv: ^5.x.x
  # And more! Check pubspec.yaml
```

---

## 📄 Reference

- 📦 **Package**: [google_maps_flutter on pub.dev](https://pub.dev/packages/google_maps_flutter)
- 📖 **Official Docs**: [Google Maps Platform](https://developers.google.com/maps/documentation)

---

*Built as a comprehensive Flutter learning resource — every concept is clearly explained with live demos, code snippets, and real-world implementation.*

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

This repository is provided for portfolio and evaluation purposes only.

Commercial use, redistribution, modification, or reproduction without written permission is prohibited.

Developed with ❤️ by **Arpit Aswal**.

