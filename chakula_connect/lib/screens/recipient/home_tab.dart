import 'package:cloud_firestore/cloud_firestore.dart';
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

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 600;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Logo + Map Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Image.asset(
                  'assets/images/Chakula Connect.png',
                  height: 60,
                ),
                IconButton(
                  icon: Icon(Icons.map_rounded, color: chakulaGreen, size: 30),
                  onPressed: () => Navigator.pushNamed(context, '/map'),
                ),
              ],
            ),
          ),

          /// Filter Chips
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('donations').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;
              final categories = {'All', ...docs.map((doc) => doc['category'].toString())};

              return SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
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

          /// Donation Posts List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('donations').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Center(child: Text("⚠️ Error loading donations."));
                }

                final all = snapshot.data?.docs ?? [];
                final filtered = selectedCategory == 'All'
                    ? all
                    : all.where((doc) => doc['category'] == selectedCategory).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text("No food available right now."));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final post = filtered[index];
                    return AnimatedContainer(
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
                              post['imageUrl'],
                              height: isLargeScreen ? 250 : 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, ___) => Container(
                                color: Colors.grey[300],
                                height: isLargeScreen ? 250 : 200,
                                alignment: Alignment.center,
                                child: const Icon(Icons.broken_image, size: 48),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    post['category'],
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
                                        "${post['location']} • ${post['distance'] ?? '2.5km'}",
                                        style: const TextStyle(color: Colors.black54),
                                      ),
                                      const Spacer(),
                                      Icon(Icons.timer_outlined, size: 18, color: chakulaOrange),
                                      const SizedBox(width: 6),
                                      Text(
                                        post['expiry'],
                                        style: TextStyle(color: chakulaOrange),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: const Text("🎉 Food claimed successfully!"),
                                            backgroundColor: chakulaGreen,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        backgroundColor: chakulaOrange,
                                        foregroundColor: Colors.white,
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
