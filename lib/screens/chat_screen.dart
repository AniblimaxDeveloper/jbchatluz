import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
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
  String myUid = FirebaseAuth.instance.currentUser?.uid ?? "";
  
  // Profil Header
  String _otherName = "";
  String _otherPhoto = "";
  String _otherStatus = "";

  @override
  void initState() {
    super.initState();
    _loadReceiverProfile();
    _markMessagesAsRead();
  }

  Future<void> _loadReceiverProfile() async {
    if (widget.roomId == 'global') {
      setState(() {
        _otherName = widget.roomName;
        _otherStatus = 'Ruang publik';
      });
      return;
    }

    final roomDoc = await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).get();
    if (roomDoc.exists) {
      final type = roomDoc.data()!['type'];
      if (type == 'private') {
        final members = (roomDoc.data()!['members'] as List?) ?? [];
        final otherUid = members.firstWhere((id) => id != myUid, orElse: () => '');
        
        if (otherUid.isNotEmpty) {
          FirebaseFirestore.instance.collection('users').doc(otherUid).snapshots().listen((userDoc) {
            if (userDoc.exists && mounted) {
              final data = userDoc.data()!;
              setState(() {
                _otherName = data['displayName'] ?? data['email']?.split('@')[0] ?? widget.roomName;
                _otherPhoto = data['photoBase64'] ?? data['photoURL'] ?? '';
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
      } else {
        setState(() {
          _otherName = roomDoc.data()!['name'] ?? widget.roomName;
          _otherStatus = 'Grup';
        });
      }
    }
  }

  void _markMessagesAsRead() async {
    if (widget.roomId == 'global') return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('mod_hide_tick') ?? false) return;

    final snapshot = await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).collection('messages').where('senderId', isNotEqualTo: myUid).where('status', isEqualTo: 'sent').get();
    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshot.docs) { batch.update(doc.reference, {'status': 'read'}); }
    await batch.commit();
  }

  Future<void> _sendImage() async {
    final picker = ImagePicker();
    final XFile? media = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (media == null) return;

    setState(() => _isUploading = true);
    try {
      const String imgbbApiKey = String.fromEnvironment('IMGBB_API_KEY');
      final request = http.MultipartRequest('POST', Uri.parse('https://api.imgbb.com/1/upload?key=$imgbbApiKey'));
      request.files.add(await http.MultipartFile.fromPath('image', media.path));

      final response = await request.send();
      final jsonData = jsonDecode(await response.stream.bytesToString());
      
      if (jsonData['success'] == true) {
        await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).collection('messages').add({
          'type': 'image', 'mediaUrl': jsonData['data']['url'], 'text': '',
          'senderId': myUid, 'senderName': FirebaseAuth.instance.currentUser?.displayName ?? 'User',
          'timestamp': FieldValue.serverTimestamp(), 'status': 'sent',
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal upload: $e')));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    _msgController.clear();

    await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).collection('messages').add({
      'type': 'text', 'text': text, 'senderId': myUid,
      'senderName': FirebaseAuth.instance.currentUser?.displayName ?? 'User',
      'timestamp': FieldValue.serverTimestamp(), 'status': 'sent',
    });

    if (widget.roomId != 'global') {
      FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).update({
        'lastMessage': text, 'lastMessageTime': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Load Foto Profil Header
    ImageProvider? headerImage;
    if (_otherPhoto.isNotEmpty) {
      if (_otherPhoto.startsWith('http')) headerImage = NetworkImage(_otherPhoto);
      else headerImage = MemoryImage(base64Decode(_otherPhoto));
    }

    return ValueListenableBuilder<Color>(
      valueListenable: bubbleColorNotifier,
      builder: (context, currentBubbleColor, child) {
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFEFEAE2),
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF202C33) : const Color(0xFF075E54),
            foregroundColor: Colors.white,
            title: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: headerImage ?? const NetworkImage('https://i.pravatar.cc/150'),
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
          body: Column(
            children: [
              if (_isUploading) const LinearProgressIndicator(color: Color(0xFF25D366)),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).collection('messages').orderBy('timestamp', descending: true).snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final docs = snapshot.data!.docs;

                    // Pesan E2E
                    List<Widget> messageWidgets = [];
                    if (widget.roomId != 'global') {
                      messageWidgets.add(
                        Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: isDark ? const Color(0xFF182229) : const Color(0xFFFFF3C4), borderRadius: BorderRadius.circular(8)),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.lock, size: 14, color: Colors.grey),
                              SizedBox(width: 6),
                              Text('Pesan pribadi Anda terenkripsi secara end-to-end', style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                            ],
                          ),
                        )
                      );
                    }

                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      itemCount: docs.length + messageWidgets.length,
                      itemBuilder: (context, index) {
                        if (index >= docs.length) {
                          return messageWidgets[index - docs.length];
                        }

                        final data = docs[index].data() as Map<String, dynamic>;
                        final isMe = data['senderId'] == myUid;
                        final timestamp = data['timestamp'] != null ? DateFormat('HH:mm').format((data['timestamp'] as Timestamp).toDate()) : '';

                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isMe 
                                  ? (isDark ? const Color(0xFF005C4B) : currentBubbleColor)
                                  : (isDark ? const Color(0xFF202C33) : Colors.white),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isMe && widget.roomId != 'global')
                                  Text(data['senderName'], style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00A884))),
                                if (data['type'] == 'image')
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(data['mediaUrl'], width: 220, fit: BoxFit.cover),
                                  )
                                else
                                  Text(data['text'] ?? '', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16)),
                                
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(timestamp, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                    if (isMe) ...[
                                      const SizedBox(width: 4),
                                      Icon(Icons.done_all, size: 14, color: data['status'] == 'read' ? Colors.blue : Colors.grey),
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
                            IconButton(icon: const Icon(Icons.attach_file, color: Colors.grey), onPressed: _isUploading ? null : _sendImage),
                            Expanded(
                              child: TextField(
                                controller: _msgController,
                                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                                decoration: const InputDecoration(hintText: 'Ketik pesan', border: InputBorder.none),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: const Color(0xFF00A884),
                      radius: 26,
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white, size: 20),
                        onPressed: _isUploading ? null : _sendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
