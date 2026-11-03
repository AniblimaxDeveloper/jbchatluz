import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForwardScreen extends StatefulWidget {
  final Map<String, dynamic> messageData;
  const ForwardScreen({super.key, required this.messageData});

  @override
  State<ForwardScreen> createState() => _ForwardScreenState();
}

class _ForwardScreenState extends State<ForwardScreen> {
  final String myUid = FirebaseAuth.instance.currentUser?.uid ?? "";
  bool _isForwarding = false;

  Future<void> _forwardToRoom(String roomId) async {
    setState(() => _isForwarding = true);
    try {
      // Buat salinan pesan
      final newMessage = Map<String, dynamic>.from(widget.messageData);
      newMessage['senderId'] = myUid;
      newMessage['senderName'] = FirebaseAuth.instance.currentUser?.displayName ?? 'User';
      newMessage['timestamp'] = FieldValue.serverTimestamp();
      newMessage['status'] = 'sent';
      newMessage.remove('isDeleted');
      newMessage.remove('deletedFor');

      await FirebaseFirestore.instance.collection('rooms').doc(roomId).collection('messages').add(newMessage);
      
      // Update last message room
      if (roomId != 'global') {
        FirebaseFirestore.instance.collection('rooms').doc(roomId).update({
          'lastMessage': newMessage['type'] == 'text' ? newMessage['text'] : '📎 Media',
          'lastMessageTime': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pesan diteruskan!')));
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal meneruskan: $e')));
    } finally {
      setState(() => _isForwarding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : Colors.white,
      appBar: AppBar(
        title: const Text('Teruskan ke...'),
        backgroundColor: isDark ? const Color(0xFF1F2C34) : const Color(0xFF075E54),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('rooms').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final allRooms = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['type'] == 'group' || data['type'] == 'channel' || (data['members'] != null && (data['members'] as List).contains(myUid));
          }).toList();

          return ListView.builder(
            itemCount: allRooms.length,
            itemBuilder: (context, index) {
              final doc = allRooms[index];
              final data = doc.data() as Map<String, dynamic>;
              final isPrivate = data['type'] == 'private';

              if (isPrivate) {
                String otherUid = (data['members'] as List).firstWhere((id) => id != myUid, orElse: () => '');
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(otherUid).get(),
                  builder: (context, userSnap) {
                    String name = 'Pengguna';
                    if (userSnap.hasData && userSnap.data!.exists) {
                      name = userSnap.data!['displayName'] ?? 'Pengguna';
                    }
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(name, style: TextStyle(color: textColor)),
                      onTap: _isForwarding ? null : () => _forwardToRoom(doc.id),
                    );
                  },
                );
              } else {
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.group)),
                  title: Text(data['name'] ?? 'Grup', style: TextStyle(color: textColor)),
                  onTap: _isForwarding ? null : () => _forwardToRoom(doc.id),
                );
              }
            },
          );
        },
      ),
    );
  }
}
