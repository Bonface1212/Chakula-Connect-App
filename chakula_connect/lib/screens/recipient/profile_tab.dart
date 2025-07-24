import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  String selectedRole = 'Recipient';
  String selectedLanguage = 'English';
  String? profileImageUrl;

  final user = FirebaseAuth.instance.currentUser;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      nameController.text = data['fullName'] ?? '';
      usernameController.text = data['username'] ?? '';
      selectedRole = data['role'] ?? 'Recipient';
      profileImageUrl = data['profileImageUrl'] ?? null;
    }
    setState(() => isLoading = false);
  }

  Future<void> updateProfile() async {
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
      'fullName': nameController.text.trim(),
      'username': usernameController.text.trim(),
      'role': selectedRole,
      'language': selectedLanguage,
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Profile updated')),
    );
  }

  void confirmDeleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Account"),
        content: const Text("Are you sure you want to delete your account? This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete")),
        ],
      ),
    );

    if (confirm ?? false) {
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).delete();
      await user!.delete();
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Profile picture display
                CircleAvatar(
                  radius: 55,
                  backgroundImage: profileImageUrl != null && profileImageUrl!.isNotEmpty
                      ? NetworkImage(profileImageUrl!)
                      : const AssetImage('assets/default_avatar.png') as ImageProvider,
                  backgroundColor: Colors.grey[200],
                ),
                const SizedBox(height: 10),
                Text(
                  nameController.text,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  user!.email ?? '',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
                const Divider(height: 30, thickness: 1),

                // Form
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.alternate_email)),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  items: const [
                    DropdownMenuItem(value: 'Recipient', child: Text("Recipient")),
                    DropdownMenuItem(value: 'Donor', child: Text("Donor")),
                  ],
                  onChanged: (value) => setState(() => selectedRole = value!),
                  decoration: const InputDecoration(labelText: 'Role', prefixIcon: Icon(Icons.account_circle)),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedLanguage,
                  items: const [
                    DropdownMenuItem(value: 'English', child: Text("English")),
                    DropdownMenuItem(value: 'Swahili', child: Text("Swahili")),
                  ],
                  onChanged: (value) => setState(() => selectedLanguage = value!),
                  decoration: const InputDecoration(labelText: 'Language', prefixIcon: Icon(Icons.language)),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: updateProfile,
                  icon: const Icon(Icons.save),
                  label: const Text("Save Changes"),
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(45)),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: confirmDeleteAccount,
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  label: const Text("Delete Account", style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
  }
}
