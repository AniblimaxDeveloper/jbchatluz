import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class StarredMessagesScreen extends StatelessWidget {
  const StarredMessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? "";

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : Colors.white,
      appBar: AppBar(
        title: const Text('Pesan Berbintang'),
        backgroundColor: isDark ? const Color(0xFF1F2C34) : const Color(0xFF075E54),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Mengambil semua pesan yang di-star (membutuhkan collectionGroup di Firestore)
        stream: FirebaseFirestore.instance.collectionGroup('messages').where('isStarred', isEqualTo: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF25D366)));
          
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star_border, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text('Belum ada pesan berbintang', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final isMe = data['senderId'] == myUid;
              final text = data['text'] ?? 'Media';
              final time = data['timestamp'] != null ? DateFormat('dd/MM/yy HH:mm').format((data['timestamp'] as Timestamp).toDate()) : '';

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isMe ? const Color(0xFF25D366) : Colors.blueGrey,
                  child: Icon(isMe ? Icons.person : Icons.person_outline, color: Colors.white),
                ),
                title: Text(isMe ? 'Anda' : (data['senderName'] ?? 'Pengguna'), style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.grey : Colors.black87)),
                    const SizedBox(height: 4),
                    Text(time, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                trailing: const Icon(Icons.star, color: Colors.orange),
              );
            },
          );
        },
      ),
    );
  }
}
