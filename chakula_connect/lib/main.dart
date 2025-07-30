// ignore_for_file: unused_import, use_build_context_synchronously

import 'package:chakula_connect/screens/rider/rider_dashboard.dart';
import 'package:chakula_connect/screens/rider/rider_home.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'firebase_options.dart';

// Screens
import 'screens/splash_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/donors/donor_dashboard.dart';
import 'screens/recipient/recipient_dashboard.dart';
// ignore: duplicate_import
import 'screens/rider/rider_home.dart'; // ✅ Rider dashboard
// ignore: duplicate_import
import 'screens/rider/rider_dashboard.dart'; // New rider dashboard with nav

// Theme controller using ValueNotifier
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("⚠️ Failed to load .env: $e");
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseFirestore.instance.enableNetwork();
  } catch (e) {
    debugPrint("⚠️ Firebase init error: ${e.toString()}");
  }

  runApp(
    const ProviderScope(
      child: ChakulaConnectApp(),
    ),
  );
}

class ChakulaConnectApp extends StatelessWidget {
  const ChakulaConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'ChakulaConnect',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.green,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            fontFamily: 'Roboto',
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.green,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            fontFamily: 'Roboto',
          ),
          initialRoute: '/splash',
          routes: {
            '/splash': (context) => const SplashScreen(),
            '/welcome': (context) => const WelcomeScreen(),
            '/login': (context) => const LoginScreen(),
            '/donor': (context) => const DonorDashboard(),
            '/recipient': (context) => const RecipientDashboard(),
            '/rider': (context) => const RiderDashboard(),
          },
        );
      },
    );
  }
}
