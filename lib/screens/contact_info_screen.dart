import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ContactInfoScreen extends StatelessWidget {
  final String userId;
  final String fallbackName;
  const ContactInfoScreen({super.key, required this.userId, required this.fallbackName});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Info Kontak'),
        backgroundColor: isDark ? const Color(0xFF202C33) : const Color(0xFF075E54),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('Pengguna tidak ditemukan. (Mungkin Room Global)'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final name = data['displayName'] ?? fallbackName;
          final email = data['email'] ?? 'Tidak ada email';
          final photoUrl = data['photoURL'];

          return Column(
            children: [
              const SizedBox(height: 30),
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey[300],
                backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                child: photoUrl == null ? const Icon(Icons.person, size: 60, color: Colors.white) : null,
              ),
              const SizedBox(height: 20),
              Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(email, style: const TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 30),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Tentang'),
                subtitle: const Text('Tersedia'),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.block, color: Colors.red),
                title: const Text('Blokir Kontak', style: TextStyle(color: Colors.red)),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fitur blokir segera hadir!')));
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
