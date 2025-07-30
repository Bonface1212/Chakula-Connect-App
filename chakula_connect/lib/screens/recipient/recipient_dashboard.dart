import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chakula_connect/theme/theme_controller.dart';
import 'package:chakula_connect/screens/recipient/home_tab.dart';
import 'package:chakula_connect/screens/recipient/map_tab.dart';
import 'package:chakula_connect/screens/recipient/claims_tab.dart';
import 'package:chakula_connect/screens/recipient/profile_tab.dart';

class RecipientDashboard extends ConsumerStatefulWidget {
  const RecipientDashboard({super.key});

  @override
  ConsumerState<RecipientDashboard> createState() => _RecipientDashboardState();
}

class _RecipientDashboardState extends ConsumerState<RecipientDashboard> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    HomeTab(),
    MapTab(claimId: '',),
    ClaimsTab(),
    ProfileTab(),
  ];

  final List<String> _titles = [
    'Home',
    'Map',
    'My Claims',
    'Profile',
  ];

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(themeControllerProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0.5,
        centerTitle: true,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Image.asset(
                'assets/images/Chakula Connect.png',
                height: 30,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _titles[_currentIndex],
              style: Theme.of(context).textTheme.titleLarge!.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDarkMode ? Icons.dark_mode : Icons.light_mode,
              color: Theme.of(context).iconTheme.color,
            ),
            onPressed: () {
              ref.read(themeControllerProvider.notifier).toggleTheme();
            },
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _tabs[_currentIndex],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        backgroundColor: Theme.of(context).colorScheme.surface,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_rounded),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_rounded),
            label: 'My Claims',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
