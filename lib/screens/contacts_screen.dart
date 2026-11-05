import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final String myUid = FirebaseAuth.instance.currentUser?.uid ?? "";

  Future<void> _startChat(String targetUid, String name) async {
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
        'lastMessage': 'Chat pribadi dimulai', 'lastMessageTime': FieldValue.serverTimestamp(),
      });
      roomId = newRoom.id;
    }

    if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(roomId: roomId, roomName: name)));
  }

  Future<void> _deleteContact(String uid, String name) async {
    await FirebaseFirestore.instance.collection('users').doc(myUid).update({
      'contacts': FieldValue.arrayRemove([uid]),
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name telah dihapus dari kontak')));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kontak'),
        backgroundColor: isDark ? const Color(0xFF1F2C34) : const Color(0xFF075E54),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(myUid).snapshots(),
        builder: (context, mySnap) {
          if (!mySnap.hasData) return const Center(child: CircularProgressIndicator());
          
          final myData = mySnap.data!.data() as Map<String, dynamic>?;
          final List<String> contactUids = List<String>.from(myData?['contacts'] ?? []);

          if (contactUids.isEmpty) return const Center(child: Text('Belum ada kontak yang disimpan.', style: TextStyle(color: Colors.grey)));

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
                  final about = uData['about'] ?? 'Tersedia';
                  ImageProvider? avatar;
                  if (uData['photoBase64'] != null && uData['photoBase64'].toString().isNotEmpty) {
                    avatar = MemoryImage(base64Decode(uData['photoBase64']));
                  }

                  return ListTile(
                    leading: CircleAvatar(backgroundImage: avatar, backgroundColor: Colors.grey, child: avatar == null ? const Icon(Icons.person, color: Colors.white) : null),
                    title: Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                    subtitle: Text(about, style: const TextStyle(color: Colors.grey)),
                    onTap: () => _startChat(uid, name),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Hapus Kontak'),
                            content: Text('Hapus $name dari daftar kontak Anda?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
                              TextButton(onPressed: () { Navigator.pop(context); _deleteContact(uid, name); }, child: const Text('Hapus', style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                      },
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
