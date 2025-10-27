// lib/screens/recipient/claims_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chakula_connect/screens/recipient/claim_detail_screen.dart';

final claimStreamProvider = StreamProvider.autoDispose((ref) {
  final userId = FirebaseAuth.instance.currentUser?.uid;

  if (userId == null) {
    return const Stream.empty();
  }

  return FirebaseFirestore.instance
      .collection('claims')
      .where('recipientId', isEqualTo: userId)
      .orderBy('timestamp', descending: true)
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
          final filteredDocs = snapshot.docs.where((doc) {
            final data = doc.data();
            return !_isExpired(data['expiryDate'] ?? data['expiry']);
          }).toList();

          if (filteredDocs.isEmpty) {
            return const Center(child: Text("No claimed items yet."));
          }

          return ListView.builder(
            itemCount: filteredDocs.length,
            itemBuilder: (context, index) {
              final doc = filteredDocs[index];
              final data = doc.data();

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
                  subtitle: Text(data['status'] ?? 'Pending'),
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
        error: (e, _) => Center(child: Text('Error loading claims: $e')),
      ),
    );
  }
}
