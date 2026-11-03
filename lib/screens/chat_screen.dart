import 'dart:io';
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
import 'contact_info_screen.dart';
import 'group_info_screen.dart'; // Import layar grup

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
  String _otherUid = "";
  
  // State Profil & Tipe Room
  String _otherName = "";
  String _otherPhoto = "";
  String _otherStatus = "";
  String _roomType = "private"; // <-- Variabel ini yang tadi hilang

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
        _roomType = 'global';
      });
      return;
    }

    final roomDoc = await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).get();
    if (roomDoc.exists) {
      final type = roomDoc.data()!['type'];
      setState(() => _roomType = type); // Set tipe room (private/group/channel)

      if (type == 'private') {
        final members = (roomDoc.data()!['members'] as List?) ?? [];
        _otherUid = members.firstWhere((id) => id != myUid, orElse: () => '');
        
        if (_otherUid.isNotEmpty) {
          FirebaseFirestore.instance.collection('users').doc(_otherUid).snapshots().listen((userDoc) {
            if (userDoc.exists && mounted) {
              final data = userDoc.data()!;
              setState(() {
                _otherName = data['displayName'] ?? data['email']?.split('@')[0] ?? widget.roomName;
                _otherPhoto = data['photoBase64'] ?? '';
                if (data['isOnline'] == true) { _otherStatus = 'Online'; } 
                else if (data['lastSeen'] != null) {
                  _otherStatus = 'Terakhir dilihat ${DateFormat('HH:mm').format((data['lastSeen'] as Timestamp).toDate())}';
                } else { _otherStatus = 'Offline'; }
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

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? media = await picker.pickImage(source: source, imageQuality: 70);
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

    final myDoc = await FirebaseFirestore.instance.collection('users').doc(myUid).get();
    final myBlocked = (myDoc.data()!['blockedUsers'] as List?) ?? [];
    if (myBlocked.contains(_otherUid)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Buka blokir kontak ini untuk mengirim pesan.')));
      return;
    }

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

  void _showMessageOptions(DocumentSnapshot doc, bool isMe) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.star_border),
                title: const Text('Beri Bintang'),
                onTap: () async {
                  await doc.reference.update({'isStarred': true});
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Hapus untuk Saya'),
                onTap: () async {
                  await doc.reference.update({'deletedFor': FieldValue.arrayUnion([myUid])});
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              if (isMe)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Hapus untuk Semua', style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    await doc.reference.delete();
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final emojis = ['😀', '😂', '🥰', '😎', '😭', '😡', '👍', '👎', '🙏', '🔥', '❤️', '💔', '🎉', '✨', '📷', '🎵'];
        return Container(
          height: 250, padding: const EdgeInsets.all(8),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8, mainAxisSpacing: 10, crossAxisSpacing: 10),
            itemCount: emojis.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () { _msgController.text += emojis[index]; Navigator.pop(context); },
                child: Center(child: Text(emojis[index], style: const TextStyle(fontSize: 28))),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ImageProvider? headerImage;
    if (_otherPhoto.isNotEmpty) headerImage = MemoryImage(base64Decode(_otherPhoto));

    return ValueListenableBuilder<Color>(
      valueListenable: bubbleColorNotifier,
      builder: (context, currentBubbleColor, child) {
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFEFEAE2),
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF1F2C34) : const Color(0xFF075E54),
            foregroundColor: Colors.white,
            title: InkWell(
              onTap: () {
                // LOGIKA KLIK JUDUL CHAT
                if (_roomType == 'group' || _roomType == 'channel') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => GroupInfoScreen(roomId: widget.roomId, roomName: widget.roomName)));
                } else if (_otherUid.isNotEmpty) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ContactInfoScreen(userId: _otherUid)));
                }
              },
              child: Row(
                children: [
                  CircleAvatar(radius: 20, backgroundImage: headerImage ?? const NetworkImage('https://i.pravatar.cc/150'), backgroundColor: Colors.grey[300]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_otherName.isNotEmpty ? _otherName : widget.roomName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        if (_otherStatus.isNotEmpty)
                          Text(_otherStatus, style: TextStyle(fontSize: 12, color: _otherStatus == 'Online' ? const Color(0xFF25D366) : Colors.white70)),
                      ],
                    ),
                  ),
                ],
              ),
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
                    
                    final docs = snapshot.data!.docs.where((doc) {
                      final deletedFor = (doc.data() as Map)['deletedFor'] as List?;
                      return deletedFor == null || !deletedFor.contains(myUid);
                    }).toList();

                    List<Widget> messageWidgets = [];
                    if (widget.roomId != 'global' && _roomType == 'private') {
                      messageWidgets.add(
                        Container(
                          margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(12),
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
                        if (index >= docs.length) return messageWidgets[index - docs.length];

                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final isMe = data['senderId'] == myUid;
                        final timestamp = data['timestamp'] != null ? DateFormat('HH:mm').format((data['timestamp'] as Timestamp).toDate()) : '';

                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: GestureDetector(
                            onLongPress: () => _showMessageOptions(doc, isMe),
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isMe ? (isDark ? const Color(0xFF005C4B) : currentBubbleColor) : (isDark ? const Color(0xFF202C33) : Colors.white),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isMe && widget.roomId != 'global' && _roomType != 'private')
                                    Text(data['senderName'], style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00A884))),
                                  if (data['type'] == 'image')
                                    ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(data['mediaUrl'], width: 220, fit: BoxFit.cover))
                                  else
                                    Text(data['text'] ?? '', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16)),
                                  
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(color: isDark ? const Color(0xFF1F2C34) : Colors.white, borderRadius: BorderRadius.circular(25)),
                        child: Row(
                          children: [
                            IconButton(icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.grey), onPressed: _showEmojiPicker),
                            Expanded(
                              child: TextField(
                                controller: _msgController,
                                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                                decoration: const InputDecoration(hintText: 'Ketik pesan', hintStyle: TextStyle(color: Colors.grey), border: InputBorder.none),
                              ),
                            ),
                            IconButton(icon: const Icon(Icons.attach_file, color: Colors.grey), onPressed: _isUploading ? null : () => _pickImage(ImageSource.gallery)),
                            IconButton(icon: const Icon(Icons.camera_alt_outlined, color: Colors.grey), onPressed: _isUploading ? null : () => _pickImage(ImageSource.camera)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: const Color(0xFF25D366),
                      radius: 24,
                      child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 20), onPressed: _isUploading ? null : _sendMessage),
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
