// ignore_for_file: unnecessary_underscores

import 'package:chakula_connect/screens/donors/donor_map_tab.dart';
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
  final userId = FirebaseAuth.instance.currentUser?.uid;

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    _pageController.jumpToPage(index);
  }

  void _deleteDonation(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Donation"),
        content: const Text("Are you sure you want to delete this donation?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('donations')
          .doc(docId)
          .delete();
      ScaffoldMessenger.of(
        // ignore: use_build_context_synchronously
        context,
      ).showSnackBar(const SnackBar(content: Text("Deleted.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Donor Dashboard",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green[700],
        elevation: 3,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DonorProfileScreen()),
            ),
          ),
        ],
      ),

      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              backgroundColor: Colors.green[600],
              icon: const Icon(Icons.add),
              label: const Text("Post Donation"),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateDonationScreen()),
              ),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        selectedItemColor: Colors.green[700],
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.fastfood),
            label: 'Donations',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
        ],
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildDonationsList(),
          const DonorMapTab(
            claimId: '',
          ), // claimId is null — shows "no delivery" message
        ],
      ),
    );
  }

  Widget _buildDonationsList() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return const Center(child: Text('Not logged in.'));
    }

    return SafeArea(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('donations')
            .where('donorId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No donations posted yet.'));
          }

          final docs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;

            if (_selectedCategory != 'All' &&
                data['category'] != _selectedCategory) {
              return false;
            }

            if (_statusFilter != 'All') {
              final status = data['status']?.toLowerCase();
              if (status != _statusFilter.toLowerCase()) return false;
            }

            if (_hideExpired) {
              final expiry = DateTime.tryParse(data['expiryDate'] ?? '');
              if (expiry != null && expiry.isBefore(DateTime.now())) {
                return false;
              }
            }

            return true;
          }).toList();

          if (docs.isEmpty) {
            return const Center(child: Text('No matching donations.'));
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        items: categories
                            .map(
                              (cat) => DropdownMenuItem(
                                value: cat,
                                child: Text(cat),
                              ),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _selectedCategory = val!),
                        decoration: const InputDecoration(
                          labelText: "Category",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _statusFilter,
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('All')),
                          DropdownMenuItem(
                            value: 'Available',
                            child: Text('Available'),
                          ),
                          DropdownMenuItem(
                            value: 'Claimed',
                            child: Text('Claimed'),
                          ),
                        ],
                        onChanged: (val) =>
                            setState(() => _statusFilter = val!),
                        decoration: const InputDecoration(
                          labelText: "Status",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    TextButton.icon(
                      icon: Icon(
                        _hideExpired ? Icons.visibility_off : Icons.visibility,
                      ),
                      label: Text(
                        _hideExpired ? 'Show Expired' : 'Hide Expired',
                      ),
                      onPressed: () =>
                          setState(() => _hideExpired = !_hideExpired),
                    ),
                  ],
                ),
              ),
              ...docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                        ),
                        child: Image.network(
                          data['imageUrl'] ?? '',
                          height: 120,
                          width: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 120,
                            width: 120,
                            color: Colors.grey[300],
                            child: const Icon(Icons.broken_image, size: 40),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['foodName'] ?? 'Unnamed',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text("📍 ${data['pickupPoint'] ?? 'N/A'}"),
                              Text("🗓 ${data['expiryDate'] ?? 'N/A'}"),
                              Text("📦 ${data['category'] ?? 'Other'}"),
                              if ((data['message'] ?? '').isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    data['message'],
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  TextButton(
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => EditDonationScreen(
                                          donationId: doc.id,
                                          data: data,
                                          docId: doc.id,
                                        ),
                                      ),
                                    ),
                                    child: const Text("Edit"),
                                  ),
                                  TextButton(
                                    onPressed: () => _deleteDonation(doc.id),
                                    child: const Text(
                                      "Delete",
                                      style: TextStyle(color: Colors.red),
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
              }),
            ],
          );
        },
      ),
    );
  }
}
