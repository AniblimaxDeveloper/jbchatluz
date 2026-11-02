import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  bool _isUploading = false;

  Future<void> _uploadStatus() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image == null) return;

    setState(() => _isUploading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final ref = FirebaseStorage.instance.ref().child('statuses/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(File(image.path));
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('statuses').add({
        'userId': user?.uid,
        'userName': user?.displayName ?? 'User',
        'imageUrl': url,
        'timestamp': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status berhasil diunggah!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Status'),
        actions: [
          IconButton(icon: const Icon(Icons.camera_alt), onPressed: _uploadStatus),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('statuses').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('Belum ada status hari ini.'));

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF00A884),
                  radius: 24,
                  child: Text(data['userName'][0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                ),
                title: Text(data['userName']),
                subtitle: const Text('Baru saja'),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      child: Image.network(data['imageUrl'], fit: BoxFit.cover),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isUploading ? null : _uploadStatus,
        backgroundColor: const Color(0xFF00A884),
        child: _isUploading ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
