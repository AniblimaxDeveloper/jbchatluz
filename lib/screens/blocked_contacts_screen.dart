import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BlockedContactsScreen extends StatefulWidget {
  const BlockedContactsScreen({super.key});

  @override
  State<BlockedContactsScreen> createState() => _BlockedContactsScreenState();
}

class _BlockedContactsScreenState extends State<BlockedContactsScreen> {
  final String myUid = FirebaseAuth.instance.currentUser?.uid ?? "";

  Future<void> _unblock(String uid, String name) async {
    await FirebaseFirestore.instance.collection('users').doc(myUid).update({
      'blockedUsers': FieldValue.arrayRemove([uid]),
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name berhasil dibuka blokirnya.')));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : Colors.white,
      appBar: AppBar(
        title: const Text('Kontak Diblokir'),
        backgroundColor: isDark ? const Color(0xFF1F2C34) : const Color(0xFF075E54),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(myUid).snapshots(),
        builder: (context, mySnap) {
          if (!mySnap.hasData) return const Center(child: CircularProgressIndicator());
          
          final myData = mySnap.data!.data() as Map<String, dynamic>?;
          final List<String> blockedUids = List<String>.from(myData?['blockedUsers'] ?? []);

          if (blockedUids.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.block, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('Tidak ada kontak yang diblokir', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: blockedUids.length,
            itemBuilder: (context, index) {
              final uid = blockedUids[index];
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData || !userSnap.data!.exists) return const SizedBox.shrink();
                  
                  final uData = userSnap.data!.data() as Map<String, dynamic>;
                  final name = uData['displayName'] ?? 'Pengguna';
                  ImageProvider? avatar;
                  if (uData['photoBase64'] != null && uData['photoBase64'].toString().isNotEmpty) {
                    avatar = MemoryImage(base64Decode(uData['photoBase64']));
                  }

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: avatar,
                      backgroundColor: Colors.grey,
                      child: avatar == null ? const Icon(Icons.person, color: Colors.white) : null,
                    ),
                    title: Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                    subtitle: const Text('Diblokir', style: TextStyle(color: Colors.red)),
                    trailing: TextButton(
                      onPressed: () => _unblock(uid, name),
                      child: const Text('Buka Blokir', style: TextStyle(color: Color(0xFF25D366), fontWeight: FontWeight.bold)),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
