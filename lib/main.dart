import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'features/home/screens/home_screen.dart';
import 'firebase_options.dart';

/// Application entry point.
///
/// Initialisation order:
///   1. Flutter engine binding
///   2. dotenv (.env file — contains the Maps REST key for Android/iOS)
///   3. Firebase core
///   4. Anonymous Firebase Auth (required for Firestore security rules)
///   5. App widget
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load Maps REST key from the git-ignored .env file
  await dotenv.load(fileName: '.env');

  // Initialise Firebase — will throw at runtime until google-services.json
  // (Android: android/app/) and GoogleService-Info.plist (iOS: ios/Runner/)
  // are added after running `flutterfire configure`.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Anonymous sign-in required for Firestore security rules.
  // Runs in the background; Map Mastery features handle auth-not-ready gracefully.
  FirebaseAuth.instance.signInAnonymously().ignore();

  runApp(const GoogleMapsMasteryApp());
}

class GoogleMapsMasteryApp extends StatelessWidget {
  const GoogleMapsMasteryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Google Maps Mastery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
