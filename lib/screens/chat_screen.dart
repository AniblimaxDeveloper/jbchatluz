import 'dart:io';
import 'dart:async';
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
import 'call_screen.dart';

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
  String? _wallpaperPath;
  String myUid = FirebaseAuth.instance.currentUser?.uid ?? "";

  // Profil Lawan Bicara (Untuk Chat Pribadi)
  String _otherName = "";
  String _otherPhoto = "";
  String _otherStatus = "";

  @override
  void initState() {
    super.initState();
    _loadWallpaper();
    _loadReceiverProfile();
    _markMessagesAsRead();
  }

  Future<void> _loadWallpaper() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _wallpaperPath = prefs.getString('wallpaper_path'));
  }

  Future<void> _loadReceiverProfile() async {
    if (widget.roomId == 'global') {
      setState(() {
        _otherName = widget.roomName;
        _otherPhoto = 'https://i.pravatar.cc/150?img=11';
        _otherStatus = 'Ruang publik';
      });
      return;
    }

    // Cari room untuk mendapatkan UID lawan bicara
    final roomDoc = await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).get();
    if (roomDoc.exists) {
      final members = (roomDoc.data()!['members'] as List?) ?? [];
      final otherUid = members.firstWhere((id) => id != myUid, orElse: () => '');
      
      if (otherUid.isNotEmpty) {
        // Dengarkan status online/offline secara real-time
        FirebaseFirestore.instance.collection('users').doc(otherUid).snapshots().listen((userDoc) {
          if (userDoc.exists && mounted) {
            final data = userDoc.data()!;
            setState(() {
              _otherName = data['displayName'] ?? data['email']?.split('@')[0] ?? widget.roomName;
              _otherPhoto = data['photoURL'] ?? 'https://i.pravatar.cc/150?img=12';
              if (data['isOnline'] == true) {
                _otherStatus = 'Online';
              } else if (data['lastSeen'] != null) {
                _otherStatus = 'Terakhir dilihat ${DateFormat('HH:mm').format((data['lastSeen'] as Timestamp).toDate())}';
              } else {
                _otherStatus = 'Offline';
              }
            });
          }
        });
      }
    }
  }

  void _markMessagesAsRead() async {
    if (widget.roomId == 'global') return;
    
    // Cek MOD Sembunyikan Centang Biru
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('mod_hide_tick') ?? false) return; // Jangan tandai dibaca

    final snapshot = await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).collection('messages').where('senderId', isNotEqualTo: myUid).where('status', isEqualTo: 'sent').get();
    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'status': 'read'});
    }
    await batch.commit();
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
      'status': 'sent',
    });

    if (widget.roomId != 'global') {
      FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).update({
        'lastMessage': text,
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
    }
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
      if (path != null) _uploadFile(File(path), 'audio');
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
        'senderName': user?.displayName ?? 'Anonim',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'sent',
      });

      if (widget.roomId != 'global') {
        FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).update({
          'lastMessage': type == 'image' ? '📷 Foto' : '🎤 Pesan Suara',
          'lastMessageTime': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal upload: $e')));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF202C33) : const Color(0xFF075E54),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: NetworkImage(_otherPhoto.isNotEmpty ? _otherPhoto : 'https://i.pravatar.cc/150'),
              backgroundColor: Colors.grey[300],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_otherName.isNotEmpty ? _otherName : widget.roomName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  if (_otherStatus.isNotEmpty)
                    Text(
                      _otherStatus, 
                      style: TextStyle(
                        fontSize: 12, 
                        color: _otherStatus == 'Online' ? const Color(0xFF25D366) : Colors.white70,
                        fontWeight: _otherStatus == 'Online' ? FontWeight.bold : FontWeight.normal
                      )
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.videocam), onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(channelName: widget.roomId, isVideoCall: true)));
          }),
          IconButton(icon: const Icon(Icons.call), onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(channelName: widget.roomId, isVideoCall: false)));
          }),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0B141A) : const Color(0xFFEFEAE2),
          image: _wallpaperPath != null ? DecorationImage(image: FileImage(File(_wallpaperPath!)), fit: BoxFit.cover, opacity: 0.2) : null,
        ),
        child: Column(
          children: [
            if (_isUploading) const LinearProgressIndicator(color: Color(0xFF25D366)),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).collection('messages').orderBy('timestamp', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF00A884)));
                  final docs = snapshot.data!.docs;

                  if (docs.isEmpty) return const Center(child: Text('Belum ada pesan.'));

                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final isMe = data['senderId'] == myUid;
                      final type = data['type'];
                      final timestamp = data['timestamp'] != null ? DateFormat('HH:mm').format((data['timestamp'] as Timestamp).toDate()) : '';

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isMe 
                                ? (isDark ? const Color(0xFF005C4B) : const Color(0xFFD9FDD3))
                                : (isDark ? const Color(0xFF202C33) : Colors.white),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(12),
                              topRight: const Radius.circular(12),
                              bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
                              bottomRight: isMe ? Radius.zero : const Radius.circular(12),
                            ),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 2, offset: const Offset(0, 1))]
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                Text(data['text'] ?? '', style: TextStyle(fontSize: 16, color: isDark ? Colors.white : Colors.black)),
                              
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(timestamp, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  if (isMe) ...[
                                    const SizedBox(width: 4),
                                    Icon(Icons.done_all, size: 16, color: data['status'] == 'read' ? Colors.blue : Colors.grey),
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
            
            Container(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(color: isDark ? const Color(0xFF202C33) : Colors.white, borderRadius: BorderRadius.circular(25)),
                      child: Row(
                        children: [
                          IconButton(icon: const Icon(Icons.camera_alt, color: Colors.grey), onPressed: _isUploading ? null : () => _pickMedia(ImageSource.camera)),
                          Expanded(
                            child: TextField(
                              controller: _msgController,
                              style: TextStyle(color: isDark ? Colors.white : Colors.black),
                              decoration: const InputDecoration(hintText: 'Ketik pesan', border: InputBorder.none),
                            ),
                          ),
                          IconButton(icon: const Icon(Icons.attach_file, color: Colors.grey), onPressed: _isUploading ? null : () => _pickMedia(ImageSource.gallery)),
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
