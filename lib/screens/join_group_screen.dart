import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({super.key});

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  final _linkController = TextEditingController();
  bool _isLoading = false;

  Future<void> _joinGroup() async {
    final inputLink = _linkController.text.trim();
    if (inputLink.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final myUid = FirebaseAuth.instance.currentUser!.uid;
      
      // Cari room dengan inviteLink yang cocok
      final query = await FirebaseFirestore.instance.collection('rooms').where('inviteLink', isEqualTo: inputLink).get();

      if (query.docs.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link undangan tidak valid atau sudah kedaluwarsa.')));
        return;
      }

      final roomDoc = query.docs.first;
      final roomData = roomDoc.data();
      final members = (roomData['members'] as List?) ?? [];

      if (members.contains(myUid)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Anda sudah menjadi anggota grup ini.')));
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ChatScreen(roomId: roomDoc.id, roomName: roomData['name'] ?? 'Grup')));
        }
        return;
      }

      // Tambahkan ke members
      await roomDoc.reference.update({
        'members': FieldValue.arrayUnion([myUid]),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Berhasil bergabung dengan grup!')));
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ChatScreen(roomId: roomDoc.id, roomName: roomData['name'] ?? 'Grup')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : Colors.white,
      appBar: AppBar(
        title: const Text('Gabung via Link'),
        backgroundColor: isDark ? const Color(0xFF1F2C34) : const Color(0xFF075E54),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('Tempelkan link undangan grup yang Anda terima di sini untuk bergabung.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: _linkController,
              decoration: const InputDecoration(
                labelText: 'Link Undangan (contoh: jbch.at/abc123)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00A884)),
                onPressed: _isLoading ? null : _joinGroup,
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Gabung Grup'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
