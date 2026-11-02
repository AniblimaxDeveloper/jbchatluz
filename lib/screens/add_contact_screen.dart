import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class AddContactScreen extends StatefulWidget {
  const AddContactScreen({super.key});

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  final _idController = TextEditingController();
  bool _isLoading = false;

  Future<void> _searchAndChat() async {
    final searchId = _idController.text.trim();
    if (searchId.isEmpty) return;
    
    setState(() => _isLoading = true);
    try {
      final myUid = FirebaseAuth.instance.currentUser!.uid;
      
      final userQuery = await FirebaseFirestore.instance.collection('users').where('jbId', isEqualTo: searchId).get();
      
      if (userQuery.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ID tidak ditemukan!')));
        return;
      }

      final targetUser = userQuery.docs.first;
      final targetUid = targetUser.id;
      final targetName = targetUser.data()['displayName'] ?? 'Pengguna';

      // Cari apakah room private sudah ada
      final roomQuery = await FirebaseFirestore.instance.collection('rooms')
          .where('type', isEqualTo: 'private')
          .where('members', arrayContains: myUid)
          .get();

      String roomId = '';
      
      for (var doc in roomQuery.docs) {
        final members = doc.data()['members'] as List;
        if (members.contains(targetUid)) {
          roomId = doc.id;
          break;
        }
      }

      // Jika belum ada, buat room baru
      if (roomId.isEmpty) {
        final newRoom = await FirebaseFirestore.instance.collection('rooms').add({
          'type': 'private',
          'members': [myUid, targetUid],
          'lastMessage': 'Chat pribadi dimulai',
          'lastMessageTime': FieldValue.serverTimestamp(),
        });
        roomId = newRoom.id;
      }

      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ChatScreen(roomId: roomId, roomName: targetName)));
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Kontak Baru'),
        backgroundColor: const Color(0xFF075E54),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('Masukkan 9 Digit ID JBchatluz teman Anda untuk memulai obrolan.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: _idController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'JBchatluz ID', border: OutlineInputBorder(), prefixIcon: Icon(Icons.numbers)),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00A884)),
                onPressed: _isLoading ? null : _searchAndChat,
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Cari & Mulai Chat'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
