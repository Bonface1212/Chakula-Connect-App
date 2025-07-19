// ignore_for_file: unused_import, use_build_context_synchronously

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'firebase_options.dart';

// Screens
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/donor_dashboard.dart';
import 'screens/recipient_dashboard.dart';

// Theme controller using ValueNotifier
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // ✅ Load environment variables securely
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("⚠️ Failed to load .env: $e");
  }

  try {
    // ✅ Initialize Firebase safely
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // ✅ Ensure Firestore is connected (especially for web)
    await FirebaseFirestore.instance.enableNetwork();
  } catch (e) {
    debugPrint("⚠️ Firebase init error: ${e.toString()}");
  }

  // ✅ Wrap app with ProviderScope (Riverpod support)
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
          initialRoute: '/',
          routes: {
            '/': (context) => const WelcomeScreen(),
            '/login': (context) => const LoginScreen(),
            '/donor': (context) => const DonorDashboard(),
            '/recipient': (context) => const RecipientDashboard(),
          },
        );
      },
    );
  }
}
