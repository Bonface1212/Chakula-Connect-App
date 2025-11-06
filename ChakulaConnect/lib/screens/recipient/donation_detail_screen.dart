// lib/screens/recipient/donation_detail_screen.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DonationDetailScreen extends StatelessWidget {
  final Map<String, dynamic> data;

  const DonationDetailScreen({super.key, required this.data});

  Future<void> _claimFood(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in first.")),
      );
      return;
    }

    final userId = user.uid;
    final firestore = FirebaseFirestore.instance;

    final donationId = data['id'];
    final donationRef = firestore.collection('donations').doc(donationId);
    final claimRef = firestore.collection('claims').doc();

    try {
      await firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(donationRef);

        if (!snapshot.exists) {
          throw Exception("Donation not found.");
        }

        final donationData = snapshot.data()!;
        final currentStatus = donationData['status'] ?? 'Available';

        if (currentStatus != 'Available') {
          throw Exception("This food has already been claimed.");
        }

        // ✅ Update donation document as allowed by your Firestore rules
        transaction.update(donationRef, {
          'status': 'claimed',
          'claimerId': userId,
        });

        // ✅ Create claim document
        transaction.set(claimRef, {
          'recipientId': userId,
          'donationId': donationId,
          'donorId': donationData['donorId'],
          'foodName': donationData['foodName'],
          'imageUrl': donationData['imageUrl'],
          'pickupPoint': donationData['pickupPoint'],
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'claimed',
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🎉 Food claimed successfully!"),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      print("❌ Error claiming food: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error claiming food: ${e.toString()}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const chakulaGreen = Color(0xFF66B347);
    const chakulaOrange = Color(0xFFFF6A13);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Details'),
        backgroundColor: chakulaGreen,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          Image.network(
            data['imageUrl'] ?? '',
            height: 450,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 450,
              color: Colors.grey[300],
              child: const Icon(Icons.broken_image, size: 60),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['foodName'] ?? 'Unnamed Food',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.category, size: 18),
                    const SizedBox(width: 6),
                    Text(data['category'] ?? 'Other'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 18),
                    const SizedBox(width: 6),
                    Text(data['pickupPoint'] ?? 'Unknown'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 18),
                    const SizedBox(width: 6),
                    Text("Expires: ${data['expiryDate'] ?? data['expiry'] ?? 'N/A'}"),
                  ],
                ),
                if (data['message'] != null && data['message'].toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    data['message'],
                    style: const TextStyle(color: Colors.black87, fontSize: 16),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text(
                      "Claim Food",
                      style: TextStyle(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: chakulaOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _claimFood(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
