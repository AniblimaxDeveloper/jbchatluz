import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  final String type; // 'group' atau 'channel'
  const CreateGroupScreen({super.key, required this.type});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _selectedMembers = [];
  bool _isLoading = false;

  void _createRoom() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nama tidak boleh kosong')));
      return;
    }
    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser!;
      final members = _selectedMembers.map((m) => m['uid']).toList();
      members.add(currentUser.uid); // Admin masuk sebagai anggota

      final docRef = await FirebaseFirestore.instance.collection('rooms').add({
        'name': _nameController.text.trim(),
        'type': widget.type, // 'group' atau 'channel'
        'members': members,
        'admins': [currentUser.uid],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '${widget.type == 'group' ? 'Grup' : 'Channel'} dibuat',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (_) => ChatScreen(roomId: docRef.id, roomName: _nameController.text.trim()))
        );
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
        title: Text(widget.type == 'group' ? 'Buat Grup Baru' : 'Buat Channel Baru'),
        backgroundColor: const Color(0xFF075E54),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _isLoading ? null : _createRoom),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: widget.type == 'group' ? 'Nama Grup' : 'Nama Channel',
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Cari pengguna berdasarkan email',
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: (val) async {
                final query = await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: val.trim()).get();
                if (query.docs.isNotEmpty) {
                  final data = query.docs.first.data();
                  if (!_selectedMembers.any((m) => m['uid'] == data['uid'])) {
                    setState(() => _selectedMembers.add(data));
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pengguna tidak ditemukan')));
                }
                _searchController.clear();
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _selectedMembers.length,
              itemBuilder: (context, index) {
                final member = _selectedMembers[index];
                return ListTile(
                  leading: CircleAvatar(backgroundImage: member['photoURL'] != null ? NetworkImage(member['photoURL']) : null, child: member['photoURL'] == null ? const Icon(Icons.person) : null),
                  title: Text(member['displayName']),
                  subtitle: Text(member['email']),
                  trailing: IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => setState(() => _selectedMembers.removeAt(index))),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
