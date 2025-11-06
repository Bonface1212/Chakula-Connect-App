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
  bool _actionInProgress = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      final userDoc = await _firestore.collection('users').doc(uid).get();

      // Use count() aggregation to get donation count efficiently
      final donationsSnap = await _firestore
          .collection('donations')
          .where('donorId', isEqualTo: uid)
          .count()
          .get();

      if (userDoc.exists) {
        setState(() {
          _userData = userDoc.data();
          _donationCount = donationsSnap.count?? 0;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Account"),
        content: const Text(
            "Are you sure you want to delete your account? This action is irreversible."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
              const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _actionInProgress = true);
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Delete Auth user first (may require reauth)
      await user.delete();

      // Then delete Firestore doc
      await _firestore.collection('users').doc(user.uid).delete();

      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting account: $e')));
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _switchRole() async {
    if (_userData == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Switch Role"),
        content: Text(
            "Do you want to switch your role to ${_userData!['role'] == 'Donor' ? 'Recipient' : 'Donor'}?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Switch", style: TextStyle(color: Colors.green))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _actionInProgress = true);
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      final newRole = _userData!['role'] == 'Donor' ? 'Recipient' : 'Donor';
      await _firestore.collection('users').doc(uid).update({'role': newRole});
      await _loadProfile();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Role switched to $newRole'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Donor Profile'),
        backgroundColor: Colors.green[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Profile',
            onPressed: () async {
              final updated = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const EditDonorProfileScreen()),
              );
              if (updated == true) _loadProfile();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userData == null
          ? const Center(child: Text("User data not found"))
          : RefreshIndicator(
        onRefresh: _loadProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              CircleAvatar(
                radius: 50,
                child: ClipOval(
                  child: _userData!['profileImageUrl'] != null
                      ? Image.network(
                    _userData!['profileImageUrl'],
                    fit: BoxFit.cover,
                    width: 100,
                    height: 100,
                  )
                      : Image.asset(
                    'assets/avatar_placeholder.png',
                    width: 100,
                    height: 100,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _userData!['fullName'] ?? '',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                '@${_userData!['username'] ?? ''}',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Colors.grey),
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
                label: _actionInProgress
                    ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Text("Switch Role"),
                onPressed: _actionInProgress ? null : _switchRole,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                label: _actionInProgress
                    ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text("Delete Account",
                    style: TextStyle(color: Colors.red)),
                onPressed: _actionInProgress ? null : _deleteAccount,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
