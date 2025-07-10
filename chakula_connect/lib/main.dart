import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/donor_dashboard.dart';
import 'screens/recipient_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: kIsWeb
        ? const FirebaseOptions(
            apiKey: "AIzaSyBEHWn31o5UhBw87ZwLXujH-aS_NcgjNg0",
            authDomain: "chakulaconnect.firebaseapp.com",
            projectId: "chakulaconnect",
            storageBucket: "chakulaconnect.appspot.com",
            messagingSenderId: "591799144347",
            appId: "1:591799144347:web:f9a036df7b1fd05c2bdb3e",
          )
        : null,
  );

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
