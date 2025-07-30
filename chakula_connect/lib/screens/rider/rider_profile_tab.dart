import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RiderProfileTab extends StatelessWidget {
  const RiderProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Profile"),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundImage: AssetImage('assets/images/rider.png'), // Replace with user photo
            ),
            const SizedBox(height: 12),
            Text(user?.displayName ?? 'Rider',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(user?.email ?? '',
                style: const TextStyle(fontSize: 14, color: Colors.grey)),
            const Divider(height: 32),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Log Out"),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ],
        ),
      ),
    );
  }
}
