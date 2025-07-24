import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class CreateDonationScreen extends StatefulWidget {
  const CreateDonationScreen({super.key});

  @override
  State<CreateDonationScreen> createState() => _CreateDonationScreenState();
}

class _CreateDonationScreenState extends State<CreateDonationScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  String? _foodName;
  String? _expiryDate;
  String? _message;
  String? _pickupPoint;
  XFile? _image;
  bool _isLoading = false;
  bool _isGettingLocation = false;

  Future<void> _getLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final placemarks = await placemarkFromCoordinates(
          position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          _pickupPoint =
              '${place.name}, ${place.street}, ${place.locality}, ${place.country}';
        });
      }
    } catch (e) {
      debugPrint("Location Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to detect location")),
      );
    } finally {
      setState(() => _isGettingLocation = false);
    }
  }

  Future<void> _pickImage() async {
    final pickedImage =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedImage != null) {
      setState(() {
        _image = pickedImage;
      });
    }
  }

  Future<String> _uploadImage(String donationId) async {
    final ref = FirebaseStorage.instance
        .ref()
        .child('donation_images')
        .child('$donationId.jpg');

    UploadTask uploadTask;

    if (kIsWeb) {
      final bytes = await _image!.readAsBytes();
      uploadTask = ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    } else {
      uploadTask = ref.putFile(File(_image!.path));
    }

    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _image == null) return;
    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final donationId = const Uuid().v4();
      final imageUrl = await _uploadImage(donationId);

      final donationData = {
        'id': donationId,
        'donorId': user.uid,
        'foodName': _foodName,
        'expiryDate': _expiryDate,
        'message': _message,
        'pickupPoint': _pickupPoint,
        'imageUrl': imageUrl,
        'timestamp': Timestamp.now(),
      };

      await FirebaseFirestore.instance
          .collection('donations')
          .doc(donationId)
          .set(donationData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Donation posted successfully')),
      );

      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Submission Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to post donation')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Donation')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_image != null)
              Image.network(
                kIsWeb ? _image!.path : File(_image!.path).path,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image),
              label: const Text('Pick Image'),
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Food Name'),
                    validator: (val) => val!.isEmpty ? "Required" : null,
                    onSaved: (val) => _foodName = val,
                  ),
                  TextFormField(
                    decoration:
                        const InputDecoration(labelText: 'Expiry Date (e.g. 2025-08-01)'),
                    validator: (val) => val!.isEmpty ? "Required" : null,
                    onSaved: (val) => _expiryDate = val,
                  ),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Message'),
                    maxLines: 3,
                    validator: (val) => val!.isEmpty ? "Required" : null,
                    onSaved: (val) => _message = val,
                  ),
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Pickup Point',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.my_location),
                        onPressed: _isGettingLocation ? null : _getLocation,
                      ),
                    ),
                    controller: TextEditingController(text: _pickupPoint),
                    validator: (val) => val == null || val.isEmpty ? "Required" : null,
                    onChanged: (val) => _pickupPoint = val,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _submit,
              icon: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_isLoading ? 'Posting...' : 'Post Donation'),
            ),
          ],
        ),
      ),
    );
  }
}
