// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'edit_donor_profile_screen.dart';

class DonorProfileScreen extends StatefulWidget {
  const DonorProfileScreen({super.key});

  @override
  State<DonorProfileScreen> createState() => _DonorProfileScreenState();
}

class _DonorProfileScreenState extends State<DonorProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? _userData;
  int _donationCount = 0;
  bool _isLoading = true;

  Future<void> _loadProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final userDoc = await _firestore.collection('users').doc(uid).get();
    final donations = await _firestore
        .collection('donations')
        .where('donorId', isEqualTo: uid)
        .get();

    if (userDoc.exists) {
      setState(() {
        _userData = userDoc.data();
        _donationCount = donations.docs.length;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Account"),
        content: const Text("Are you sure you want to delete your account? This action is irreversible."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final uid = _auth.currentUser?.uid;
        await _firestore.collection('users').doc(uid).delete();
        await _auth.currentUser?.delete();
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst); // Go to login
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting account: $e')));
      }
    }
  }

  Future<void> _switchRole() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || _userData == null) return;

    String newRole = _userData!['role'] == 'Donor' ? 'Recipient' : 'Donor';

    await _firestore.collection('users').doc(uid).update({'role': newRole});
    await _loadProfile();

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Role switched to $newRole'),
      backgroundColor: Colors.green,
    ));
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Donor Profile'),
        backgroundColor: Colors.green[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const EditDonorProfileScreen(),
                ),
              ).then((_) => _loadProfile());
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userData == null
              ? const Center(child: Text("User data not found"))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: _userData!['profileImageUrl'] != null
                            ? NetworkImage(_userData!['profileImageUrl'])
                            : const AssetImage('assets/avatar_placeholder.png') as ImageProvider,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _userData!['fullName'] ?? '',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '@${_userData!['username'] ?? ''}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey),
                      ),
                      const SizedBox(height: 10),
                      Chip(
                        label: Text(
                          _userData!['role'] ?? 'Donor',
                          style: const TextStyle(color: Colors.white),
                        ),
                        backgroundColor: Colors.green,
                      ),
                      const Divider(height: 40),
                      ListTile(
                        leading: const Icon(Icons.phone, color: Colors.green),
                        title: const Text("Phone Number"),
                        subtitle: Text(_userData!['phoneNumber'] ?? ''),
                      ),
                      ListTile(
                        leading: const Icon(Icons.location_on, color: Colors.green),
                        title: const Text("Location"),
                        subtitle: Text(_userData!['location'] ?? ''),
                      ),
                      ListTile(
                        leading: const Icon(Icons.star, color: Colors.orange),
                        title: const Text("Total Donations"),
                        subtitle: Text("$_donationCount donations"),
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.sync_alt),
                        label: const Text("Switch Role"),
                        onPressed: _switchRole,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                        label: const Text("Delete Account", style: TextStyle(color: Colors.red)),
                        onPressed: _deleteAccount,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
