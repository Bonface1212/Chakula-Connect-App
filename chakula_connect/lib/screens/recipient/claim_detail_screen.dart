import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ClaimDetailScreen extends StatelessWidget {
  final Map<String, dynamic> data;

  const ClaimDetailScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final expiry = data['expiryDate'];
    final expiryFormatted = expiry != null
        ? DateFormat.yMMMd().format(DateTime.tryParse(expiry) ?? DateTime.now())
        : 'N/A';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Claim Details"),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.chat),
            tooltip: 'Chat with Donor',
            onPressed: () {
              // TODO: Open chat screen with Donor
            },
          ),
          IconButton(
            icon: const Icon(Icons.call),
            tooltip: 'Call Donor',
            onPressed: () {
              final phone = data['donorPhone'];
              if (phone != null) launchUrl(Uri.parse('tel:$phone'));
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              child: data['imageUrl'] != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        data['imageUrl'],
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Container(
                      height: 220,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(child: Icon(Icons.image, size: 50)),
                    ),
            ),
            const SizedBox(height: 24),

            // Food Name
            Text(
              data['foodName'] ?? 'Unnamed Item',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),

            const SizedBox(height: 16),

            // Detail Cards
            _detailCard(Icons.calendar_today, 'Expiry', expiryFormatted),
            _detailCard(Icons.location_on, 'Pickup Point', data['pickupPoint'] ?? 'Unknown'),
            _detailCard(Icons.info, 'Status', data['status'] ?? 'Pending'),

            if (data['message'] != null) ...[
              const SizedBox(height: 16),
              _messageCard(data['message']),
            ],

            const SizedBox(height: 24),

            // Rider Section
            if (data['status'] == 'Pending')
              Center(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    backgroundColor: Colors.green.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    _showRiderAssignDialog(context);
                  },
                  icon: const Icon(Icons.motorcycle),
                  label: const Text("Request Delivery Rider"),
                ),
              ),

            if (data['riderAssigned'] == true) ...[
              const SizedBox(height: 24),
              _riderInfoCard(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailCard(IconData icon, String title, String value) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(icon, color: Colors.green.shade700),
        title: Text(title),
        subtitle: Text(value),
      ),
    );
  }

  Widget _messageCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Text(
        message,
        style: const TextStyle(fontSize: 16),
      ),
    );
  }

  void _showRiderAssignDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Rider Request"),
        content: const Text("Do you want to request a rider to deliver this item?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement rider assignment logic
              // Update Firestore status, assign rider ID, etc.
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
            child: const Text("Request"),
          ),
        ],
      ),
    );
  }

  Widget _riderInfoCard(BuildContext context) {
    final rider = data['rider'] ?? {};
    final name = rider['name'] ?? 'Assigned Rider';
    final phone = rider['phone'];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        leading: const Icon(Icons.person_pin_circle, size: 32, color: Colors.green),
        title: Text(name),
        subtitle: const Text("Rider assigned"),
        trailing: Wrap(
          spacing: 12,
          children: [
            IconButton(
              icon: const Icon(Icons.chat),
              onPressed: () {
                // TODO: Open chat with rider
              },
            ),
            if (phone != null)
              IconButton(
                icon: const Icon(Icons.call),
                onPressed: () {
                  launchUrl(Uri.parse('tel:$phone'));
                },
              ),
          ],
        ),
      ),
    );
  }
}
