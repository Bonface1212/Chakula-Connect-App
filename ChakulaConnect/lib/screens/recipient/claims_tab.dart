// lib/screens/recipient/claims_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ChakulaConnect/screens/recipient/claim_detail_screen.dart';

final claimStreamProvider = StreamProvider.autoDispose((ref) {
  final userId = FirebaseAuth.instance.currentUser?.uid;

  if (userId == null) {
    return const Stream.empty();
  }

  // Removed .orderBy() to prevent Firestore error with mixed types.
  return FirebaseFirestore.instance
      .collection('claims')
      .where('recipientId', isEqualTo: userId)
      .snapshots();
});

class ClaimsTab extends ConsumerWidget {
  const ClaimsTab({super.key});

  bool _isExpired(dynamic expiryDate) {
    if (expiryDate == null) return false;

    DateTime? expiry;
    if (expiryDate is Timestamp) {
      expiry = expiryDate.toDate();
    } else if (expiryDate is String) {
      expiry = DateTime.tryParse(expiryDate);
    }

    if (expiry == null) return false;

    final now = DateTime.now();
    final expiryDateOnly = DateTime(expiry.year, expiry.month, expiry.day);
    final todayDateOnly = DateTime(now.year, now.month, now.day);

    return expiryDateOnly.isBefore(todayDateOnly);
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'claimed':
        return 'Waiting for rider';
      case 'accepted':
        return 'Rider enroute to donor';
      case 'enroutePickup':
        return 'Rider enroute to you';
      case 'delivered':
        return 'Delivered';
      default:
        return status ?? 'Pending';
    }
  }

  DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime(2000);
    return DateTime(2000);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claimStream = ref.watch(claimStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Claimed Items'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: claimStream.when(
        data: (snapshot) {
          if (snapshot.docs.isEmpty) {
            return const Center(child: Text("No claimed items yet."));
          }

          // Filter and sort safely
          final filteredDocs = snapshot.docs.where((doc) {
            final data = doc.data();
            return !_isExpired(data['expiryDate'] ?? data['expiry']);
          }).toList()
            ..sort((a, b) {
              final aTime = _parseTimestamp(a['timestamp']);
              final bTime = _parseTimestamp(b['timestamp']);
              return bTime.compareTo(aTime); // newest first
            });

          if (filteredDocs.isEmpty) {
            return const Center(child: Text("No claimed items yet."));
          }

          return ListView.builder(
            itemCount: filteredDocs.length,
            itemBuilder: (context, index) {
              final doc = filteredDocs[index];
              final data = doc.data();
              final statusText = _getStatusText(data['status']);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                child: ListTile(
                  leading: data['imageUrl'] != null
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      data['imageUrl'],
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  )
                      : const Icon(Icons.fastfood, size: 40),
                  title: Text(data['foodName'] ?? 'Unnamed'),
                  subtitle: Text(statusText),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ClaimDetailScreen(data: data),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Error loading claims: $e',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
    );
  }
}
