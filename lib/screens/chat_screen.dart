import "call_screen.dart";
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isTyping = false;
  String? _wallpaperPath;

  Future<void> _loadWallpaper() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _wallpaperPath = prefs.getString('wallpaper_path');
    });
  }

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
      'status': 'sent', // Status untuk centang
    });
  }

  void _pickMedia(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? media = await picker.pickImage(source: source, imageQuality: 70);
    if (media == null) return;
    _uploadFile(File(media.path), 'image');
  }

  Future<void> _startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _recorder.start(const RecordConfig(), path: path);
        setState(() => _isRecording = true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal merekam: $e')));
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _recorder.stop();
      setState(() => _isRecording = false);
      if (path != null) {
        _uploadFile(File(path), 'audio');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
    }
  }

  void _uploadFile(File file, String type) async {
    setState(() => _isUploading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final ext = type == 'image' ? 'jpg' : 'm4a';
      final ref = FirebaseStorage.instance.ref().child('chat_media/${DateTime.now().millisecondsSinceEpoch}.$ext');
      await ref.putFile(file);
      final downloadUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).collection('messages').add({
        'type': type,
        'mediaUrl': downloadUrl,
        'text': '',
        'senderId': user?.uid,
        'senderName': user?.displayName ?? user?.email?.split('@')[0] ?? 'Anonim',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'sent',
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
      backgroundColor: Colors.transparent, // Background chat khas WhatsApp
      appBar: AppBar(
        backgroundColor: const Color(0xFF075E54),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white24,
              child: Text(widget.roomName[0], style: const TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.roomName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (_isTyping) // Indikator sedang mengetik
                  const Text('sedang mengetik...', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.videocam), onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(channelName: widget.roomId, isVideoCall: true))); }),
          IconButton(icon: const Icon(Icons.call), onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(channelName: widget.roomId, isVideoCall: false))); }),
          PopupMenuButton<String>(
            onSelected: (value) {},
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'info', child: Text('Info Kontak')),
              const PopupMenuItem(value: 'clear', child: Text('Bersihkan Chat')),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFEFEAE2),
          image: _wallpaperPath != null 
              ? DecorationImage(image: FileImage(File(_wallpaperPath!)), fit: BoxFit.cover)
              : null,
        ),
        child: Column(
        children: [
          if (_isUploading) const LinearProgressIndicator(color: Color(0xFF25D366)),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).collection('messages').orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Center(child: Text('Belum ada pesan.'));

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == FirebaseAuth.instance.currentUser?.uid;
                    final type = data['type'];
                    final timestamp = data['timestamp'] != null ? DateFormat('HH:mm').format((data['timestamp'] as Timestamp).toDate()) : '';

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isMe ? const Color(0xFFD9FDD3) : Colors.white, // Warna bubble
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(12),
                            topRight: const Radius.circular(12),
                            bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
                            bottomRight: isMe ? Radius.zero : const Radius.circular(12),
                          ),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 2, offset: const Offset(0, 1))
                          ]
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!isMe)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(data['senderName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF00A884))),
                              ),
                            if (type == 'image')
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(data['mediaUrl'], width: 220, fit: BoxFit.cover),
                              )
                            else if (type == 'audio')
                              _buildAudioPlayer(data['mediaUrl'], isMe)
                            else
                              Text(data['text'] ?? '', style: const TextStyle(fontSize: 16)),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(timestamp, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                if (isMe) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.done_all, size: 16, color: Colors.blue), // Centang Biru
                                ]
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Kolom Ketik
          Container(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25)),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.grey),
                          onPressed: () {},
                        ),
                        Expanded(
                          child: TextField(
                            controller: _msgController,
                            decoration: const InputDecoration(hintText: 'Ketik pesan', border: InputBorder.none),
                            onChanged: (val) {
                              setState(() { _isTyping = val.isNotEmpty; });
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.attach_file, color: Colors.grey),
                          onPressed: _isUploading ? null : () => _pickMedia(ImageSource.gallery),
                        ),
                        IconButton(
                          icon: const Icon(Icons.camera_alt, color: Colors.grey),
                          onPressed: _isUploading ? null : () => _pickMedia(ImageSource.camera),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onLongPressStart: (_) => _startRecording(),
                  onLongPressEnd: (_) => _stopRecording(),
                  child: CircleAvatar(
                    backgroundColor: _isRecording ? Colors.red : const Color(0xFF00A884),
                    radius: 26,
                    child: Icon(_isRecording ? Icons.mic : Icons.mic_none, color: Colors.white),
                  ),
                ),
                if (!_isRecording) ...[
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: const Color(0xFF00A884),
                    radius: 26,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _isUploading ? null : _sendMessage,
                    ),
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildAudioPlayer(String url, bool isMe) {
    final player = AudioPlayer();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.play_circle_fill, color: isMe ? const Color(0xFF00A884) : Colors.blue, size: 36),
          onPressed: () async {
            if (player.state == PlayerState.playing) {
              await player.pause();
            } else {
              await player.play(UrlSource(url));
            }
          },
        ),
        const Text('Pesan Suara', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 15)),
      ],
    );
  }
}
