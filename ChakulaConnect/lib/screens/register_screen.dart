// ignore_for_file: use_build_context_synchronously, unused_field, avoid_print
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart'; // Reverse geocoding

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _licenseController = TextEditingController();
  final _locationController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Mobile file
  File? _profileImageFile;
  File? _idImageFile;

  // Web bytes
  Uint8List? _profileImageBytes;
  Uint8List? _idImageBytes;

  String? _role = 'Donor';
  String? _phone;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _agreedToTerms = false;
  bool _isLoading = false;

  LatLng? _selectedLatLng; // Actual coordinates
  String? _selectedAddress; // Human-readable address

  // --- OTP / Phone verification state (added) ---
  String _verificationId = '';
  bool _isOTPSent = false;
  bool _isVerifying = false;
  bool _isPhoneVerified = false;
  // ------------------------------------------------

  // Image picker
  Future<void> _pickImage({bool isIdPhoto = false}) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        setState(() {
          if (isIdPhoto) _idImageBytes = bytes;
          else _profileImageBytes = bytes;
        });
      } else {
        setState(() {
          if (isIdPhoto) _idImageFile = File(picked.path);
          else _profileImageFile = File(picked.path);
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No image selected")),
      );
    }
  }

  // Firebase uploads
  Future<String> _uploadToFirebase(File file, String path) async {
    final ref = FirebaseStorage.instance.ref().child(path);
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  Future<String> _uploadToFirebaseWeb(Uint8List bytes, String path) async {
    final ref = FirebaseStorage.instance.ref().child(path);
    await ref.putData(bytes);
    return await ref.getDownloadURL();
  }

  // Auto-detect location
  Future<void> _autoDetectLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enable location services.')),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    _selectedLatLng = LatLng(position.latitude, position.longitude);
    _selectedAddress = await _getAddressFromLatLng(_selectedLatLng!);

    setState(() {
      _locationController.text = _selectedAddress!;
    });
  }

  // Reverse geocoding
  Future<String> _getAddressFromLatLng(LatLng position) async {
    List<Placemark> placemarks =
    await placemarkFromCoordinates(position.latitude, position.longitude);
    if (placemarks.isNotEmpty) {
      final place = placemarks.first;
      return "${place.name}, ${place.locality}, ${place.subAdministrativeArea}";
    }
    return "${position.latitude}, ${position.longitude}";
  }

  // Select on map
  Future<void> _selectOnMap() async {
    final LatLng? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          initialLocation: _selectedLatLng ?? LatLng(-1.2921, 36.8219),
        ),
      ),
    );

    if (result != null) {
      _selectedLatLng = result;
      _selectedAddress = await _getAddressFromLatLng(result);

      setState(() {
        _locationController.text = _selectedAddress!;
      });
    }
  }

  // --- OTP: send SMS ----
  Future<void> sendOTP() async {
    if (_phone == null || _phone!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid phone number first")),
      );
      return;
    }

    setState(() {
      _isVerifying = true;
      _isOTPSent = false;
      _isPhoneVerified = false;
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _phone!,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-retrieval or instant validation on some devices
          // We'll try to sign in then delete the temp phone user to only use verification.
          try {
            final uc = await FirebaseAuth.instance.signInWithCredential(credential);
            // Delete the temporary phone user right away to avoid leaving orphan accounts.
            await uc.user?.delete();
            setState(() {
              _isPhoneVerified = true;
              _isOTPSent = true;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Phone auto-verified")),
            );
          } catch (e) {
            // ignore errors here; user can still enter code manually
          } finally {
            setState(() => _isVerifying = false);
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() => _isVerifying = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message ?? "OTP verification failed")),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _isOTPSent = true;
            _isVerifying = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("OTP sent")),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      setState(() => _isVerifying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error sending OTP: $e")),
      );
    }
  }

  // --- OTP: verify code entered by user ---
  Future<void> verifyOTP(String smsCode) async {
    if (_verificationId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No verification in progress")),
      );
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: smsCode,
      );

      // Sign in with the credential to validate the code, then delete the temporary phone user.
      final uc = await FirebaseAuth.instance.signInWithCredential(credential);

      // Delete temporary phone-only auth user so they don't remain in Firebase Auth.
      await uc.user?.delete();

      setState(() {
        _isPhoneVerified = true;
        _isVerifying = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Phone verified successfully")),
      );
    } catch (e) {
      setState(() => _isVerifying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid or expired OTP")),
      );
    }
  }

  Future<void> _register() async {
    // Require phone verification before allowing registration
    if (!_isPhoneVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please verify your phone number first (send and confirm OTP)")),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please agree to the Terms and Conditions")),
      );
      return;
    }

    if ((kIsWeb && _profileImageBytes == null) || (!kIsWeb && _profileImageFile == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please upload a Profile image")),
      );
      return;
    }

    if (_role == 'Rider' &&
        ((kIsWeb && _idImageBytes == null) || (!kIsWeb && _idImageFile == null))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please upload your ID image")),
      );
      return;
    }

    if (_selectedLatLng == null || _selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select your location")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      String profileUrl = kIsWeb
          ? await _uploadToFirebaseWeb(_profileImageBytes!, "users/${cred.user!.uid}/profile.jpg")
          : await _uploadToFirebase(_profileImageFile!, "users/${cred.user!.uid}/profile.jpg");

      String? idUrl;
      if (_role == 'Rider') {
        idUrl = kIsWeb
            ? await _uploadToFirebaseWeb(_idImageBytes!, "users/${cred.user!.uid}/id.jpg")
            : await _uploadToFirebase(_idImageFile!, "users/${cred.user!.uid}/id.jpg");
      }

      await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
        'uid': cred.user!.uid,
        'fullName': _fullNameController.text.trim(),
        'username': _usernameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phone,
        'role': _role,
        'nationalId': _nationalIdController.text.trim(),
        'driverLicense': _role == 'Rider' ? _licenseController.text.trim() : null,
        'location': _selectedAddress,
        'lat': _selectedLatLng?.latitude,
        'lng': _selectedLatLng?.longitude,
        'profileImageUrl': profileUrl,
        'idImageUrl': idUrl,
        'createdAt': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Registration successful!")),
      );

      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Profile Image
                GestureDetector(
                  onTap: () => _pickImage(),
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.green,
                    child: kIsWeb
                        ? (_profileImageBytes != null
                        ? ClipOval(
                      child: Image.memory(
                        _profileImageBytes!,
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    )
                        : const Icon(Icons.camera_alt, size: 40, color: Colors.white))
                        : (_profileImageFile != null
                        ? ClipOval(
                      child: Image.file(
                        _profileImageFile!,
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    )
                        : const Icon(Icons.camera_alt, size: 40, color: Colors.white)),
                  ),
                ),
                if ((kIsWeb && _profileImageBytes != null) || (!kIsWeb && _profileImageFile != null))
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text(
                      "Profile photo selected ✅",
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
                    ),
                  ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: _role,
                  items: const [
                    DropdownMenuItem(value: 'Donor', child: Text('Donor')),
                    DropdownMenuItem(value: 'Recipient', child: Text('Recipient')),
                    DropdownMenuItem(value: 'Rider', child: Text('Rider')),
                  ],
                  onChanged: (val) => setState(() => _role = val),
                  decoration: const InputDecoration(
                    labelText: 'Select Role',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => val!.isEmpty ? 'Enter full name' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.account_circle),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => val!.isEmpty ? 'Enter username' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => val!.isEmpty ? 'Enter email' : null,
                ),
                const SizedBox(height: 16),

                IntlPhoneField(
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  initialCountryCode: 'KE',
                  disableLengthCheck: true,
                  onChanged: (phone) {
                    String raw = phone.number;

                    // Remove leading zero (e.g., 07 → 7, 01 → 1)
                    if (raw.startsWith('0')) {
                      raw = raw.substring(1);
                    }

                    // Final stored phone number: +254XXXXXXXXX
                    _phone = "+254$raw";

                    // If user changed phone after verification, reset verification
                    if (_isPhoneVerified) {
                      setState(() {
                        _isPhoneVerified = false;
                        _isOTPSent = false;
                        _verificationId = '';
                      });
                    }
                  },
                  validator: (phone) {
                    if (phone == null || phone.number.isEmpty) {
                      return 'Enter phone number';
                    }

                    String raw = phone.number;

                    if (raw.startsWith('0')) {
                      raw = raw.substring(1); // remove leading zero
                    }

                    // Accept: 7XXXXXXXX or 1XXXXXXXX (Safaricom/Airtel/Telkom new prefixes)
                    if (!RegExp(r'^(7|1)\d{8}$').hasMatch(raw)) {
                      return 'Format must be +2547XXXXXXXX or +2541XXXXXXXX';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 8),

                // Send OTP / OTP input UI (added)
                if (!_isOTPSent) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: _isVerifying ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
                          label: Text(_isVerifying ? "Sending..." : "Send OTP"),
                          onPressed: _isVerifying
                              ? null
                              : () {
                            // validate phone input before sending OTP
                            final valid = _formKey.currentState?.validate() ?? false;
                            if (!valid) {
                              // show inline error (the IntlPhoneField validator will show)
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Please enter a valid phone number")),
                              );
                              return;
                            }
                            sendOTP();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 44),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  TextField(
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: "Enter OTP",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      if (value.length == 6) {
                        verifyOTP(value);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isVerifying ? null : () {
                            // manual verify will be handled by the onChanged above (auto) or user can press this after entering code
                          },
                          child: _isVerifying
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : Text(_isPhoneVerified ? "Verified ✓" : "Verify OTP"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isPhoneVerified ? Colors.grey : Colors.green,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 44),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _isVerifying ? null : sendOTP,
                        child: const Text("Resend"),
                      )
                    ],
                  ),
                ],

                const SizedBox(height: 16),

                TextFormField(
                  controller: _nationalIdController,
                  decoration: const InputDecoration(
                    labelText: 'National ID',
                    prefixIcon: Icon(Icons.credit_card),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Enter National ID';
                    if (val.length != 8) return 'National ID must be 8 digits';
                    if (!RegExp(r'^\d+$').hasMatch(val)) return 'National ID must be numeric';
                    return null;
                  },
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                ),
                const SizedBox(height: 16),

                if (_role == 'Rider') ...[
                  TextFormField(
                    controller: _licenseController,
                    decoration: const InputDecoration(
                      labelText: 'Driver’s License',
                      prefixIcon: Icon(Icons.badge),
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Enter license number';
                      if (val.length != 7) return 'License number must be 7 characters';
                      return null;
                    },
                    maxLength: 7,
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton.icon(
                    onPressed: () => _pickImage(isIdPhoto: true),
                    icon: const Icon(Icons.photo_camera_back),
                    label: Text(_idImageBytes != null || _idImageFile != null
                        ? "ID Photo Selected ✅"
                        : "Upload ID Photo"),
                  ),
                  if ((kIsWeb && _idImageBytes != null) || (!kIsWeb && _idImageFile != null))
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text(
                        "ID photo selected ✅",
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],

                // Location Field with auto-detect and map picker
                TextFormField(
                  controller: _locationController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Location / Landmark',
                    prefixIcon: const Icon(Icons.location_on),
                    border: const OutlineInputBorder(),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.my_location),
                          onPressed: _autoDetectLocation,
                        ),
                        IconButton(
                          icon: const Icon(Icons.map),
                          onPressed: _selectOnMap,
                        ),
                      ],
                    ),
                  ),
                  validator: (val) => val!.isEmpty ? 'Enter location' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                    ),
                  ),
                  validator: (val) => val!.length < 6 ? 'Password too short' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: !_isConfirmPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                    ),
                  ),
                  validator: (val) => val != _passwordController.text ? 'Passwords do not match' : null,
                ),
                const SizedBox(height: 16),

                CheckboxListTile(
                  value: _agreedToTerms,
                  onChanged: (val) => setState(() => _agreedToTerms = val!),
                  title: const Text("I agree to the Terms and Conditions"),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 16),

                ElevatedButton.icon(
                  icon: const Icon(Icons.app_registration),
                  label: Text(_isLoading ? "Registering..." : "Register"),
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  child: const Text("Already have an account? Login"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Map Picker Screen
class MapPickerScreen extends StatefulWidget {
  final LatLng initialLocation;
  const MapPickerScreen({super.key, required this.initialLocation});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  LatLng? _pickedLocation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pick a location')),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: widget.initialLocation,
          zoom: 16,
        ),
        onTap: (latLng) {
          setState(() => _pickedLocation = latLng);
        },
        markers: _pickedLocation != null
            ? {Marker(markerId: const MarkerId('picked'), position: _pickedLocation!)}
            : {},
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.check),
        onPressed: () => Navigator.pop(context, _pickedLocation),
      ),
    );
  }
}
