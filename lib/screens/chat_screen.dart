import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ChatScreen extends StatefulWidget {
  final String roomId;
  final String roomName;

  const ChatScreen({super.key, required this.roomId, required this.roomName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgController = TextEditingController();
  bool _isUploading = false;

  void _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    _msgController.clear();

    final user = FirebaseAuth.instance.currentUser;
    await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).collection('messages').add({
      'type': 'text',
      'text': text,
      'senderId': user?.uid,
      'senderName': user?.displayName ?? user?.email?.split('@')[0] ?? 'Anonim',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  void _sendImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final file = File(image.path);
      
      // 1. Upload ke Firebase Storage
      final ref = FirebaseStorage.instance.ref().child('chat_media/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(file);
      final downloadUrl = await ref.getDownloadURL();

      // 2. Simpan link ke Firestore
      await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).collection('messages').add({
        'type': 'image',
        'mediaUrl': downloadUrl,
        'text': '',
        'senderId': user?.uid,
        'senderName': user?.displayName ?? user?.email?.split('@')[0] ?? 'Anonim',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal upload: $e')));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.roomName)),
      body: Column(
        children: [
          if (_isUploading) const LinearProgressIndicator(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('rooms')
                  .doc(widget.roomId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Center(child: Text('Belum ada pesan.'));

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == FirebaseAuth.instance.currentUser?.uid;
                    final isImage = data['type'] == 'image';

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue.shade100 : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isMe)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(data['senderName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            if (isImage)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  data['mediaUrl'],
                                  width: 200,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const SizedBox(width: 200, height: 200, child: Center(child: CircularProgressIndicator()));
                                  },
                                ),
                              )
                            else
                              Text(data['text'] ?? ''),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.image, color: Colors.blue),
                    onPressed: _isUploading ? null : _sendImage,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      decoration: const InputDecoration(hintText: 'Ketik pesan...', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(onPressed: _isUploading ? null : _sendMessage, icon: const Icon(Icons.send)),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
