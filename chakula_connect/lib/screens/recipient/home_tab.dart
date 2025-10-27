import 'package:chakula_connect/screens/recipient/donation_detail_screen.dart';
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
  int remainingClaims = 3;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      userId = user.uid;
      _fetchTodaysClaimCount();
    }
  }

  Future<void> _fetchTodaysClaimCount() async {
    final todayStart = DateTime.now();
    final startOfDay = DateTime(todayStart.year, todayStart.month, todayStart.day);

    final snapshot = await FirebaseFirestore.instance
        .collection('claims')
        .where('userId', isEqualTo: userId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .get();

    setState(() {
      remainingClaims = 3 - snapshot.docs.length;
    });
  }

  Future<void> _claimFood(Map<String, dynamic> post) async {
    final donationId = post['id'];

    if (remainingClaims <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⛔ You have reached your daily limit of 3 claims.")),
      );
      return;
    }

    final existing = await FirebaseFirestore.instance
        .collection('claims')
        .where('userId', isEqualTo: userId)
        .where('donationId', isEqualTo: donationId)
        .get();

    if (existing.docs.isNotEmpty) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ You've already claimed this item.")),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('claims').add({
        'userId': userId,
        'donationId': donationId,
        'foodName': post['foodName'],
        'imageUrl': post['imageUrl'],
        'timestamp': Timestamp.now(),
        'status': 'claimed',
      });

      await FirebaseFirestore.instance
          .collection('donations')
          .doc(donationId)
          .update({'status': 'claimed'});

      setState(() => remainingClaims--);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("🎉 Food claimed successfully!"),
          backgroundColor: chakulaGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error claiming food: $e")),
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
          // Logo + Map Button + Claim Info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Image.asset('assets/images/Chakula Connect.png', height: 60),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(Icons.map_rounded, color: chakulaGreen, size: 30),
                      onPressed: () => Navigator.pushNamed(context, '/map'),
                    ),
                    Text(
                      "Claims left: $remainingClaims",
                      style: TextStyle(color: chakulaOrange, fontWeight: FontWeight.bold),
                    )
                  ],
                )
              ],
            ),
          ),

          // Filter Chips
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('donations')
                .where('status', isEqualTo: 'available')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              final docs = snapshot.data!.docs;
              final categories = {'All', ...docs.map((doc) => doc['category'].toString())};

              return SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final category = categories.elementAt(index);
                    final isSelected = selectedCategory == category;
                    return ChoiceChip(
                      label: Text(category),
                      selected: isSelected,
                      selectedColor: chakulaOrange,
                      backgroundColor: Colors.grey.shade200,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
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

          // Food List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('donations')
                  .where('status', isEqualTo: 'available')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Center(child: Text("⚠️ Error loading donations."));
                }

                final all = snapshot.data?.docs ?? [];
                final now = DateTime.now();

                final filtered = all.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final category = data['category'];
                  final expiryRaw = data['expiryDate'] ?? data['expiry'] ?? '';
                  final expiry = DateTime.tryParse(expiryRaw);
                  final isExpired = expiry != null && expiry.isBefore(now);
                  final matchesCategory = selectedCategory == 'All' || category == selectedCategory;
                  return matchesCategory && !isExpired;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text("No food available right now."));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final post = filtered[index];
                    final data = post.data() as Map<String, dynamic>;
                    data['id'] = post.id;

                    return GestureDetector(
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DonationDetailScreen(data: data),
      ),
    );
  },
  child: AnimatedContainer(
    duration: const Duration(milliseconds: 300),
  


                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            // ignore: deprecated_member_use
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          )
                        ],
                        color: Theme.of(context).cardColor,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Image.network(
                              data['imageUrl'],
                              height: isLargeScreen ? 250 : 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: isLargeScreen ? 250 : 200,
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
                                    data['category'],
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                          color: chakulaGreen,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.location_on, size: 18, color: chakulaGreen),
                                      const SizedBox(width: 6),
                                      Text(
                                        "${data['location'] ?? 'N/A'} • ${data['distance'] ?? '2.5km'}",
                                        style: const TextStyle(color: Colors.black54),
                                      ),
                                      const Spacer(),
                                      Icon(Icons.timer_outlined, size: 18, color: chakulaOrange),
                                      const SizedBox(width: 6),
                                      Text(
                                        data['expiryDate'] ?? data['expiry'] ?? 'N/A',
                                        style: TextStyle(color: chakulaOrange),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _claimFood(data),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: chakulaOrange,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                      ),
                                      icon: const Icon(Icons.check_circle_outline),
                                      label: const Text("Claim Food", style: TextStyle(fontSize: 16)),
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ],
                        ),
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
