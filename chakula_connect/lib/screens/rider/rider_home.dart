import 'package:flutter/material.dart';
import 'rider_dashboard.dart';
import 'rider_food_tab.dart';
import 'rider_profile_tab.dart';

class RiderHome extends StatefulWidget {
  const RiderHome({super.key});

  @override
  State<RiderHome> createState() => _RiderHomeState();
}

class _RiderHomeState extends State<RiderHome> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    RiderDashboard(),
    RiderFoodTab(),
    RiderProfileTab(),
  ];

  // ignore: unused_field
  final List<String> _titles = [
    "Deliveries",
    "Available Food",
    "Profile",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.delivery_dining), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.food_bank), label: 'Posted Food'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
