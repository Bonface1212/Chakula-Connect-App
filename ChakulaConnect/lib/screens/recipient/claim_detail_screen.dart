// lib/screens/recipient/claim_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_screen.dart'; // adjust path if needed

class ClaimDetailScreen extends StatefulWidget {
  final Map<String, dynamic> data;

  const ClaimDetailScreen({super.key, required this.data});

  @override
  State<ClaimDetailScreen> createState() => _ClaimDetailScreenState();
}

class _ClaimDetailScreenState extends State<ClaimDetailScreen> {
  Map<String, dynamic>? donorData;
  Map<String, dynamic>? riderData;

  @override
  void initState() {
    super.initState();
    _fetchDonor();
    _listenRiderUpdates();
  }

  Future<void> _fetchDonor() async {
    final donorId = widget.data['donorId'];
    if (donorId == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(donorId).get();
    if (doc.exists) {
      setState(() {
        donorData = doc.data();
      });
    }
  }

  /// Listen for rider updates in real time
  void _listenRiderUpdates() {
    final claimId = widget.data['id'] ?? widget.data['claimId'];
    if (claimId == null) return;
    FirebaseFirestore.instance
        .collection('claims')
        .doc(claimId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null && data['riderAssigned'] == true && data['rider'] != null) {
          setState(() {
            riderData = Map<String, dynamic>.from(data['rider']);
          });
        }
      }
    });
  }

  String _formatDate(dynamic value) {
    if (value == null) return 'N/A';
    try {
      if (value is Timestamp) {
        return DateFormat.yMMMd().add_jm().format(value.toDate());
      } else if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) {
          return DateFormat.yMMMd().add_jm().format(parsed);
        }
      }
      return value.toString();
    } catch (_) {
      return 'Invalid date';
    }
  }

  @override
  Widget build(BuildContext context) {
    final expiryFormatted = _formatDate(widget.data['expiryDate']);
    final claimDate = _formatDate(widget.data['timestamp']);

    final donorName = donorData?['fullName'] ?? 'Donor';
    final donorPhone = donorData?['phone'] ?? 'N/A';
    final donorLocation = donorData?['location'] ?? 'Unknown location';
    final donorProfile = donorData?['profileImageUrl'];
    final donorId = widget.data['donorId'];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Claim Details"),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.chat),
            tooltip: 'Chat with Donor',
            onPressed: donorId == null
                ? null
                : () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    receiverId: donorId,
                    receiverName: donorName,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.call),
            tooltip: 'Call Donor',
            onPressed: donorPhone == 'N/A'
                ? null
                : () async {
              final Uri phoneUri = Uri(scheme: 'tel', path: donorPhone);
              if (await canLaunchUrl(phoneUri)) {
                await launchUrl(phoneUri);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Cannot launch dialer.")),
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Food Image
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              child: widget.data['imageUrl'] != null
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  widget.data['imageUrl'],
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
              widget.data['foodName'] ?? 'Unnamed Item',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Detail Cards
            _detailCard(Icons.calendar_today, 'Expiry Date', expiryFormatted),
            _detailCard(Icons.access_time, 'Claimed On', claimDate),
            _detailCard(Icons.location_on, 'Donor Location', donorLocation),
            _detailCard(Icons.info, 'Status', widget.data['status'] ?? 'Pending'),
            _detailCard(Icons.person, 'Donor', donorName),

            if (donorProfile != null)
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(donorProfile),
                  ),
                  title: Text(donorName),
                  subtitle: Text(donorPhone),
                  trailing: IconButton(
                    icon: const Icon(Icons.call),
                    onPressed: donorPhone == 'N/A'
                        ? null
                        : () async {
                      final Uri phoneUri = Uri(scheme: 'tel', path: donorPhone);
                      if (await canLaunchUrl(phoneUri)) {
                        await launchUrl(phoneUri);
                      }
                    },
                  ),
                ),
              ),

            if (widget.data['message'] != null) ...[
              const SizedBox(height: 16),
              _messageCard(widget.data['message']),
            ],

            const SizedBox(height: 24),

            // Rider Section
            if (widget.data['status'] == 'Pending')
              Center(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    backgroundColor: Colors.green.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _showRiderAssignDialog(context),
                  icon: const Icon(Icons.motorcycle),
                  label: const Text("Request Delivery Rider"),
                ),
              ),

            if (riderData != null) ...[
              const SizedBox(height: 24),
              _riderInfoCard(context, riderData!),
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
        subtitle: Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
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
              _requestRider();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
            child: const Text("Request"),
          ),
        ],
      ),
    );
  }

  Future<void> _requestRider() async {
    final claimId = widget.data['id'] ?? widget.data['claimId'];
    if (claimId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Missing claim ID.")),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('claims').doc(claimId).update({
        'status': 'requested',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Rider request sent successfully.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to request rider: $e")),
      );
    }
  }

  Widget _riderInfoCard(BuildContext context, Map<String, dynamic> rider) {
    final name = rider['name'] ?? 'Assigned Rider';
    final phone = rider['phone'];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: rider['profileImageUrl'] != null
              ? NetworkImage(rider['profileImageUrl'])
              : null,
          child: rider['profileImageUrl'] == null ? const Icon(Icons.person) : null,
        ),
        title: Text(name),
        subtitle: const Text("Rider assigned"),
        trailing: Wrap(
          spacing: 12,
          children: [
            if (rider['uid'] != null)
              IconButton(
                icon: const Icon(Icons.chat),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        receiverId: rider['uid'],
                        receiverName: name,
                      ),
                    ),
                  );
                },
              ),
            if (phone != null)
              IconButton(
                icon: const Icon(Icons.call),
                onPressed: () async {
                  final Uri phoneUri = Uri(scheme: 'tel', path: phone);
                  if (await canLaunchUrl(phoneUri)) {
                    await launchUrl(phoneUri);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}
