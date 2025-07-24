// lib/screens/recipient/claim_detail_screen.dart
import 'package:flutter/material.dart';

class ClaimDetailScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  const ClaimDetailScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Claim Details"),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (data['imageUrl'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  data['imageUrl'],
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 16),
            Text(
              data['foodName'] ?? 'Unnamed',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today),
                const SizedBox(width: 8),
                Text('Expiry: ${data['expiryDate'] ?? 'N/A'}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on),
                const SizedBox(width: 8),
                Text('Pickup: ${data['pickupPoint'] ?? 'Unknown'}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.info_outline),
                const SizedBox(width: 8),
                Text('Status: ${data['status'] ?? 'Pending'}'),
              ],
            ),
            const SizedBox(height: 16),
            if (data['message'] != null)
              Text(
                data['message'],
                style: Theme.of(context).textTheme.bodyLarge,
              ),
          ],
        ),
      ),
    );
  }
}
