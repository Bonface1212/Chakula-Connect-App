// lib/screens/rider/rider_food_tab.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RiderFoodTab extends StatelessWidget {
  const RiderFoodTab({super.key});

  Future<void> _acceptDelivery(BuildContext context, String claimId) async {
    final riderId = FirebaseAuth.instance.currentUser?.uid;
    if (riderId == null) return;

    try {
      await FirebaseFirestore.instance.collection('claims').doc(claimId).update({
        'riderId': riderId,
        'status': 'assigned',
        'assignedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery accepted successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Available Deliveries"),
        backgroundColor: Colors.green,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('claims')
            .where('status', isEqualTo: 'claimed')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text("No delivery requests available at the moment."),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final claimId = docs[index].id;
              final foodName = data['foodName'] ?? 'Food Item';
              final imageUrl = data['imageUrl'];
              final recipientId = data['recipientId'];
              final donorLocation = data['donorLocation'];
              final timestamp = data['timestamp'];

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                child: ListTile(
                  leading: imageUrl != null
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl,
                      width: 55,
                      height: 55,
                      fit: BoxFit.cover,
                    ),
                  )
                      : const Icon(Icons.fastfood, color: Colors.green, size: 40),
                  title: Text(foodName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text("Recipient ID: $recipientId"),
                      if (timestamp != null)
                        Text("Requested: ${timestamp.toDate()}"),
                      const SizedBox(height: 6),
                      Text(
                        donorLocation == null
                            ? "Pickup location: Not set"
                            : "Pickup location ready",
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _acceptDelivery(context, claimId),
                    child: const Text("Accept"),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
