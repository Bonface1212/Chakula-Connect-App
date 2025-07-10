import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:location/location.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';

import 'donor_dashboard.dart';
import 'recipient_dashboard.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final Location _location = Location();

  File? _profileImage;
  String? _role;
  bool _isLoading = false;
  bool _showPassword = false;
  bool _showImageError = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _locationController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();

  PhoneNumber _phoneNumber = PhoneNumber(isoCode: 'KE');
  String? _rawPhoneNumber;

  double _passwordStrength = 0.0;
  String _passwordStrengthLabel = '';
  Color _strengthColor = Colors.grey;

  void _checkPasswordStrength(String password) {
    double strength = 0;
    if (password.length >= 8) strength += 0.25;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength += 0.25;
    if (RegExp(r'[0-9]').hasMatch(password)) strength += 0.25;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) strength += 0.25;

    setState(() {
      _passwordStrength = strength;
      if (strength < 0.5) {
        _strengthColor = Colors.red;
        _passwordStrengthLabel = 'Weak ❌';
      } else if (strength < 0.75) {
        _strengthColor = Colors.orange;
        _passwordStrengthLabel = 'Medium ⚠️';
      } else {
        _strengthColor = Colors.green;
        _passwordStrengthLabel = 'Strong ✅';
      }
    });
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _profileImage = File(picked.path);
        _showImageError = false;
      });
    }
  }

  Future<void> _detectLocation() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) serviceEnabled = await _location.requestService();
    if (!serviceEnabled) return;

    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }

    final currentLocation = await _location.getLocation();
    setState(() {
      _locationController.text =
          'Lat: ${currentLocation.latitude}, Lng: ${currentLocation.longitude}';
    });
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_role == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your role')),
      );
      return;
    }

    if (_profileImage == null) {
      setState(() => _showImageError = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a profile picture')),
      );
      return;
    }

    try {
      setState(() => _isLoading = true);

      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;
      final storage = FirebaseStorage.instance;

      final result = await auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final uploadTask = await storage
          .ref('profiles/${result.user!.uid}.jpg')
          .putFile(_profileImage!);
      final imageUrl = await uploadTask.ref.getDownloadURL();

      await firestore.collection('users').doc(result.user!.uid).set({
        'fullName': _fullNameController.text.trim(),
        'username': _usernameController.text.trim(),
        'email': _emailController.text.trim(),
        'nationalId': _nationalIdController.text.trim(),
        'phone': _rawPhoneNumber,
        'location': _locationController.text.trim(),
        'role': _role,
        'profileImage': imageUrl,
        'createdAt': Timestamp.now(),
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => _role == 'Donor'
              ? const DonorDashboard()
              : const RecipientDashboard(),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade50,
      appBar: AppBar(
        title: const Text('Register'),
        centerTitle: true,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // ✅ Profile Image
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _showImageError ? Colors.red : Colors.green,
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.green.shade100,
                      backgroundImage: _profileImage != null
                          ? FileImage(_profileImage!)
                          : null,
                      child: _profileImage == null
                          ? const Icon(Icons.camera_alt, size: 40)
                          : null,
                    ),
                  ),
                ),
                if (_showImageError)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Profile image is required',
                      style: TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                const SizedBox(height: 16),

                // ✅ Role
                DropdownButtonFormField<String>(
                  value: _role,
                  items: const [
                    DropdownMenuItem(value: 'Donor', child: Text('Donor')),
                    DropdownMenuItem(value: 'Recipient', child: Text('Recipient')),
                  ],
                  onChanged: (value) => setState(() => _role = value),
                  decoration: const InputDecoration(
                    labelText: 'Select Role',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value == null ? 'Please select a role' : null,
                ),
                const SizedBox(height: 16),

                // ✅ Full Name
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value!.isEmpty ? 'Enter your full name' : null,
                ),
                const SizedBox(height: 16),

                // ✅ Username
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.account_circle),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value!.isEmpty ? 'Enter a username' : null,
                ),
                const SizedBox(height: 16),

                // ✅ Email
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) =>
                      value!.contains('@') ? null : 'Enter a valid email',
                ),
                const SizedBox(height: 16),

                // ✅ Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  onChanged: _checkPasswordStrength,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Min 8 chars, uppercase, number, symbol',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _showPassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                    ),
                  ),
                  validator: (value) {
                    final password = value ?? '';
                    if (password.length < 8) return 'Minimum 8 characters';
                    if (!RegExp(r'[A-Z]').hasMatch(password)) {
                      return 'Must contain uppercase';
                    }
                    if (!RegExp(r'[a-z]').hasMatch(password)) {
                      return 'Must contain lowercase';
                    }
                    if (!RegExp(r'[0-9]').hasMatch(password)) {
                      return 'Must contain number';
                    }
                    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) {
                      return 'Must contain special symbol';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _passwordStrength,
                  backgroundColor: Colors.grey.shade300,
                  color: _strengthColor,
                  minHeight: 6,
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Password Strength: $_passwordStrengthLabel',
                    style: TextStyle(color: _strengthColor),
                  ),
                ),
                const SizedBox(height: 16),

                // ✅ Confirm Password
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock_open_outlined),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _showPassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                    ),
                  ),
                  validator: (value) => value == _passwordController.text
                      ? null
                      : 'Passwords do not match',
                ),
                const SizedBox(height: 16),

                // ✅ National ID
                TextFormField(
                  controller: _nationalIdController,
                  decoration: const InputDecoration(
                    labelText: 'National ID',
                    prefixIcon: Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value!.isEmpty ? 'Enter your National ID' : null,
                ),
                const SizedBox(height: 16),

                // ✅ Phone Number (Intl input)
                InternationalPhoneNumberInput(
                  onInputChanged: (PhoneNumber number) {
                    _rawPhoneNumber = number.phoneNumber;
                  },
                  selectorConfig: const SelectorConfig(
                    selectorType: PhoneInputSelectorType.DROPDOWN,
                    showFlags: true,
                    setSelectorButtonAsPrefixIcon: true,
                  ),
                  initialValue: _phoneNumber,
                  textFieldController: _phoneController,
                  inputDecoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Phone number required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ✅ Location (with GPS button)
                TextFormField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    labelText: 'Location',
                    prefixIcon: IconButton(
                      icon: const Icon(Icons.my_location),
                      onPressed: _detectLocation,
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.location_searching),
                      tooltip: 'Use current location',
                      onPressed: _detectLocation,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value!.isEmpty ? 'Enter location or tap icon' : null,
                ),
                const SizedBox(height: 24),

                // ✅ Register Button
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _register,
                  icon: const Icon(Icons.person_add),
                  label: Text(_isLoading ? 'Registering...' : 'Register'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
