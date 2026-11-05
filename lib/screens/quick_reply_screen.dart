import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QuickReplyScreen extends StatefulWidget {
  const QuickReplyScreen({super.key});

  @override
  State<QuickReplyScreen> createState() => _QuickReplyScreenState();
}

class _QuickReplyScreenState extends State<QuickReplyScreen> {
  final String myUid = FirebaseAuth.instance.currentUser?.uid ?? "";

  void _addQuickReply(String shortcut, String message) async {
    if (shortcut.isEmpty || message.isEmpty) return;
    await FirebaseFirestore.instance.collection('users').doc(myUid).collection('quick_replies').add({
      'shortcut': shortcut.startsWith('/') ? shortcut : '/$shortcut',
      'message': message,
    });
  }

  void _showAddDialog() {
    final shortcutCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Balasan Cepat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: shortcutCtrl, decoration: const InputDecoration(labelText: 'Pintasan (contoh: /alamat)', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: messageCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Isi Pesan', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          TextButton(onPressed: () { _addQuickReply(shortcutCtrl.text.trim(), messageCtrl.text.trim()); Navigator.pop(context); }, child: const Text('Simpan')),
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
      appBar: AppBar(title: const Text('Balasan Cepat'), backgroundColor: const Color(0xFF075E54), foregroundColor: Colors.white),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(myUid).collection('quick_replies').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final replies = snapshot.data!.docs;
          if (replies.isEmpty) return const Center(child: Text('Belum ada balasan cepat.', style: TextStyle(color: Colors.grey)));

          return ListView.builder(
            itemCount: replies.length,
            itemBuilder: (context, index) {
              final data = replies[index].data() as Map<String, dynamic>;
              return ListTile(
                leading: const Icon(Icons.flash_on, color: Color(0xFF25D366)),
                title: Text(data['shortcut'] ?? '', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                subtitle: Text(data['message'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.grey : Colors.black54)),
                trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => replies[index].reference.delete()),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: _showAddDialog, backgroundColor: const Color(0xFF25D366), child: const Icon(Icons.add, color: Colors.white)),
    );
  }
}
