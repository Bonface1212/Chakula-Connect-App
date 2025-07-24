import 'dart:io';
import 'dart:typed_data';
import 'package:chakula_connect/theme/brand_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

class CreateDonationScreen extends StatefulWidget {
  const CreateDonationScreen({super.key});

  @override
  State<CreateDonationScreen> createState() => _CreateDonationScreenState();
}

class _CreateDonationScreenState extends State<CreateDonationScreen> {
  final _formKey = GlobalKey<FormState>();
  String _foodName = '';
  String _expiryDate = '';
  String _pickupPoint = '';
  String _message = '';
  File? _image;
  bool _isLoading = false;
  bool _isGettingLocation = false;

  final picker = ImagePicker();
  late Position _donorLocation;

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _donorLocation = position;
      setState(() {
        _pickupPoint =
            '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to get location")),
      );
    }
    setState(() => _isGettingLocation = false);
  }

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _image = File(pickedFile.path));
    }
  }

  Future<String> _uploadImage(String donationId) async {
    final ref = FirebaseStorage.instance
        .ref()
        .child('donation_images')
        .child('$donationId.jpg');

    Uint8List? compressedBytes;

    if (kIsWeb) {
      final originalBytes = await _image!.readAsBytes();
      compressedBytes = await FlutterImageCompress.compressWithList(
        originalBytes,
        minWidth: 800,
        minHeight: 800,
        quality: 60,
      );

      final uploadTask = ref.putData(
        compressedBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } else {
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        _image!.path,
        '${_image!.path}_compressed.jpg',
        quality: 60,
      );
      final uploadTask = ref.putFile(File(compressedFile!.path));
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields & pick an image")),
      );
      return;
    }

    _formKey.currentState!.save();

    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final donationRef =
          FirebaseFirestore.instance.collection('donations').doc();

      final imageUrl = await _uploadImage(donationRef.id);

      await donationRef.set({
        'donationId': donationRef.id,
        'foodName': _foodName,
        'expiryDate': _expiryDate,
        'pickupPoint': _pickupPoint,
        'message': _message,
        'donorId': currentUser!.uid,
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'available',
        'location': GeoPoint(
          _donorLocation.latitude,
          _donorLocation.longitude,
        ),
      });

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Donation posted successfully!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error posting donation: $e")),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  Widget build(BuildContext context) {
    final inputStyle = InputDecoration(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.grey.shade100,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Donation"),
        backgroundColor: ChakulaColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_isGettingLocation)
              const LinearProgressIndicator(minHeight: 3),
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    decoration: inputStyle.copyWith(labelText: "Food Name"),
                    validator: (value) =>
                        value!.isEmpty ? "Enter food name" : null,
                    onSaved: (value) => _foodName = value!.trim(),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: inputStyle.copyWith(
                      labelText: "Expiry Date (e.g. 2025-07-28)",
                    ),
                    onTap: () async {
                      FocusScope.of(context).requestFocus(FocusNode());
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (picked != null) {
                        setState(() {
                          _expiryDate = DateFormat('yyyy-MM-dd').format(picked);
                        });
                      }
                    },
                    readOnly: true,
                    validator: (value) =>
                        _expiryDate.isEmpty ? "Pick an expiry date" : null,
                    controller: TextEditingController(text: _expiryDate),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: inputStyle.copyWith(labelText: "Pickup Point"),
                    initialValue: _pickupPoint,
                    validator: (value) =>
                        value!.isEmpty ? "Enter pickup point" : null,
                    onSaved: (value) => _pickupPoint = value!.trim(),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration:
                        inputStyle.copyWith(labelText: "Message to Recipients"),
                    maxLines: 3,
                    onSaved: (value) => _message = value!.trim(),
                  ),
                  const SizedBox(height: 12),
                  _image != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: kIsWeb
                              ? Image.network(_image!.path, height: 180)
                              : Image.file(_image!, height: 180),
                        )
                      : const Text("No image selected"),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo),
                    label: const Text("Select Image"),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _submit,
                    icon: _isLoading
                        ? const CircularProgressIndicator()
                        : const Icon(Icons.send),
                    label: Text(_isLoading ? "Posting..." : "Post Donation"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ChakulaColors.primary,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 12.0),
                      child: Text("Uploading image and posting...",
                          style: TextStyle(color: Colors.grey)),
                    )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
