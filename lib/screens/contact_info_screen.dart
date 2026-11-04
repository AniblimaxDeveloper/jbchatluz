import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ContactInfoScreen extends StatefulWidget {
  final String userId;
  const ContactInfoScreen({super.key, required this.userId});

  @override
  State<ContactInfoScreen> createState() => _ContactInfoScreenState();
}

class _ContactInfoScreenState extends State<ContactInfoScreen> {
  final String myUid = FirebaseAuth.instance.currentUser?.uid ?? "";
  bool _isBlocked = false;
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _checkBlockStatus(); }

  Future<void> _checkBlockStatus() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(myUid).get();
    if (doc.exists) {
      final blocked = (doc.data()!['blockedUsers'] as List?) ?? [];
      setState(() { _isBlocked = blocked.contains(widget.userId); _isLoading = false; });
    }
  }

  Future<void> _toggleBlock() async {
    final docRef = FirebaseFirestore.instance.collection('users').doc(myUid);
    if (_isBlocked) {
      await docRef.update({'blockedUsers': FieldValue.arrayRemove([widget.userId])});
      setState(() => _isBlocked = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kontak dibuka blokirnya')));
    } else {
      await docRef.update({'blockedUsers': FieldValue.arrayUnion([widget.userId])});
      setState(() => _isBlocked = true);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kontak diblokir')));
    }
  }

  void _editNickname(String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ubah Nama Kontak'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Nama Panggilan', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await FirebaseFirestore.instance.collection('users').doc(myUid).update({
                  'nicknames.${widget.userId}': controller.text.trim(),
                });
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Simpan'),
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
      appBar: AppBar(title: const Text('Info Kontak'), backgroundColor: isDark ? const Color(0xFF1F2C34) : const Color(0xFF075E54), foregroundColor: Colors.white),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(widget.userId).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: Text('Pengguna tidak ditemukan'));
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final name = data['displayName'] ?? 'Pengguna';
          final email = data['email'] ?? '';
          final jbId = data['jbId'] ?? '';
          final about = data['about'] ?? 'Tersedia';
          ImageProvider? avatar;
          if (data['photoBase64'] != null && data['photoBase64'].toString().isNotEmpty) { avatar = MemoryImage(base64Decode(data['photoBase64'])); } 
          else if (data['photoURL'] != null && data['photoURL'].toString().isNotEmpty) { avatar = NetworkImage(data['photoURL']); }

          return ListView(
            children: [
              const SizedBox(height: 30),
              Center(child: CircleAvatar(radius: 70, backgroundImage: avatar ?? const NetworkImage('https://i.pravatar.cc/150'), backgroundColor: Colors.grey[300])),
              const SizedBox(height: 20),
              Center(child: Text(name, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor))),
              const SizedBox(height: 8),
              Center(child: Text(email, style: const TextStyle(fontSize: 16, color: Colors.grey))),
              const SizedBox(height: 24),
              const Divider(),
              ListTile(leading: const Icon(Icons.info_outline, color: Colors.grey), title: Text('Tentang', style: TextStyle(color: Colors.grey, fontSize: 14)), subtitle: Text(about, style: TextStyle(color: textColor, fontSize: 16))),
              ListTile(leading: const Icon(Icons.alternate_email, color: Colors.grey), title: Text('JBchatluz ID', style: TextStyle(color: Colors.grey, fontSize: 14)), subtitle: Text(jbId, style: TextStyle(color: textColor, fontSize: 16))),
              ListTile(leading: const Icon(Icons.edit, color: Colors.blue), title: const Text('Ubah Nama Kontak', style: TextStyle(color: Colors.blue)), onTap: () => _editNickname(name)),
              const Divider(),
              ListTile(leading: Icon(_isBlocked ? Icons.lock_open : Icons.block, color: Colors.red), title: Text(_isBlocked ? 'Buka Blokir Kontak' : 'Blokir Kontak', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)), onTap: () { showDialog(context: context, builder: (context) => AlertDialog(title: Text(_isBlocked ? 'Buka blokir?' : 'Blokir kontak?'), content: Text(_isBlocked ? 'Anda akan bisa menerima pesan dari kontak ini.' : 'Kontak ini tidak akan bisa mengirim pesan kepada Anda.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')), TextButton(onPressed: () { _toggleBlock(); Navigator.pop(context); }, child: Text(_isBlocked ? 'Buka Blokir' : 'Blokir'))])); }),
            ],
          );
        },
      ),
    );
  }
}
