import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

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

  Future<void> _editGroupName(String currentName) async {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ganti Nama Grup'),
        content: TextField(controller: controller, decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).update({'name': controller.text.trim()});
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _changeGroupPhoto() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 10);
    if (image == null) return;

    setState(() => _isLoading = true);
    try {
      final bytes = await File(image.path).readAsBytes();
      final base64String = base64Encode(bytes);
      await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).update({'photoBase64': base64String});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto grup diubah!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
      await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).update({
        'members': FieldValue.arrayUnion([targetUid]),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Anggota ditambahkan')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeMember(String uid) async {
    await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).update({
      'members': FieldValue.arrayRemove([uid]),
      'admins': FieldValue.arrayRemove([uid]),
    });
  }

  Future<void> _makeAdmin(String uid) async {
    await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).update({
      'admins': FieldValue.arrayUnion([uid]),
    });
  }

  Future<void> _leaveGroup() async {
    await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).update({
      'members': FieldValue.arrayRemove([myUid]),
      'admins': FieldValue.arrayRemove([myUid]),
    });
    if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
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
          TextButton(onPressed: _isLoading ? null : _addMember, child: _isLoading ? const CircularProgressIndicator() : const Text('Tambah')),
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
          final groupPhoto = data['photoBase64'];
          final groupName = data['name'] ?? widget.roomName;

          ImageProvider? avatarImage;
          if (groupPhoto != null && groupPhoto.toString().isNotEmpty) {
            avatarImage = MemoryImage(base64Decode(groupPhoto));
          }

          return ListView(
            children: [
              const SizedBox(height: 30),
              Center(
                child: GestureDetector(
                  onTap: isAdmin ? _changeGroupPhoto : null,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: const Color(0xFF25D366),
                        backgroundImage: avatarImage,
                        child: avatarImage == null ? const Icon(Icons.group, size: 60, color: Colors.white) : null,
                      ),
                      if (isAdmin)
                        Positioned(
                          bottom: 0, right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt, color: Color(0xFF25D366), size: 20),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(groupName, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
                    if (isAdmin) IconButton(icon: const Icon(Icons.edit, size: 20, color: Colors.grey), onPressed: () => _editGroupName(groupName)),
                  ],
                ),
              ),
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

              ...members.map((memberUid) {
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(memberUid).get(),
                  builder: (context, userSnap) {
                    if (!userSnap.hasData || !userSnap.data!.exists) return const SizedBox.shrink();

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
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isMemberAdmin) const Text('Admin', style: TextStyle(color: Color(0xFF25D366), fontSize: 12)),
                          if (isAdmin && !isMe)
                            IconButton(
                              icon: const Icon(Icons.more_vert, size: 20),
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  builder: (context) => SafeArea(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (!isMemberAdmin)
                                          ListTile(
                                            leading: const Icon(Icons.star, color: Colors.blue),
                                            title: const Text('Jadikan Admin'),
                                            onTap: () { _makeAdmin(memberUid); Navigator.pop(context); },
                                          ),
                                        ListTile(
                                          leading: const Icon(Icons.person_remove, color: Colors.red),
                                          title: const Text('Keluarkan dari Grup', style: TextStyle(color: Colors.red)),
                                          onTap: () { _removeMember(memberUid); Navigator.pop(context); },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
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
