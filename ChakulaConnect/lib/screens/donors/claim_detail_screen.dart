// lib/screens/donors/donor_claim_detail_screen.dart
import 'package:ChakulaConnect/screens/donors/chat_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DonorClaimDetailScreen extends StatelessWidget {
  final String claimId;

  const DonorClaimDetailScreen({super.key, required this.claimId});

  @override
  Widget build(BuildContext context) {
    final claimsRef = FirebaseFirestore.instance.collection('claims');

    return Scaffold(
      appBar: AppBar(
        title: const Text("Claim Details"),
        backgroundColor: Colors.green[700],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: claimsRef.doc(claimId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Claim not found."));
          }

          final claimData = snapshot.data!.data() as Map<String, dynamic>;
          final recipientId = claimData['recipientId'] ?? '';
          final recipientName = claimData['recipientName'] ?? 'Recipient';
          final recipientPhone = claimData['recipientPhone'] ?? '';
          final foodName = claimData['foodName'] ?? 'Food';
          final foodImage = claimData['foodImage'] ?? '';
          final status = claimData['status'] ?? 'pending';
          final riderId = claimData['riderId'] ?? '';
          final riderName = claimData['riderName'] ?? 'Not assigned';
          final riderPhone = claimData['riderPhone'] ?? '';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Claimed Food
                Text(
                  "Claimed Food",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            bottomLeft: Radius.circular(16)),
                        child: Image.network(
                          foodImage,
                          height: 120,
                          width: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(color: Colors.grey[200], height: 120, width: 120, child: const Icon(Icons.fastfood, color: Colors.grey)),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            foodName,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Recipient Details
                Text(
                  "Recipient Details",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Name: $recipientName"),
                        Text("Phone: $recipientPhone"),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DonorChatScreen(
                                  receiverId: recipientId,
                                  receiverName: recipientName,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.chat),
                          label: const Text("Chat with Recipient"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Rider Details
                Text(
                  "Assigned Rider",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Name: $riderName"),
                        if (riderId.isNotEmpty) Text("Phone: $riderPhone"),
                        const SizedBox(height: 8),
                        if (riderId.isNotEmpty)
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DonorChatScreen(
                                    receiverId: riderId,
                                    receiverName: riderName,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.chat),
                            label: const Text("Chat with Rider"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                Text("Status: $status", style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          );
        },
      ),
    );
  }
}
