// lib/screens/recipient/donation_detail_screen.dart

import 'package:flutter/material.dart';

class DonationDetailScreen extends StatelessWidget {
  final Map<String, dynamic> data;

  const DonationDetailScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    const chakulaGreen = Color(0xFF66B347);
    // ignore: unused_local_variable
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
            height: 250,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 250,
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
                    Text(data['location'] ?? 'Unknown'),
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
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }
}
