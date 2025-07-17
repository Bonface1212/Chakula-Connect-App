// ignore_for_file: unused_element, unused_field

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
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

  File? _profileImageFile;
  Uint8List? _webImageData;

  String? _role;
  bool _isLoading = false;
  final bool _showPassword = false;
  bool _showImageError = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _locationController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();

  final PhoneNumber _phoneNumber = PhoneNumber(isoCode: 'KE');
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
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _webImageData = bytes;
          _profileImageFile = null;
          _showImageError = false;
        });
      } else {
        setState(() {
          _profileImageFile = File(picked.path);
          _webImageData = null;
          _showImageError = false;
        });
      }
    }
  }

  Future<void> _detectLocation() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return;
    }

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select your role')),
        );
      }
      return;
    }

    if (_profileImageFile == null && _webImageData == null) {
      setState(() => _showImageError = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please upload a profile picture')),
        );
      }
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

      final imageRef = storage.ref('profiles/${result.user!.uid}.jpg');
      UploadTask uploadTask = kIsWeb
          ? imageRef.putData(_webImageData!)
          : imageRef.putFile(_profileImageFile!);

      final imageUrl = await (await uploadTask).ref.getDownloadURL();

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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎉 Registered successfully!')),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              _role == 'Donor' ? const DonorDashboard() : const RecipientDashboard(),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildProfileImage() {
    ImageProvider? image;
    if (_webImageData != null) {
      image = MemoryImage(_webImageData!);
    } else if (_profileImageFile != null) {
      image = FileImage(_profileImageFile!);
    }

    return GestureDetector(
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
          backgroundImage: image,
          child: image == null ? const Icon(Icons.camera_alt, size: 40) : null,
        ),
      ),
    );
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
                _buildProfileImage(),
                if (_showImageError)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Profile image is required',
                      style: TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                const SizedBox(height: 16),
                // Remaining form fields go here...
              ],
            ),
          ),
        ),
      ),
    );
  }
}
