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
import 'contact_info_screen.dart';

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
  
  Map<String, dynamic>? _replyingTo;
  bool _isAdmin = false;
  String _roomType = "group";
  bool _isSearching = false;
  String _searchQuery = "";
  bool _isOtherTyping = false;
  bool _isMeTyping = false;
  Timer? _typingTimer;

  // State Disappearing Messages (dalam milidetik)
  int _disappearingDuration = 0; 

  @override
  void initState() {
    super.initState();
    _loadWallpaper();
    _loadRoomInfo();
    _listenToTyping();
    _markMessagesAsRead();
  }

  void _listenToTyping() {
    if (widget.roomId == 'global') return;
    FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).snapshots().listen((snap) {
      if (snap.exists) {
        final data = snap.data()!;
        final myUid = FirebaseAuth.instance.currentUser?.uid;
        final typingUsers = data['typing'] as Map<String, dynamic>? ?? {};
        bool otherTyping = false;
        typingUsers.forEach((key, value) {
          if (key != myUid && value == true) otherTyping = true;
        });
        if (mounted) setState(() => _isOtherTyping = otherTyping);
      }
    });
  }

  void _onTextChanged(String text) {
    if (widget.roomId == 'global') return;
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

      _isMeTyping = true;
      FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).update({'typing.': true});
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _isMeTyping = false;
      FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).update({'typing.': false});
    });
  }

  void _markMessagesAsRead() async {
    if (widget.roomId == 'global') return;
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final snapshot = await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).collection('messages').where('senderId', isNotEqualTo: myUid).where('status', isEqualTo: 'sent').get();
    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'status': 'read'});
    }
    await batch.commit();
  }

  Future<void> _loadRoomInfo() async {
    if (widget.roomId == 'global') return;
    final doc = await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _roomType = data['type'] ?? 'group';
        _isAdmin = (data['admins'] as List?)?.contains(FirebaseAuth.instance.currentUser?.uid) ?? false;
        _disappearingDuration = data['disappearingDuration'] ?? 0;
      });
    }
  }

  Future<void> _loadWallpaper() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _wallpaperPath = prefs.getString('wallpaper_path');
    });
  }

  Future<void> _setDisappearingMessages(int durationInMillis) async {
    if (widget.roomId == 'global') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak bisa mengatur di Room Global')));
      return;
    }
    await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).update({
      'disappearingDuration': durationInMillis,
    });
    setState(() => _disappearingDuration = durationInMillis);
    if (mounted) Navigator.pop(context);
  }

  void _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    
    final replyData = _replyingTo;
    _msgController.clear();
    setState(() => _replyingTo = null);

    final user = FirebaseAuth.instance.currentUser;
    
    // Hitung waktu kedaluwarsa
    Timestamp? expiresAt;
    if (_disappearingDuration > 0) {
      expiresAt = Timestamp.fromDate(DateTime.now().add(Duration(milliseconds: _disappearingDuration)));
    }

    await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).collection('messages').add({
      'type': 'text',
      'text': text,
      'senderId': user?.uid,
      'senderName': user?.displayName ?? user?.email?.split('@')[0] ?? 'Anonim',
      'timestamp': FieldValue.serverTimestamp(),
      'replyTo': replyData,
      'reactions': {},
      'status': 'sent',
      'expiresAt': expiresAt,
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

      Timestamp? expiresAt;
      if (_disappearingDuration > 0) {
        expiresAt = Timestamp.fromDate(DateTime.now().add(Duration(milliseconds: _disappearingDuration)));
      }

      await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).collection('messages').add({
        'type': type,
        'mediaUrl': downloadUrl,
        'text': '',
        'senderId': user?.uid,
        'senderName': user?.displayName ?? user?.email?.split('@')[0] ?? 'Anonim',
        'timestamp': FieldValue.serverTimestamp(),
        'reactions': {},
      'status': 'sent',
        'expiresAt': expiresAt,
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

  void _addReaction(String messageId, String emoji) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('messages')
        .doc(messageId)
        .update({'reactions.${user.uid}': emoji});
  }

  void _deleteMessage(String messageId) async {
    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  Future<void> _clearChat() async {
    final snapshot = await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).collection('messages').get();
    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Riwayat chat dibersihkan.')));
    }
  }

  void _showMessageOptions(DocumentSnapshot doc, Map<String, dynamic> data, bool isMe) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ['❤️', '👍', '😂', '😮', '😢', '🙏'].map((emoji) {
                    return GestureDetector(
                      onTap: () {
                        _addReaction(doc.id, emoji);
                        Navigator.pop(context);
                      },
                      child: Text(emoji, style: const TextStyle(fontSize: 28)),
                    );
                  }).toList(),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('Balas'),
                onTap: () {
                  setState(() {
                    _replyingTo = {
                      'text': data['type'] == 'text' ? data['text'] : 'Media',
                      'senderName': data['senderName']
                    };
                  });
                  Navigator.pop(context);
                },
              ),
              if (isMe)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Hapus untuk Semua', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    _deleteMessage(doc.id);
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF202C33) : const Color(0xFF075E54),
        foregroundColor: Colors.white,
        title: InkWell(
          onTap: () {
            if (widget.roomId != 'global' && _roomType != 'group' && _roomType != 'channel') {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ContactInfoScreen(userId: widget.roomId, fallbackName: widget.roomName)));
            }
          },
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white24,
                child: Text(widget.roomName[0], style: const TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.roomName, style: const TextStyle(fontSize: 18)),
                  if (_isOtherTyping)
                    const Text('sedang mengetik...', style: TextStyle(fontSize: 12, color: Colors.white70, fontStyle: FontStyle.italic))
                  else if (_disappearingDuration > 0)
                    const Text('🕒 Pesan sementara aktif', style: TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(icon: Icon(_isSearching ? Icons.close : Icons.search), onPressed: () {
            setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) _searchQuery = "";
            });
          }),
          IconButton(icon: const Icon(Icons.videocam), onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(channelName: widget.roomId, isVideoCall: true)));
          }),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') _clearChat();
            },
            itemBuilder: (context) => [
              if (widget.roomId != 'global')
                PopupMenuItem(
                  value: 'disappearing',
                  child: const Text('Pesan Sementara'),
                  onTap: () {
                    // Dialog untuk memilih durasi
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Pesan Sementara'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(title: const Text('Nonaktifkan'), onTap: () => _setDisappearingMessages(0)),
                            ListTile(title: const Text('1 Menit'), onTap: () => _setDisappearingMessages(60000)),
                            ListTile(title: const Text('1 Jam'), onTap: () => _setDisappearingMessages(3600000)),
                            ListTile(title: const Text('1 Hari'), onTap: () => _setDisappearingMessages(86400000)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              const PopupMenuItem(value: 'clear', child: Text('Bersihkan Chat')),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0B141A) : const Color(0xFFEFEAE2),
          image: _wallpaperPath != null 
              ? DecorationImage(image: FileImage(File(_wallpaperPath!)), fit: BoxFit.cover, opacity: 0.5)
              : null,
        ),
        child: Column(
          children: [
            if (_isSearching)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: isDark ? const Color(0xFF202C33) : Colors.white,
                child: TextField(
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    hintText: 'Cari pesan...',
                    hintStyle: TextStyle(color: isDark ? Colors.grey : Colors.black54),
                    border: InputBorder.none,
                    filled: true,
                    fillColor: isDark ? Colors.black26 : Colors.grey[200],
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                ),
              ),
            if (_isUploading) const LinearProgressIndicator(color: Color(0xFF25D366)),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).collection('messages').orderBy('timestamp', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  
                  final now = DateTime.now();
                  
                  // Filter Pencarian & Disappearing Messages
                  final docs = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    
                    // Cek Kedaluwarsa
                    if (data['expiresAt'] != null) {
                      final expiresAt = (data['expiresAt'] as Timestamp).toDate();
                      if (now.isAfter(expiresAt)) {
                        // Hapus pesan secara diam-diam jika waktu habis
                        doc.reference.delete();
                        return false;
                      }
                    }

                    // Cek Pencarian
                    if (_searchQuery.isEmpty) return true;
                    final text = data['text']?.toString().toLowerCase() ?? '';
                    return text.contains(_searchQuery);
                  }).toList();

                  if (docs.isEmpty) return const Center(child: Text('Pesan tidak ditemukan.'));

                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final isMe = data['senderId'] == myUid;
                      final type = data['type'];
                      final timestamp = data['timestamp'] != null ? DateFormat('HH:mm').format((data['timestamp'] as Timestamp).toDate()) : '';
                      final replyTo = data['replyTo'];
                      final reactions = data['reactions'] as Map<String, dynamic>? ?? {};

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: GestureDetector(
                          onLongPress: () => _showMessageOptions(doc, data, isMe),
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
                                if (replyTo != null)
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.black26 : Colors.black12,
                                      borderRadius: BorderRadius.circular(8),
                                      border: const Border(left: BorderSide(color: Color(0xFF00A884), width: 4)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(replyTo['senderName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF00A884))),
                                        Text(replyTo['text'], maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87)),
                                      ],
                                    ),
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
                                    if (data['expiresAt'] != null)
                                      const Padding(
                                        padding: EdgeInsets.only(right: 4),
                                        child: Icon(Icons.timer, size: 12, color: Colors.grey),
                                      ),
                                    Text(timestamp, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    if (isMe) ...[
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.done_all, 
                                        size: 16, 
                                        color: data['status'] == 'read' ? Colors.blue : Colors.grey,
                                      ),
                                    ]
                                  ],
                                ),
                                if (reactions.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Wrap(
                                      spacing: 4,
                                      children: reactions.values.map((emoji) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: isDark ? Colors.black45 : Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade400)),
                                        child: Text(emoji, style: const TextStyle(fontSize: 12)),
                                      )).toList(),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            
            if (_roomType == 'channel' && !_isAdmin)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: isDark ? const Color(0xFF202C33) : Colors.grey[200],
                child: Text(
                  'Hanya admin yang dapat mengirim pesan di saluran ini',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: isDark ? Colors.grey : Colors.black54, fontStyle: FontStyle.italic),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    if (_replyingTo != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: isDark ? const Color(0xFF202C33) : Colors.white, borderRadius: BorderRadius.circular(10)),
                        child: Row(
                          children: [
                            const Icon(Icons.reply, color: Color(0xFF00A884)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_replyingTo!['senderName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF00A884))),
                                  Text(_replyingTo!['text'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
                                ],
                              ),
                            ),
                            IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => setState(() => _replyingTo = null)),
                          ],
                        ),
                      ),
                    Row(
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
                                    onChanged: _onTextChanged,
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
