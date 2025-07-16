// ignore_for_file: unused_import

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart'; // ✅ Firebase options

// Screens
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/donor_dashboard.dart';
import 'screens/recipient_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize Firebase with platform-specific options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ Ensure Firestore is online (especially for web)
  try {
    await FirebaseFirestore.instance.enableNetwork();
  } catch (e) {
    print('Error enabling Firestore network: $e');
  }

  runApp(const ChakulaConnectApp());
}

class ChakulaConnectApp extends StatelessWidget {
  const ChakulaConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChakulaConnect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.light,
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
  }
}
