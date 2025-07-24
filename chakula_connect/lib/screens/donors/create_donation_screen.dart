// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class CreateDonationScreen extends StatefulWidget {
  const CreateDonationScreen({super.key});

  @override
  State<CreateDonationScreen> createState() => _CreateDonationScreenState();
}

class _CreateDonationScreenState extends State<CreateDonationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _foodNameController = TextEditingController();
  final _expiryDateController = TextEditingController();
  final _pickupPointController = TextEditingController();
  final _messageController = TextEditingController();

  File? _selectedImage;
  Uint8List? _webImageData;
  UploadTask? _uploadTask;
  bool _isPosting = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        setState(() => _webImageData = bytes);
      } else {
        setState(() => _selectedImage = File(picked.path));
      }
    }
  }

  Future<String?> _uploadImage() async {
    final fileName = const Uuid().v4();
    final ref = FirebaseStorage.instance.ref('donation_images/$fileName.jpg');

    if (kIsWeb && _webImageData != null) {
      _uploadTask = ref.putData(_webImageData!);
    } else if (_selectedImage != null) {
      _uploadTask = ref.putFile(_selectedImage!);
    } else {
      return null;
    }

    final snapshot = await _uploadTask!.whenComplete(() {});
    return await snapshot.ref.getDownloadURL();
  }

  Future<void> _submitDonation() async {
    if (!_formKey.currentState!.validate() ||
        (_selectedImage == null && _webImageData == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill all fields and upload an image')),
      );
      return;
    }

    setState(() => _isPosting = true);

    try {
      final imageUrl = await _uploadImage();

      final data = {
        'foodName': _foodNameController.text.trim(),
        'expiryDate': _expiryDateController.text.trim(),
        'pickupPoint': _pickupPointController.text.trim(),
        'message': _messageController.text.trim(),
        'imageUrl': imageUrl,
        'createdAt': Timestamp.now(),
      };

      await FirebaseFirestore.instance.collection('donations').add(data);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Donation posted successfully!')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isPosting = false);
    }
  }

  Widget _buildImagePreview() {
    if (kIsWeb && _webImageData != null) {
      return Image.memory(_webImageData!, height: 200, fit: BoxFit.cover);
    } else if (_selectedImage != null) {
      return Image.file(_selectedImage!, height: 200, fit: BoxFit.cover);
    } else {
      return GestureDetector(
        onTap: _pickImage,
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Icon(Icons.camera_alt, size: 50, color: Colors.grey),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Post a Donation"),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildImagePreview(),
              const SizedBox(height: 20),
              TextFormField(
                controller: _foodNameController,
                decoration: const InputDecoration(
                  labelText: 'Food Name',
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    val!.isEmpty ? 'Food name is required' : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _expiryDateController,
                decoration: const InputDecoration(
                  labelText: 'Expiry Date (e.g. 2025-08-10)',
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    val!.isEmpty ? 'Expiry date is required' : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _pickupPointController,
                decoration: const InputDecoration(
                  labelText: 'Pickup Point',
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    val!.isEmpty ? 'Pickup point is required' : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: 'Message (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 25),
              _isPosting
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _submitDonation,
                        icon: const Icon(Icons.check),
                        label: const Text("Post Donation"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
