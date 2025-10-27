// ignore_for_file: use_build_context_synchronously

import 'package:chakula_connect/screens/recipient/recipient_dashboard.dart';
import 'package:chakula_connect/screens/rider/rider_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'register_screen.dart';
import 'forgot_password_screen.dart'; // 🔗 Linked here
import 'donors/donor_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameOrEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _obscurePassword = true;
  String? _selectedRole;

  final List<String> _roles = ['Donor', 'Recipient', 'Rider'];

  Future<void> _loadSavedLogin() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _usernameOrEmailController.text =
          prefs.getString('saved_username_or_email') ?? '';
      _rememberMe = prefs.getBool('remember_me') ?? false;
      _selectedRole = prefs.getString('saved_role');
    });
  }

  Future<void> _login() async {
    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select your role")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final input = _usernameOrEmailController.text.trim();
      final password = _passwordController.text.trim();

      String email = input;

      if (!input.contains('@')) {
        final userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: input)
            .limit(1)
            .get();

        if (userQuery.docs.isEmpty) {
          throw Exception("Username not found");
        }
        email = userQuery.docs.first['email'];
      }

      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user?.uid;
      if (uid == null) throw Exception("User ID not found");

      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!userDoc.exists) throw Exception("User profile not found");

      final role = userDoc['role'] as String?;

      if (role != _selectedRole) {
        throw Exception("Role mismatch. You selected $_selectedRole but this account is a $role.");
      }

      if (_rememberMe) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_username_or_email', input);
        await prefs.setBool('remember_me', true);
        await prefs.setString('saved_role', _selectedRole!);
      }

      switch (role) {
        case 'Donor':
          Navigator.pushReplacement(
              // ignore: duplicate_ignore
              // ignore: use_build_context_synchronously
              context, MaterialPageRoute(builder: (_) => const DonorDashboard()));
          break;
        case 'Recipient':
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const RecipientDashboard()));
          break;
        case 'Rider':
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const RiderDashboard()));
          break;
        default:
          throw Exception("Unknown role: $role");
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message ?? "Login error")));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Login failed: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSavedLogin();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset("assets/images/Chakula Connect.png", height: 100),
              const SizedBox(height: 20),
              Text(
                "Welcome to ChakulaConnect",
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
              const SizedBox(height: 10),
              Text("Login to continue", style: TextStyle(color: Colors.grey[700])),
              const SizedBox(height: 30),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: "Login as",
                  border: OutlineInputBorder(),
                ),
                items: _roles
                    .map((role) =>
                        DropdownMenuItem(value: role, child: Text(role)))
                    .toList(),
                onChanged: (value) => setState(() => _selectedRole = value),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _usernameOrEmailController,
                decoration: const InputDecoration(
                  labelText: "Email or Username",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: "Password",
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Checkbox(
                    value: _rememberMe,
                    onChanged: (val) => setState(() => _rememberMe = val ?? false),
                  ),
                  const Text("Remember me"),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                      );
                    },
                    child: const Text("Forgot Password?"),
                  )
                ],
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _login,
                        child: const Text("Login", style: TextStyle(fontSize: 16),selectionColor: (Colors.white)),
                      ),
                    ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                ),
                child: const Text("Don't have an account? Register"),
              )
            ],
          ),
        ),
      ),
    );
  }
}
