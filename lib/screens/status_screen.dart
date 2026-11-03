import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  final String myUid = FirebaseAuth.instance.currentUser?.uid ?? "";
  bool _isUploading = false;

  Future<void> _uploadStatus() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 20);
    if (image == null) return;

    setState(() => _isUploading = true);
    try {
      final bytes = await File(image.path).readAsBytes();
      final base64String = base64Encode(bytes);

      await FirebaseFirestore.instance.collection('statuses').add({
        'uid': myUid,
        'userName': FirebaseAuth.instance.currentUser?.displayName ?? 'User',
        'photoBase64': base64String,
        'timestamp': FieldValue.serverTimestamp(),
        'views': [], // Array untuk menyimpan UID yang melihat
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status diunggah!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _viewStatus(DocumentSnapshot doc, Map<String, dynamic> data) async {
    // Tandai sudah dilihat (jika belum)
    final views = (data['views'] as List?) ?? [];
    if (!views.contains(myUid)) {
      await doc.reference.update({
        'views': FieldValue.arrayUnion([myUid])
      });
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(data['userName'] ?? 'Status'),
            actions: [
              if (data['uid'] == myUid)
                IconButton(
                  icon: const Icon(Icons.remove_red_eye),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Dilihat oleh'),
                        content: Text('${views.length} orang telah melihat status ini.'),
                        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup'))],
                      ),
                    );
                  },
                )
            ],
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.memory(base64Decode(data['photoBase64'])),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Status', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
          ),
          
          // Status Saya (Tombol Tambah)
          ListTile(
            leading: Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey[300],
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: Color(0xFF25D366), shape: BoxShape.circle),
                    child: const Icon(Icons.add, size: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
            title: Text('Status Saya', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
            subtitle: Text('Ketuk untuk menambah pembaruan status', style: TextStyle(color: isDark ? Colors.grey : Colors.black54)),
            onTap: _isUploading ? null : _uploadStatus,
          ),
          const Divider(),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Pembaruan Terbaru', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.grey : Colors.black54)),
          ),

          // Daftar Status Orang Lain
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('statuses').orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final now = DateTime.now();
                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  if (data['uid'] == myUid) return false; // Jangan tampilkan status sendiri
                  
                  // Cek 24 Jam
                  final timestamp = (data['timestamp'] as Timestamp).toDate();
                  return now.difference(timestamp).inHours < 24;
                }).toList();

                if (docs.isEmpty) return const Center(child: Text('Belum ada pembaruan status.', style: TextStyle(color: Colors.grey)));

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final isViewed = (data['views'] as List).contains(myUid);
                    final time = DateFormat('HH:mm').format((data['timestamp'] as Timestamp).toDate());

                    return ListTile(
                      leading: CircleAvatar(
                        radius: 26,
                        backgroundColor: isViewed ? Colors.grey : const Color(0xFF25D366),
                        child: CircleAvatar(
                          radius: 23,
                          backgroundImage: MemoryImage(base64Decode(data['photoBase64'])),
                        ),
                      ),
                      title: Text(data['userName'] ?? 'User', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                      subtitle: Text(time, style: TextStyle(color: isDark ? Colors.grey : Colors.black54)),
                      onTap: () => _viewStatus(doc, data),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isUploading ? null : _uploadStatus,
        backgroundColor: const Color(0xFF25D366),
        child: _isUploading ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.camera_alt, color: Colors.white),
      ),
    );
  }
}
