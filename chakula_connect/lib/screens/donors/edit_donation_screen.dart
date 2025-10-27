// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
// ignore: depend_on_referenced_packages
import 'package:uuid/uuid.dart';

class EditDonationScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const EditDonationScreen({super.key, required this.docId, required this.data, required String donationId});

  @override
  State<EditDonationScreen> createState() => _EditDonationScreenState();
}

class _EditDonationScreenState extends State<EditDonationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _foodNameController = TextEditingController();
  final _expiryDateController = TextEditingController();
  final _pickupPointController = TextEditingController();
  final _messageController = TextEditingController();

  File? _selectedImage;
  Uint8List? _webImageData;
  String? _selectedCategory;
  bool _isUpdating = false;

  final List<String> _categories = ['Cooked', 'Uncooked', 'Snacks', 'Beverages', 'Other'];

  @override
  void initState() {
    super.initState();
    _foodNameController.text = widget.data['foodName'] ?? '';
    _expiryDateController.text = widget.data['expiryDate'] ?? '';
    _pickupPointController.text = widget.data['pickupPoint'] ?? '';
    _messageController.text = widget.data['message'] ?? '';
    _selectedCategory = widget.data['category'] ?? 'Other';
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        setState(() => _webImageData = bytes);
      } else {
        setState(() => _selectedImage = File(picked.path));
      }
    }
  }

  Future<void> _pickExpiryDate() async {
    DateTime? date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: DateTime.now(),
    );
    if (date != null) {
      _expiryDateController.text =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    }
  }

  Future<String?> _uploadImageToFirebaseStorage() async {
    try {
      final storage = FirebaseStorage.instance;
      final String fileId = const Uuid().v4();

      final ref = storage.ref().child('donation_images/$fileId.jpg');

      if (kIsWeb && _webImageData != null) {
        await ref.putData(_webImageData!);
        return await ref.getDownloadURL();
      } else if (_selectedImage != null) {
        await ref.putFile(_selectedImage!);
        return await ref.getDownloadURL();
      }
    } catch (e) {
      debugPrint('Image upload failed: $e');
    }
    return null;
  }

  Future<void> _updateDonation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUpdating = true);

    try {
      String imageUrl = widget.data['imageUrl'];
      final newImageUrl = await _uploadImageToFirebaseStorage();
      if (newImageUrl != null) imageUrl = newImageUrl;

      final updatedData = {
        'foodName': _foodNameController.text.trim(),
        'expiryDate': _expiryDateController.text.trim(),
        'pickupPoint': _pickupPointController.text.trim(),
        'message': _messageController.text.trim(),
        'category': _selectedCategory ?? 'Other',
        'imageUrl': imageUrl,
        'updatedAt': Timestamp.now(),
      };

      await FirebaseFirestore.instance.collection('donations').doc(widget.docId).update(updatedData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Donation updated successfully')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update error: $e')));
    } finally {
      setState(() => _isUpdating = false);
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
            image: DecorationImage(
              image: NetworkImage(widget.data['imageUrl'] ?? ''),
              fit: BoxFit.cover,
            ),
          ),
          child: const Align(
            alignment: Alignment.center,
            child: Icon(Icons.camera_alt, size: 50, color: Colors.white70),
          ),
        ),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Donation"),
        content: const Text("Are you sure you want to delete this donation?"),
        actions: [
          TextButton(child: const Text("Cancel"), onPressed: () => Navigator.pop(context, false)),
          TextButton(child: const Text("Delete"), onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );
    if (confirmed == true) {
      await FirebaseFirestore.instance.collection('donations').doc(widget.docId).delete();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Donation"),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _confirmDelete,
            icon: const Icon(Icons.delete),
            tooltip: "Delete Donation",
          )
        ],
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
                decoration: const InputDecoration(labelText: 'Food Name', border: OutlineInputBorder()),
                validator: (val) => val!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 15),
              GestureDetector(
                onTap: _pickExpiryDate,
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: _expiryDateController,
                    decoration: const InputDecoration(
                      labelText: 'Expiry Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    validator: (val) => val!.isEmpty ? 'Required' : null,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) => setState(() => _selectedCategory = val),
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _pickupPointController,
                decoration: const InputDecoration(labelText: 'Pickup Point', border: OutlineInputBorder()),
                validator: (val) => val!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _messageController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Message (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 25),
              _isUpdating
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.save),
                        label: const Text("Update Donation"),
                        onPressed: _updateDonation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
