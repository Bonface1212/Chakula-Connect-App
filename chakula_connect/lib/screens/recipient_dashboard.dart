import 'package:flutter/material.dart';

class RecipientDashboard extends StatelessWidget {
  const RecipientDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recipient Dashboard')),
      body: const Center(child: Text('Welcome, Recipient!')),
    );
  }
}
