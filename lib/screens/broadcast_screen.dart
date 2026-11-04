import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BroadcastScreen extends StatefulWidget {
  const BroadcastScreen({super.key});

  @override
  State<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends State<BroadcastScreen> {
  final String myUid = FirebaseAuth.instance.currentUser?.uid ?? "";
  final _msgController = TextEditingController();
  final List<String> _selectedContacts = [];
  bool _isSending = false;

  Future<void> _sendBroadcast() async {
    if (_selectedContacts.isEmpty || _msgController.text.trim().isEmpty) return;
    setState(() => _isSending = true);

    try {
      final text = _msgController.text.trim();
      for (String targetUid in _selectedContacts) {
        // Cari atau buat room private
        final roomQuery = await FirebaseFirestore.instance.collection('rooms')
            .where('type', isEqualTo: 'private')
            .where('members', arrayContains: myUid).get();

        String roomId = '';
        for (var doc in roomQuery.docs) {
          final members = doc.data()['members'] as List;
          if (members.contains(targetUid)) { roomId = doc.id; break; }
        }

        if (roomId.isEmpty) {
          final newRoom = await FirebaseFirestore.instance.collection('rooms').add({
            'type': 'private', 'members': [myUid, targetUid],
            'lastMessage': text, 'lastMessageTime': FieldValue.serverTimestamp(),
          });
          roomId = newRoom.id;
        } else {
          await FirebaseFirestore.instance.collection('rooms').doc(roomId).update({
            'lastMessage': text, 'lastMessageTime': FieldValue.serverTimestamp(),
          });
        }

        // Kirim pesan
        await FirebaseFirestore.instance.collection('rooms').doc(roomId).collection('messages').add({
          'type': 'text', 'text': text, 'senderId': myUid,
          'senderName': FirebaseAuth.instance.currentUser?.displayName ?? 'User',
          'timestamp': FieldValue.serverTimestamp(), 'status': 'sent',
        });
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Siaran berhasil dikirim!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : Colors.white,
      appBar: AppBar(title: const Text('Daftar Siaran'), backgroundColor: const Color(0xFF075E54), foregroundColor: Colors.white),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _msgController,
              maxLines: 3,
              style: TextStyle(color: textColor),
              decoration: const InputDecoration(labelText: 'Isi Pesan Siaran', border: OutlineInputBorder()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(alignment: Alignment.centerLeft, child: Text('Pilih Penerima (${_selectedContacts.length})', style: TextStyle(fontWeight: FontWeight.bold, color: textColor))),
          ),
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(myUid).snapshots(),
              builder: (context, mySnap) {
                if (!mySnap.hasData) return const Center(child: CircularProgressIndicator());
                final List<String> contactUids = List<String>.from((mySnap.data!.data() as Map)['contacts'] ?? []);
                if (contactUids.isEmpty) return const Center(child: Text('Belum ada kontak.', style: TextStyle(color: Colors.grey)));

                return ListView.builder(
                  itemCount: contactUids.length,
                  itemBuilder: (context, index) {
                    final uid = contactUids[index];
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
                      builder: (context, userSnap) {
                        if (!userSnap.hasData || !userSnap.data!.exists) return const SizedBox.shrink();
                        final uData = userSnap.data!.data() as Map<String, dynamic>;
                        final name = uData['displayName'] ?? 'Pengguna';
                        ImageProvider? avatar;
                        if (uData['photoBase64'] != null && uData['photoBase64'].toString().isNotEmpty) avatar = MemoryImage(base64Decode(uData['photoBase64']));

                        return CheckboxListTile(
                          secondary: CircleAvatar(backgroundImage: avatar, backgroundColor: Colors.grey, child: avatar == null ? const Icon(Icons.person, color: Colors.white) : null),
                          title: Text(name, style: TextStyle(color: textColor)),
                          value: _selectedContacts.contains(uid),
                          activeColor: const Color(0xFF25D366),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) _selectedContacts.add(uid); else _selectedContacts.remove(uid);
                            });
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity, height: 50,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                onPressed: _isSending ? null : _sendBroadcast,
                child: _isSending ? const CircularProgressIndicator(color: Colors.white) : const Text('Kirim Siaran'),
              ),
            ),
          )
        ],
      ),
    );
  }
}
