// ignore_for_file: use_build_context_synchronously

import 'package:ChakulaConnect/screens/donors/donor_map_tab.dart';
import 'package:ChakulaConnect/screens/donors/chat_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'create_donation_screen.dart';
import 'donor_profile_screen.dart';
import 'edit_donation_screen.dart';

class DonorDashboard extends StatefulWidget {
  const DonorDashboard({super.key});

  @override
  State<DonorDashboard> createState() => _DonorDashboardState();
}

class _DonorDashboardState extends State<DonorDashboard> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  // Filters
  String _selectedCategory = 'All';
  String _statusFilter = 'All';
  bool _hideExpired = false;

  final categories = [
    'All',
    'Cooked',
    'Uncooked',
    'Snacks',
    'Beverages',
    'Other',
  ];

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    _pageController.jumpToPage(index);
  }

  Future<void> _deleteDonation(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete Donation", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Are you sure you want to delete this donation?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Deleting donation...")));
      await FirebaseFirestore.instance.collection('donations').doc(docId).delete();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Deleted successfully.")));
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Donor Dashboard", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green[700],
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DonorProfileScreen())),
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
        backgroundColor: Colors.green[600],
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Post Donation", style: TextStyle(color: Colors.white)),
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateDonationScreen()));
          if (result == true) setState(() {});
        },
      )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        selectedItemColor: Colors.green[700],
        unselectedItemColor: Colors.grey[500],
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.fastfood_rounded), label: 'Donations'),
          BottomNavigationBarItem(icon: Icon(Icons.map_rounded), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'Claims'),
        ],
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildDonationsList(),
          const SafeArea(child: DonorMapTab()),
          _buildClaimsList(),
        ],
      ),
    );
  }

  // ======================== Donations List ========================
  Widget _buildDonationsList() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return const Center(child: Text('Not logged in.'));

    return SafeArea(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('donations').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No donations posted yet.'));

          final docs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            if (_selectedCategory != 'All' && data['category'] != _selectedCategory) return false;
            if (_statusFilter != 'All') {
              final status = data['status']?.toLowerCase() ?? 'available';
              if (status != _statusFilter.toLowerCase()) return false;
            }
            if (_hideExpired) {
              final expiry = DateTime.tryParse(data['expiryDate'] ?? '');
              if (expiry != null && expiry.isBefore(DateTime.now())) return false;
            }
            return true;
          }).toList();

          if (docs.isEmpty) return const Center(child: Text('No matching donations.'));

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;
                final imageUrl = data['imageUrl'] ?? '';
                final foodName = data['foodName'] ?? 'Unnamed';
                final pickup = data['pickupPoint'] ?? 'N/A';
                final expiry = data['expiryDate'] ?? 'N/A';
                final category = data['category'] ?? 'Other';
                final message = data['message'] ?? '';
                final status = data['status'] ?? 'Available';
                final donorId = data['donorId'] ?? '';
                final isOwnDonation = donorId == userId;
                final donorName = data['donorUsername'] ?? 'Anonymous';

                return AnimatedContainer(
                  key: ValueKey(doc.id),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: isOwnDonation ? Border.all(color: Colors.green, width: 2) : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12.withOpacity(isOwnDonation ? 0.15 : 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
                        child: Image.network(
                          imageUrl,
                          height: 120,
                          width: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 120,
                            width: 120,
                            color: Colors.grey[200],
                            child: const Icon(Icons.fastfood, color: Colors.grey),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(foodName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
                              const SizedBox(height: 4),
                              Text("Donor: $donorName"),
                              Text("📍 $pickup"),
                              Text("🗓 $expiry"),
                              Text("📦 $category"),
                              if (message.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(message, style: const TextStyle(fontSize: 13, color: Colors.black54)),
                                ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  if (isOwnDonation)
                                    Flexible(
                                      child: ElevatedButton.icon(
                                        onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => EditDonationScreen(data: data, docId: doc.id)),
                                        ),
                                        icon: const Icon(Icons.edit, size: 16),
                                        label: const Text("Edit", overflow: TextOverflow.ellipsis),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green[600],
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                        ),
                                      ),
                                    ),
                                  if (isOwnDonation) const SizedBox(width: 8),
                                  if (isOwnDonation)
                                    Flexible(
                                      child: TextButton.icon(
                                        onPressed: () => _deleteDonation(doc.id),
                                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                                        label: const Text("Delete", overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.red)),
                                      ),
                                    ),
                                  const Spacer(),
                                  Flexible(
                                    child: ElevatedButton(
                                      onPressed: null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: status == 'Available' ? Colors.green : Colors.grey,
                                      ),
                                      child: Text(status, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  // ======================== Claims List ========================
  Widget _buildClaimsList() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return const Center(child: Text('Not logged in.'));

    return SafeArea(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('donations')
            .where('status', isEqualTo: 'claimed')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No claimed donations yet.'));

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final foodName = data['foodName'] ?? 'Unnamed';
              final pickup = data['pickupPoint'] ?? 'N/A';
              final recipientName = data['recipientName'] ?? 'Unknown';
              final recipientId = data['recipientId'] ?? '';
              final riderName = data['riderName'] ?? 'Not assigned';
              final riderId = data['riderId'] ?? '';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(foodName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text("📍 Pickup: $pickup"),
                      Text("👤 Recipient: $recipientName"),
                      Text("🏍 Rider: $riderName"),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: recipientId.isNotEmpty
                                ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DonorChatScreen(
                                    receiverId: recipientId,
                                    receiverName: recipientName,
                                  ),
                                ),
                              );
                            }
                                : null,
                            child: const Text("Chat with Recipient"),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: riderId.isNotEmpty
                                ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DonorChatScreen(
                                    receiverId: riderId,
                                    receiverName: riderName,
                                  ),
                                ),
                              );
                            }
                                : null,
                            child: const Text("Chat with Rider"),
                          ),
                        ],
                      ),
                    ],
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
