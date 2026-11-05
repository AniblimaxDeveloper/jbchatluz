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
  final List<String> _selectedRooms = [];
  String _searchQuery = "";
  bool _isForwarding = false;

  Future<void> _forwardMessage() async {
    if (_selectedRooms.isEmpty) return;
    setState(() => _isForwarding = true);

    try {
      for (String roomId in _selectedRooms) {
        final newMessage = Map<String, dynamic>.from(widget.messageData);
        newMessage['senderId'] = myUid;
        newMessage['senderName'] = FirebaseAuth.instance.currentUser?.displayName ?? 'User';
        newMessage['timestamp'] = FieldValue.serverTimestamp();
        newMessage['status'] = 'sent';
        newMessage.remove('isDeleted');
        newMessage.remove('deletedFor');
        newMessage.remove('replyTo');

        await FirebaseFirestore.instance.collection('rooms').doc(roomId).collection('messages').add(newMessage);
        
        // Update last message room
        if (roomId != 'global') {
          final text = newMessage['type'] == 'text' ? newMessage['text'] : '📎 Media';
          await FirebaseFirestore.instance.collection('rooms').doc(roomId).update({
            'lastMessage': text,
            'lastMessageTime': FieldValue.serverTimestamp(),
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pesan berhasil diteruskan!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal meneruskan: $e')));
    } finally {
      if (mounted) setState(() => _isForwarding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final appBarColor = isDark ? const Color(0xFF1F2C34) : const Color(0xFF075E54);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : Colors.white,
      appBar: AppBar(
        backgroundColor: appBarColor,
        foregroundColor: Colors.white,
        title: Text('Teruskan ke (${_selectedRooms.length})'),
        actions: [
          if (_isForwarding)
            const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
          else
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _selectedRooms.isEmpty ? null : _forwardMessage,
            )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Cari kontak atau grup...',
                hintStyle: TextStyle(color: isDark ? Colors.grey : Colors.black54),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: isDark ? const Color(0xFF2A3942) : Colors.grey[200],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
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
                          ImageProvider? avatarImage;
                          if (userSnap.hasData && userSnap.data!.exists) {
                            final uData = userSnap.data!.data() as Map<String, dynamic>;
                            name = uData['displayName'] ?? 'Pengguna';
                            if (uData['photoBase64'] != null && uData['photoBase64'].toString().isNotEmpty) avatarImage = MemoryImage(base64Decode(uData['photoBase64']));
                          }

                          if (_searchQuery.isNotEmpty && !name.toLowerCase().contains(_searchQuery)) return const SizedBox.shrink();
                          final isSelected = _selectedRooms.contains(doc.id);

                          return CheckboxListTile(
                            secondary: CircleAvatar(radius: 22, backgroundImage: avatarImage ?? const NetworkImage('https://i.pravatar.cc/150'), backgroundColor: Colors.grey),
                            title: Text(name, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                            value: isSelected,
                            activeColor: const Color(0xFF25D366),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) _selectedRooms.add(doc.id);
                                else _selectedRooms.remove(doc.id);
                              });
                            },
                          );
                        },
                      );
                    } else {
                      final groupName = data['name'] ?? 'Grup';
                      if (_searchQuery.isNotEmpty && !groupName.toLowerCase().contains(_searchQuery)) return const SizedBox.shrink();
                      final isSelected = _selectedRooms.contains(doc.id);

                      return CheckboxListTile(
                        secondary: CircleAvatar(radius: 22, backgroundColor: Colors.blueGrey, child: Icon(data['type'] == 'channel' ? Icons.campaign : Icons.group, color: Colors.white)),
                        title: Text(groupName, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                        value: isSelected,
                        activeColor: const Color(0xFF25D366),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) _selectedRooms.add(doc.id);
                            else _selectedRooms.remove(doc.id);
                          });
                        },
                      );
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
