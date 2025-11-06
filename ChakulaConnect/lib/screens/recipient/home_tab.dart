// ignore_for_file: use_build_context_synchronously, avoid_print

import 'package:ChakulaConnect/screens/recipient/donation_detail_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final chakulaGreen = const Color(0xFF66B347);
  final chakulaOrange = const Color(0xFFFF6A13);

  String selectedCategory = 'All';
  String userId = '';
  int remainingClaims = 5;
  final int dailyLimit = 5;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      userId = user.uid;
      _fetchTodaysClaimCount();
    }
  }

  /// Fetch today’s claim count from Firestore
  Future<void> _fetchTodaysClaimCount() async {
    final today = DateTime.now();
    final dateString = "${today.year}-${today.month}-${today.day}";

    final doc = await FirebaseFirestore.instance
        .collection('claimLimits')
        .doc(userId)
        .get();

    int countToday = 0;
    if (doc.exists) {
      final data = doc.data();
      if (data != null && data['date'] == dateString) {
        countToday = data['count'] ?? 0;
      }
    }

    setState(() {
      remainingClaims = dailyLimit - countToday;
      if (remainingClaims < 0) remainingClaims = 0;
    });
  }

  /// Increment Firestore claim count after a successful claim
  Future<void> _incrementClaimCount() async {
    final today = DateTime.now();
    final dateString = "${today.year}-${today.month}-${today.day}";

    final docRef =
    FirebaseFirestore.instance.collection('claimLimits').doc(userId);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);

      if (!snapshot.exists) {
        transaction.set(docRef, {'date': dateString, 'count': 1});
      } else {
        final data = snapshot.data()!;
        if (data['date'] == dateString) {
          final newCount = (data['count'] ?? 0) + 1;
          transaction.update(docRef, {'count': newCount});
        } else {
          transaction.set(docRef, {'date': dateString, 'count': 1});
        }
      }
    });
  }

  /// Handle claiming a food donation
  Future<void> _claimFood(Map<String, dynamic> post) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final donationId = post['id'];

    if (remainingClaims <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⛔ You have reached your daily limit of 5 claims."),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final donationRef =
    FirebaseFirestore.instance.collection('donations').doc(donationId);
    final claimsRef = FirebaseFirestore.instance.collection('claims');

    try {
      String claimDocId = '';

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(donationRef);
        final status = (snapshot.data()?['status'] ?? 'available').toString().toLowerCase();
        if (status == 'claimed') throw Exception("Already claimed");

        // Create claim document
        final claimDoc = claimsRef.doc();
        claimDocId = claimDoc.id;
        transaction.set(claimDoc, {
          'claimId': claimDoc.id,
          'recipientId': userId,
          'recipientName': user.displayName ?? 'Unknown',
          'recipientPhone': user.phoneNumber ?? '',
          'donationId': donationId,
          'foodName': post['foodName'],
          'category': post['category'],
          'imageUrl': post['imageUrl'],
          'timestamp': Timestamp.now(),
          'status': 'claimed',
          'donorId': post['donorId'],
          'donorLocation': post['donorLocation'],
        });

        // Update donation status
        transaction.update(donationRef, {
          'status': 'claimed',
          'claimerId': userId,
        });
      });

      // Increment claim count in Firestore
      await _incrementClaimCount();
      await _fetchTodaysClaimCount(); // Update remainingClaims in UI

      // Notify donor
      final donorId = post['donorId'];
      if (donorId != null && donorId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(donorId)
            .collection('notifications')
            .add({
          'type': 'food_claimed',
          'status': 'claimed',
          'claimId': claimDocId,
          'donationId': donationId,
          'recipientId': userId,
          'fromId': userId,
          'timestamp': Timestamp.now(),
        });
      }

      // Notify all riders
      final ridersQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'rider')
          .get();

      for (var rider in ridersQuery.docs) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(rider.id)
            .collection('notifications')
            .add({
          'type': 'new_claim',
          'claimId': claimDocId,
          'donationId': donationId,
          'recipientId': userId,
          'timestamp': Timestamp.now(),
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🎉 Food claimed successfully! Check your My Claims tab."),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      print("Claim error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().contains("Already claimed")
              ? "⚠️ This food has already been claimed by someone else."
              : "Error claiming food: $e"),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 600;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Image.asset('assets/images/Chakula_Connect_logo.png', height: 60),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(Icons.map_rounded, color: chakulaGreen, size: 30),
                      onPressed: () => Navigator.pushNamed(context, '/map'),
                    ),
                    Text(
                      "Claims left: $remainingClaims",
                      style: TextStyle(
                        color: chakulaOrange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),

          // Category filter
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('donations').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();

              final docs = snapshot.data!.docs;
              final categories = {'All', ...docs.map((d) => d['category'])};

              return SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final category = categories.elementAt(index);
                    final selected = category == selectedCategory;
                    return ChoiceChip(
                      label: Text(category),
                      selected: selected,
                      selectedColor: chakulaOrange,
                      backgroundColor: Colors.grey.shade200,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (_) => setState(() => selectedCategory = category),
                    );
                  },
                ),
              );
            },
          ),

          const SizedBox(height: 10),

          // Food list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('donations')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text("⚠️ Error: ${snapshot.error.toString()}"));
                }

                final all = snapshot.data?.docs ?? [];
                final filtered = all.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final category = data['category'];
                  if (selectedCategory != 'All' && category != selectedCategory)
                    return false;
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text("No food available now."));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final doc = filtered[index];
                    final data = doc.data() as Map<String, dynamic>;
                    data['id'] = doc.id;

                    final status = (data['status'] ?? 'available').toString().toLowerCase();
                    final isClaimed = status == 'claimed';
                    final claimedByMe = data['claimerId'] == userId;

                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DonationDetailScreen(data: data),
                        ),
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: Theme.of(context).cardColor,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Image.network(
                              data['imageUrl'],
                              height: isLargeScreen ? 250 : 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 200,
                                color: Colors.grey[300],
                                child: const Icon(Icons.broken_image, size: 48),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['category'] ?? 'Unknown',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                      color: chakulaGreen,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.location_on,
                                          color: chakulaGreen, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        "${data['location'] ?? 'N/A'}",
                                        style: const TextStyle(color: Colors.black54),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: isClaimed ? null : () => _claimFood(data),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isClaimed
                                            ? Colors.grey
                                            : chakulaOrange,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                      ),
                                      icon: const Icon(Icons.check_circle),
                                      label: Text(
                                        isClaimed
                                            ? claimedByMe
                                            ? "You Claimed"
                                            : "Already Claimed"
                                            : "Claim Food",
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
