import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class RiderFoodTab extends StatelessWidget {
  const RiderFoodTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Available Donations"),
        backgroundColor: Colors.green,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('donations')
            .where('isClaimed', isEqualTo: false)
            .where('isExpired', isEqualTo: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("No food donations available now."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.shade100,
                    child: const Icon(Icons.fastfood),
                  ),
                  title: Text(data['foodName'] ?? 'Food Item'),
                  subtitle: Text("Donor: ${data['donorUsername']}"),
                  trailing: ElevatedButton(
                    onPressed: () {
                      // Navigate to claim or request this donation
                    },
                    child: const Text("Request"),
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
