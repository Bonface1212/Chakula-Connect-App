import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

class UploadTestScreen extends StatefulWidget {
  const UploadTestScreen({super.key});

  @override
  State<UploadTestScreen> createState() => _UploadTestScreenState();
}

class _UploadTestScreenState extends State<UploadTestScreen> {
  File? _selectedImage;
  Uint8List? _webImageData;
  String? _imageUrl;
  bool _uploading = false;

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

  Future<void> _uploadImage() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Not authenticated')),
      );
      return;
    }

    if (_webImageData == null && _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ No image selected')),
      );
      return;
    }

    try {
      setState(() => _uploading = true);
      final storage = FirebaseStorage.instance;
      final String fileId = const Uuid().v4();
      final ref = storage.ref().child('test_uploads/$fileId.jpg');

      UploadTask uploadTask;
      if (kIsWeb && _webImageData != null) {
        uploadTask = ref.putData(_webImageData!);
      } else {
        uploadTask = ref.putFile(_selectedImage!);
      }

      final snapshot = await uploadTask;
      final url = await snapshot.ref.getDownloadURL();

      setState(() => _imageUrl = url);
    } catch (e) {
      debugPrint('❌ Upload error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      setState(() => _uploading = false);
    }
  }

  Widget _buildPreview() {
    if (_webImageData != null) {
      return Image.memory(_webImageData!, height: 200, fit: BoxFit.cover);
    } else if (_selectedImage != null) {
      return Image.file(_selectedImage!, height: 200, fit: BoxFit.cover);
    } else {
      return const Text('No image selected');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Upload Test'),
        backgroundColor: Colors.green[700],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo),
              label: const Text('Pick Image'),
            ),
            const SizedBox(height: 20),
            _buildPreview(),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _uploading ? null : _uploadImage,
              icon: const Icon(Icons.cloud_upload),
              label: Text(_uploading ? 'Uploading...' : 'Upload to Firebase'),
            ),
            const SizedBox(height: 20),
            if (_imageUrl != null) ...[
              const Text('✅ Upload successful! URL:'),
              SelectableText(_imageUrl!),
            ],
          ],
        ),
      ),
    );
  }
}
