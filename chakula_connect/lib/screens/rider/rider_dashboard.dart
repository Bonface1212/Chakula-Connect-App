import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'rider_map_tab.dart';
import 'rider_food_tab.dart';
import 'rider_profile_tab.dart';

class RiderDashboard extends StatefulWidget {
  const RiderDashboard({super.key});

  @override
  State<RiderDashboard> createState() => _RiderDashboardState();
}

class _RiderDashboardState extends State<RiderDashboard> {
  int _currentIndex = 0;
  int _newRequests = 0;

  final List<Widget> _tabs = [
    const RiderMapTab(),
    const RiderFoodTab(),
    const RiderProfileTab(),
  ];

  final List<String> _titles = [
    "Map & Deliveries",
    "Available Food",
    "My Profile",
  ];

  @override
  void initState() {
    super.initState();
    _listenForNewRequests();
  }

  void _listenForNewRequests() {
    FirebaseFirestore.instance
        .collection('claims')
        .where('status', isEqualTo: 'requested')
        .snapshots()
        .listen((snapshot) {
      setState(() => _newRequests = snapshot.docs.length);
    });
  }

  PreferredSizeWidget _buildAppBar() {
    final user = FirebaseAuth.instance.currentUser;
    final String? photoUrl = user?.photoURL;
    final String name = user?.displayName ?? "Rider";
    final String initials = name.isNotEmpty ? name[0].toUpperCase() : 'R';

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      title: Text(
        _titles[_currentIndex],
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        if (_currentIndex == 0 && _newRequests > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Chip(
              backgroundColor: Colors.red.shade700,
              label: Text(
                "$_newRequests new request${_newRequests > 1 ? 's' : ''}",
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: const AssetImage('assets/images/rider.png'),
            foregroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                ? NetworkImage(photoUrl)
                : null,
            child: (photoUrl == null || photoUrl.isEmpty)
                ? Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  )
                : null,
          ),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: SafeArea(child: _tabs[_currentIndex]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.green.shade700,
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.map),
                if (_newRequests > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Center(
                        child: Text(
                          '$_newRequests',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Map',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.fastfood),
            label: 'Food',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
