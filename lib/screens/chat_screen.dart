import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
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
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String myUid = FirebaseAuth.instance.currentUser?.uid ?? "";
  
  bool _isAdmin = false;
  String _roomType = "group";
  bool _isSearching = false;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadRoomInfo();
    _markMessagesAsRead();
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

  Future<void> _loadRoomInfo() async {
    if (widget.roomId == 'global') return;
    final doc = await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _roomType = data['type'] ?? 'group';
        _isAdmin = (data['admins'] as List?)?.contains(myUid) ?? false;
      });
    }
  }

  // OPSI B: Kirim Foto Lewat ImgBB
  Future<void> _sendImage() async {
    final picker = ImagePicker();
    final XFile? media = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (media == null) return;

    setState(() => _isUploading = true);
    try {
      // GANTI DENGAN API KEY IMGBB ANDA
      const String imgbbApiKey = String.fromEnvironment('IMGBB_API_KEY');
      
      final request = http.MultipartRequest('POST', Uri.parse('https://api.imgbb.com/1/upload?key=$imgbbApiKey'));
      request.files.add(await http.MultipartFile.fromPath('image', media.path));

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonData = jsonDecode(responseData);
      
      if (jsonData['success'] == true) {
        final imageUrl = jsonData['data']['url'];
        
        await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).collection('messages').add({
          'type': 'image', 'mediaUrl': imageUrl, 'text': '',
          'senderId': myUid, 'senderName': FirebaseAuth.instance.currentUser?.displayName ?? 'User',
          'timestamp': FieldValue.serverTimestamp(), 'status': 'sent', 'isStarred': false,
        });

        if (widget.roomId != 'global') {
          FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).update({
            'lastMessage': '📷 Foto', 'lastMessageTime': FieldValue.serverTimestamp(),
          });
        }
      } else {
        throw Exception('ImgBB Error');
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
      'timestamp': FieldValue.serverTimestamp(), 'status': 'sent', 'isStarred': false,
    });

    if (widget.roomId != 'global') {
      FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).update({
        'lastMessage': text, 'lastMessageTime': FieldValue.serverTimestamp(),
      });
    }
  }

  // OPSI A: Toggle Bintang
  void _toggleStar(String docId, bool currentStatus) async {
    await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).collection('messages').doc(docId).update({'isStarred': !currentStatus});
    Navigator.pop(context);
  }

  void _showMessageOptions(DocumentSnapshot doc, Map<String, dynamic> data, bool isMe) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(data['isStarred'] == true ? Icons.star : Icons.star_border, color: Colors.orange),
                title: Text(data['isStarred'] == true ? 'Hapus Bintang' : 'Beri Bintang'),
                onTap: () => _toggleStar(doc.id, data['isStarred'] ?? false),
              ),
              if (isMe)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Hapus untuk Semua', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    doc.reference.delete();
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

    return ValueListenableBuilder<Color>(
      valueListenable: bubbleColorNotifier,
      builder: (context, currentBubbleColor, child) {
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFEFEAE2),
          appBar: AppBar(
            backgroundColor: const Color(0xFF075E54),
            foregroundColor: Colors.white,
            title: Text(widget.roomName),
            actions: [
              IconButton(icon: const Icon(Icons.videocam), onPressed: () {
                // OPSI C: Panggilan Video Grup
                Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(channelName: widget.roomId, isVideoCall: true)));
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
                    if (docs.isEmpty) return const Center(child: Text('Belum ada pesan.'));

                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final isMe = data['senderId'] == myUid;
                        final timestamp = data['timestamp'] != null ? DateFormat('HH:mm').format((data['timestamp'] as Timestamp).toDate()) : '';

                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: GestureDetector(
                            onLongPress: () => _showMessageOptions(doc, data, isMe),
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isMe 
                                    ? (isDark ? const Color(0xFF005C4B) : currentBubbleColor) // OPSI D: Warna Dinamis
                                    : (isDark ? const Color(0xFF202C33) : Colors.white),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isMe) Text(data['senderName'], style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00A884))),
                                  if (data['type'] == 'image')
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(data['mediaUrl'], width: 220, fit: BoxFit.cover),
                                    )
                                  else
                                    Text(data['text'] ?? '', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                                  
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (data['isStarred'] == true) const Icon(Icons.star, size: 14, color: Colors.orange),
                                      const SizedBox(width: 4),
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
