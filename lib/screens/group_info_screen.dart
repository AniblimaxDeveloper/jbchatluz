import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class GroupInfoScreen extends StatefulWidget {
  final String roomId;
  final String roomName;
  const GroupInfoScreen({super.key, required this.roomId, required this.roomName});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final String myUid = FirebaseAuth.instance.currentUser?.uid ?? "";
  final _searchIdController = TextEditingController();
  bool _isLoading = false;

  Future<void> _addMember() async {
    final searchId = _searchIdController.text.trim();
    if (searchId.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final userQuery = await FirebaseFirestore.instance.collection('users').where('jbId', isEqualTo: searchId).get();
      
      if (userQuery.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ID tidak ditemukan!')));
        return;
      }

      final targetUid = userQuery.docs.first.id;

      // Tambahkan ke members dan admins (opsional) di Firestore
      await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).update({
        'members': FieldValue.arrayUnion([targetUid]),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Anggota berhasil ditambahkan')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _leaveGroup() async {
    await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).update({
      'members': FieldValue.arrayRemove([myUid]),
    });
    if (mounted) {
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  void _showAddMemberDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Anggota'),
        content: TextField(
          controller: _searchIdController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'JBchatluz ID', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          TextButton(
            onPressed: _isLoading ? null : _addMember,
            child: _isLoading ? const CircularProgressIndicator() : const Text('Tambah'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : Colors.white,
      appBar: AppBar(
        title: const Text('Info Grup'),
        backgroundColor: isDark ? const Color(0xFF1F2C34) : const Color(0xFF075E54),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (!snapshot.data!.exists) return const Center(child: Text('Grup tidak ditemukan'));

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final members = (data['members'] as List?) ?? [];
          final admins = (data['admins'] as List?) ?? [];
          final isAdmin = admins.contains(myUid);

          return ListView(
            children: [
              const SizedBox(height: 30),
              Center(
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: const Color(0xFF25D366),
                  child: const Icon(Icons.group, size: 60, color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              Center(child: Text(widget.roomName, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor))),
              Center(child: Text('Grup', style: const TextStyle(color: Colors.grey))),
              
              const Divider(),
              ListTile(
                leading: const Icon(Icons.person_add, color: Color(0xFF25D366)),
                title: const Text('Tambah Anggota', style: TextStyle(color: Color(0xFF25D366))),
                onTap: _showAddMemberDialog,
              ),
              const Divider(),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('${members.length} Anggota', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
              ),

              // Daftar Anggota
              ...members.map((memberUid) {
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(memberUid).get(),
                  builder: (context, userSnap) {
                    if (!userSnap.hasData) return const SizedBox.shrink();
                    if (!userSnap.data!.exists) return const SizedBox.shrink();

                    final userData = userSnap.data!.data() as Map<String, dynamic>;
                    final name = userData['displayName'] ?? 'Pengguna';
                    final jbId = userData['jbId'] ?? '';
                    final isMe = memberUid == myUid;
                    final isMemberAdmin = admins.contains(memberUid);

                    ImageProvider? avatar;
                    if (userData['photoBase64'] != null && userData['photoBase64'].toString().isNotEmpty) {
                      avatar = MemoryImage(base64Decode(userData['photoBase64']));
                    }

                    return ListTile(
                      leading: CircleAvatar(backgroundImage: avatar, backgroundColor: Colors.grey, child: avatar == null ? const Icon(Icons.person, color: Colors.white) : null),
                      title: Text(isMe ? 'Anda' : name, style: TextStyle(color: textColor)),
                      subtitle: Text(jbId, style: const TextStyle(color: Colors.grey)),
                      trailing: isMemberAdmin ? const Text('Admin', style: TextStyle(color: Color(0xFF25D366), fontSize: 12)) : null,
                    );
                  },
                );
              }),

              const Divider(),
              ListTile(
                leading: const Icon(Icons.exit_to_app, color: Colors.red),
                title: const Text('Keluar dari Grup', style: TextStyle(color: Colors.red)),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Keluar dari grup?'),
                      content: const Text('Anda tidak akan menerima pesan dari grup ini lagi.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
                        TextButton(onPressed: () { Navigator.pop(context); _leaveGroup(); }, child: const Text('Keluar', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
