import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import '../main.dart';
import 'call_screen.dart';
import 'contact_info_screen.dart';
import 'group_info_screen.dart';
import 'forward_screen.dart';

class ChatScreen extends StatefulWidget {
  final String roomId;
  final String roomName;
  const ChatScreen({super.key, required this.roomId, required this.roomName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isUploading = false;
  String myUid = FirebaseAuth.instance.currentUser?.uid ?? "";
  String _otherUid = "";
  String _otherName = "";
  String _otherPhoto = "";
  String _otherStatus = "";
  String _roomType = "private";
  
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isAntiDelete = false;
  bool _isAutoReply = false;
  bool _antiViewOnce = false;
  Color _tickColor = Colors.blue;
  String _autoReplyMsg = "";
  StreamSubscription? _messageListener;
  StreamSubscription? _typingListener;
  StreamSubscription? _roomListener;
  int _disappearingDuration = 0;

  Map<String, dynamic>? _replyTo;
  Map<String, dynamic>? _pinnedMessage;
  bool _isOtherTyping = false;
  Timer? _typingTimer;
  bool _isMeTyping = false;
  bool _showScrollToBottom = false;
  
  bool _isBlockedByMe = false;
  bool _hasBlockedMe = false;

  @override
  void initState() {
    super.initState();
    _loadReceiverProfile();
    _markMessagesAsRead();
    _loadModSettings();
    _listenToTyping();
    _listenToRoomData();
    _checkBlockStatus();
    
    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        setState(() { _showScrollToBottom = _scrollController.offset > 500; });
      }
    });
  }

  @override
  void dispose() {
    _messageListener?.cancel();
    _typingListener?.cancel();
    _roomListener?.cancel();
    _typingTimer?.cancel();
    _recorder.dispose();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkBlockStatus() async {
    if (_otherUid.isEmpty) return;
    final myDoc = await FirebaseFirestore.instance.collection('users').doc(myUid).get();
    final otherDoc = await FirebaseFirestore.instance.collection('users').doc(_otherUid).get();
    final myBlocked = (myDoc.data()?['blockedUsers'] as List?) ?? [];
    final otherBlocked = (otherDoc.data()?['blockedUsers'] as List?) ?? [];
    setState(() { _isBlockedByMe = myBlocked.contains(_otherUid); _hasBlockedMe = otherBlocked.contains(myUid); });
  }

  void _listenToRoomData() {
    if (widget.roomId == 'global') return;
    _roomListener = FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).snapshots().listen((snap) {
      if (snap.exists) { final data = snap.data()!; setState(() { _pinnedMessage = data['pinnedMessage'] as Map<String, dynamic>?; }); }
    });
  }

  void _listenToTyping() {
    if (widget.roomId == 'global') return;
    _typingListener = FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).snapshots().listen((snap) {
      if (snap.exists) {
        final data = snap.data()!;
        final typingUsers = data['typing'] as Map<String, dynamic>? ?? {};
        bool otherTyping = false;
        typingUsers.forEach((key, value) { if (key != myUid && value == true) otherTyping = true; });
        if (mounted) setState(() => _isOtherTyping = otherTyping);
      }
    });
  }

  void _onTextChanged(String text) {
    if (widget.roomId == 'global' || _isBlockedByMe || _hasBlockedMe) return;
    if (!_isMeTyping && text.isNotEmpty) { _isMeTyping = true; FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).update({'typing.$myUid': true}); }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () { _isMeTyping = false; FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).update({'typing.$myUid': false}); });
  }

  Future<void> _loadModSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isAntiDelete = prefs.getBool('mod_anti_delete') ?? false;
      _isAutoReply = prefs.getBool('mod_auto_reply') ?? false;
      _antiViewOnce = prefs.getBool('mod_anti_viewonce') ?? false;
      _autoReplyMsg = prefs.getString('mod_auto_reply_msg') ?? 'Saya sedang sibuk.';
      final tickStr = prefs.getString('mod_tick_color') ?? 'blue';
      if (tickStr == 'blue') _tickColor = Colors.blue; else if (tickStr == 'grey') _tickColor = Colors.grey; else if (tickStr == 'purple') _tickColor = Colors.purple; else if (tickStr == 'green') _tickColor = Colors.green;
    });
    _setupAutoReply();
  }

  void _setupAutoReply() {
    if (!_isAutoReply) return;
    _messageListener = FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).collection('messages').orderBy('timestamp', descending: true).limit(1).snapshots().listen((snap) {
      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        if (data['senderId'] != myUid && data['type'] == 'text') {
           FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).collection('messages').add({'type': 'text', 'text': '🤖 [Auto-Reply]: $_autoReplyMsg', 'senderId': myUid, 'senderName': FirebaseAuth.instance.currentUser?.displayName ?? 'Bot', 'timestamp': FieldValue.serverTimestamp(), 'status': 'sent'});
        }
      }
    });
  }

  Future<void> _loadReceiverProfile() async {
    if (widget.roomId == 'global') { setState(() { _otherName = widget.roomName; _otherStatus = 'Ruang publik'; _roomType = 'global'; }); return; }
    final roomDoc = await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).get();
    if (roomDoc.exists) {
      final type = roomDoc.data()!['type'];
      setState(() { _roomType = type; _disappearingDuration = roomDoc.data()!['disappearingDuration'] ?? 0; });
      if (type == 'private') {
        final members = (roomDoc.data()!['members'] as List?) ?? [];
        _otherUid = members.firstWhere((id) => id != myUid, orElse: () => '');
        if (_otherUid.isNotEmpty) {
          FirebaseFirestore.instance.collection('users').doc(_otherUid).snapshots().listen((userDoc) {
            if (userDoc.exists && mounted) {
              final data = userDoc.data()!;
              setState(() {
                _otherName = data['displayName'] ?? data['email']?.split('@')[0] ?? widget.roomName;
                if (data['photoBase64'] != null && data['photoBase64'].toString().isNotEmpty) { _otherPhoto = data['photoBase64']; } else if (data['photoURL'] != null) { _otherPhoto = data['photoURL']; } else { _otherPhoto = ''; }
                if (data['isOnline'] == true) { _otherStatus = 'Online'; } else if (data['lastSeen'] != null) { _otherStatus = 'Terakhir dilihat ${DateFormat('HH:mm').format((data['lastSeen'] as Timestamp).toDate())}'; } else { _otherStatus = 'Offline'; }
              });
            }
          });
        }
      } else { setState(() { _otherName = roomDoc.data()!['name'] ?? widget.roomName; _otherStatus = 'Grup'; }); }
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

  void _setDisappearingMessages(int durationInMillis) async {
    if (widget.roomId == 'global') return;
    await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).update({'disappearingDuration': durationInMillis});
    setState(() => _disappearingDuration = durationInMillis);
  }

  void _logCall(bool isVideo) async { if (_otherUid.isNotEmpty) { await FirebaseFirestore.instance.collection('call_logs').add({'callerId': myUid, 'receiverId': _otherUid, 'type': isVideo ? 'video' : 'voice', 'status': 'outgoing', 'timestamp': FieldValue.serverTimestamp()}); } }

  Future<void> _clearChat() async {
    final snapshot = await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).collection('messages').get();
    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshot.docs) { batch.delete(doc.reference); }
    await batch.commit();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Riwayat chat dibersihkan.')));
  }

  Future<void> _exportChat() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).collection('messages').orderBy('timestamp', descending: false).get();
      String content = 'Ekspor Chat: ${widget.roomName}\n\n';
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final time = data['timestamp'] != null ? DateFormat('dd/MM/yyyy HH:mm').format((data['timestamp'] as Timestamp).toDate()) : '';
        final sender = data['senderName'] ?? 'User';
        final text = data['type'] == 'text' ? data['text'] : '[Media: ${data['type']}]';
        content += '[$time] $sender: $text\n';
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/chat_export.txt');
      await file.writeAsString(content);
      await OpenFilex.open(file.path);
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal ekspor: $e'))); }
  }

  Future<void> _showAttachmentMenu() async {
    if (_isBlockedByMe || _hasBlockedMe) return;
    showModalBottomSheet(context: context, builder: (context) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.image, color: Colors.blue), title: const Text('Galeri / Foto'), onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery, false); }),
      ListTile(leading: const Icon(Icons.visibility, color: Colors.purple), title: const Text('Foto Sekali Lihat (View Once)'), onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery, true); }),
      ListTile(leading: const Icon(Icons.insert_drive_file, color: Colors.orange), title: const Text('Dokumen'), onTap: () { Navigator.pop(context); _pickDocument(); }),
      ListTile(leading: const Icon(Icons.location_on, color: Colors.red), title: const Text('Lokasi'), onTap: () { Navigator.pop(context); _shareLocation(); }),
      ListTile(leading: const Icon(Icons.bar_chart, color: Colors.purple), title: const Text('Polling (Voting)'), onTap: () { Navigator.pop(context); _createPoll(); }),
    ])));
  }

  Future<void> _pickDocument() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result == null) return;
    setState(() => _isUploading = true);
    try {
      File file = File(result.files.single.path!);
      String fileName = result.files.single.name;
      final ref = FirebaseStorage.instance.ref().child('chat_docs/${DateTime.now().millisecondsSinceEpoch}_$fileName');
      await ref.putFile(file);
      final downloadUrl = await ref.getDownloadURL();
      Timestamp? expiresAt; if (_disappearingDuration > 0) expiresAt = Timestamp.fromDate(DateTime.now().add(Duration(milliseconds: _disappearingDuration)));
      await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).collection('messages').add({'type': 'document', 'mediaUrl': downloadUrl, 'text': fileName, 'senderId': myUid, 'senderName': FirebaseAuth.instance.currentUser?.displayName ?? 'User', 'timestamp': FieldValue.serverTimestamp(), 'status': 'sent', 'expiresAt': expiresAt, 'replyTo': _replyTo});
      setState(() => _replyTo = null);
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal upload dokumen: $e'))); } finally { setState(() => _isUploading = false); }
  }

  Future<void> _shareLocation() async {
    setState(() => _isUploading = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) { permission = await Geolocator.requestPermission(); if (permission == LocationPermission.denied) throw Exception('Izin lokasi ditolak'); }
      Position position = await Geolocator.getCurrentPosition();
      String locationUrl = 'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';
      Timestamp? expiresAt; if (_disappearingDuration > 0) expiresAt = Timestamp.fromDate(DateTime.now().add(Duration(milliseconds: _disappearingDuration)));
      await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).collection('messages').add({'type': 'location', 'mediaUrl': locationUrl, 'text': '📍 Lokasi Saya', 'senderId': myUid, 'senderName': FirebaseAuth.instance.currentUser?.displayName ?? 'User', 'timestamp': FieldValue.serverTimestamp(), 'status': 'sent', 'expiresAt': expiresAt, 'replyTo': _replyTo});
      setState(() => _replyTo = null);
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengirim lokasi: $e'))); } finally { setState(() => _isUploading = false); }
  }

  Future<void> _pickImage(ImageSource source, bool isViewOnce) async {
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
        Timestamp? expiresAt; if (_disappearingDuration > 0) expiresAt = Timestamp.fromDate(DateTime.now().add(Duration(milliseconds: _disappearingDuration)));
        await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).collection('messages').add({'type': 'image', 'mediaUrl': jsonData['data']['url'], 'text': '', 'senderId': myUid, 'senderName': FirebaseAuth.instance.currentUser?.displayName ?? 'User', 'timestamp': FieldValue.serverTimestamp(), 'status': 'sent', 'expiresAt': expiresAt, 'replyTo': _replyTo, 'viewOnce': isViewOnce});
        setState(() => _replyTo = null);
      }
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal upload foto: $e'))); } finally { setState(() => _isUploading = false); }
  }

  Future<void> _startRecording() async {
    try { if (await _recorder.hasPermission()) { final dir = await getTemporaryDirectory(); final path = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a'; await _recorder.start(const RecordConfig(), path: path); setState(() => _isRecording = true); } } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal merekam: $e'))); }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _recorder.stop(); setState(() => _isRecording = false);
      if (path != null) {
        setState(() => _isUploading = true);
        final ref = FirebaseStorage.instance.ref().child('chat_audio/${DateTime.now().millisecondsSinceEpoch}.m4a'); await ref.putFile(File(path)); final url = await ref.getDownloadURL();
        Timestamp? expiresAt; if (_disappearingDuration > 0) expiresAt = Timestamp.fromDate(DateTime.now().add(Duration(milliseconds: _disappearingDuration)));
        await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).collection('messages').add({'type': 'audio', 'mediaUrl': url, 'text': '', 'senderId': myUid, 'senderName': FirebaseAuth.instance.currentUser?.displayName ?? 'User', 'timestamp': FieldValue.serverTimestamp(), 'status': 'sent', 'expiresAt': expiresAt, 'replyTo': _replyTo});
        setState(() => _replyTo = null);
      }
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal upload suara.'))); } finally { setState(() => _isUploading = false); }
  }

  void _sendMessage() async {
    if (_isBlockedByMe || _hasBlockedMe) return;
    final text = _msgController.text.trim(); if (text.isEmpty) return; _msgController.clear();
    Timestamp? expiresAt; if (_disappearingDuration > 0) expiresAt = Timestamp.fromDate(DateTime.now().add(Duration(milliseconds: _disappearingDuration)));
    await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).collection('messages').add({'type': 'text', 'text': text, 'senderId': myUid, 'senderName': FirebaseAuth.instance.currentUser?.displayName ?? 'User', 'timestamp': FieldValue.serverTimestamp(), 'status': 'sent', 'expiresAt': expiresAt, 'replyTo': _replyTo});
    if (widget.roomId != 'global') { FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).update({'lastMessage': text, 'lastMessageTime': FieldValue.serverTimestamp()}); }
    setState(() => _replyTo = null);
    _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  void _createPoll() {
    final questionController = TextEditingController(); final optionAController = TextEditingController(); final optionBController = TextEditingController();
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text('Buat Voting'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: questionController, decoration: const InputDecoration(labelText: 'Pertanyaan')), const SizedBox(height: 8), TextField(controller: optionAController, decoration: const InputDecoration(labelText: 'Pilihan A')), const SizedBox(height: 8), TextField(controller: optionBController, decoration: const InputDecoration(labelText: 'Pilihan B'))]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')), TextButton(onPressed: () async { if (questionController.text.isNotEmpty && optionAController.text.isNotEmpty && optionBController.text.isNotEmpty) { await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).collection('messages').add({'type': 'poll', 'question': questionController.text, 'options': [optionAController.text, optionBController.text], 'votes': {}, 'senderId': myUid, 'senderName': FirebaseAuth.instance.currentUser?.displayName ?? 'User', 'timestamp': FieldValue.serverTimestamp(), 'status': 'sent', 'replyTo': _replyTo}); if (context.mounted) { Navigator.pop(context); setState(() => _replyTo = null); } } }, child: const Text('Kirim'))]));
  }

  void _votePoll(String docId, int optionIndex, Map<String, dynamic> votes) async { votes[myUid] = optionIndex; await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).collection('messages').doc(docId).update({'votes': votes}); }

  void _showMessageOptions(DocumentSnapshot doc, bool isMe, String text, Map<String, dynamic> data) {
    showModalBottomSheet(context: context, builder: (context) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: ['❤️', '👍', '😂', '😮', '😢', '🙏'].map((emoji) => GestureDetector(onTap: () async { final reactions = Map<String, dynamic>.from(data['reactions'] ?? {}); reactions[myUid] = emoji; await doc.reference.update({'reactions': reactions}); if (context.mounted) Navigator.pop(context); }, child: Text(emoji, style: const TextStyle(fontSize: 28)))).toList())),
      const Divider(),
      ListTile(leading: const Icon(Icons.push_pin, color: Colors.blue), title: const Text('Sematkan Pesan'), onTap: () async { await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).update({'pinnedMessage': {'text': text, 'senderName': data['senderName']}}); if (context.mounted) Navigator.pop(context); }),
      ListTile(leading: const Icon(Icons.reply), title: const Text('Balas'), onTap: () { setState(() => _replyTo = {'text': text, 'senderName': data['senderName']}); Navigator.pop(context); }),
      ListTile(leading: const Icon(Icons.forward), title: const Text('Teruskan'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => ForwardScreen(messageData: data))); }),
      ListTile(leading: const Icon(Icons.star_border), title: const Text('Beri Bintang'), onTap: () async { await doc.reference.update({'isStarred': true}); if (context.mounted) Navigator.pop(context); }),
      ListTile(leading: const Icon(Icons.delete_outline), title: const Text('Hapus untuk Saya'), onTap: () async { await doc.reference.update({'deletedFor': FieldValue.arrayUnion([myUid])}); if (context.mounted) Navigator.pop(context); }),
      if (isMe) ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text('Hapus untuk Semua', style: TextStyle(color: Colors.red)), onTap: () async { await doc.reference.update({'isDeleted': true, 'text': '🚫 Pesan ini telah dihapus'}); if (context.mounted) Navigator.pop(context); }),
    ])));
  }

  void _showEmojiPicker() {
    showModalBottomSheet(context: context, builder: (context) { final emojis = ['😀', '😂', '🥰', '😎', '😭', '😡', '👍', '👎', '🙏', '🔥', '❤️', '💔', '🎉', '✨', '📷', '🎵']; return Container(height: 250, padding: const EdgeInsets.all(8), child: GridView.builder(gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8, mainAxisSpacing: 10, crossAxisSpacing: 10), itemCount: emojis.length, itemBuilder: (context, index) => GestureDetector(onTap: () { _msgController.text += emojis[index]; Navigator.pop(context); }, child: Center(child: Text(emojis[index], style: const TextStyle(fontSize: 28)))))); });
  }

  void _openMediaViewer(String imageUrl, bool isViewOnce, DocumentSnapshot doc) {
    if (isViewOnce && !_antiViewOnce) { doc.reference.update({'mediaUrl': 'deleted', 'text': '📷 Foto sekali lihat telah dibuka'}); }
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(backgroundColor: Colors.black, appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text(isViewOnce ? 'Sekali Lihat' : 'Foto')), body: Center(child: InteractiveViewer(panEnabled: true, child: Image.network(imageUrl))))));
  }

  void _openDocument(String url) async { final file = await http.get(Uri.parse(url)); final dir = await getTemporaryDirectory(); final path = '${dir.path}/doc_${DateTime.now().millisecondsSinceEpoch}'; final f = File(path); await f.writeAsBytes(file.bodyBytes); await OpenFilex.open(path); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ImageProvider? headerImage;
    if (_otherPhoto.isNotEmpty) {
      if (_otherPhoto.startsWith('http')) { headerImage = NetworkImage(_otherPhoto); } else { headerImage = MemoryImage(base64Decode(_otherPhoto)); }
    }

    return ValueListenableBuilder<Color>(valueListenable: bubbleColorNotifier, builder: (context, currentBubbleColor, child) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFEFEAE2),
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF1F2C34) : const Color(0xFF075E54), foregroundColor: Colors.white,
          title: InkWell(
            onTap: () { if (_roomType == 'group' || _roomType == 'channel') { Navigator.push(context, MaterialPageRoute(builder: (_) => GroupInfoScreen(roomId: widget.roomId, roomName: widget.roomName))); } else if (_otherUid.isNotEmpty) { Navigator.push(context, MaterialPageRoute(builder: (_) => ContactInfoScreen(userId: _otherUid))); } },
            child: Row(children: [
              CircleAvatar(radius: 20, backgroundImage: headerImage ?? const NetworkImage('https://i.pravatar.cc/150'), backgroundColor: Colors.grey[300]),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_otherName.isNotEmpty ? _otherName : widget.roomName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (_isOtherTyping) const Text('sedang mengetik...', style: TextStyle(fontSize: 12, color: Colors.white70, fontStyle: FontStyle.italic))
                else if (_disappearingDuration > 0) const Text('🕒 Pesan sementara aktif', style: TextStyle(fontSize: 12, color: Colors.white70, fontStyle: FontStyle.italic))
                else if (_otherStatus.isNotEmpty) Text(_otherStatus, style: TextStyle(fontSize: 12, color: _otherStatus == 'Online' ? const Color(0xFF25D366) : Colors.white70)),
              ])),
            ]),
          ),
          actions: [
            PopupMenuButton<String>(icon: const Icon(Icons.timer), onSelected: (val) { if (val == '0') _setDisappearingMessages(0); if (val == '60000') _setDisappearingMessages(60000); if (val == '3600000') _setDisappearingMessages(3600000); if (val == '86400000') _setDisappearingMessages(86400000); }, itemBuilder: (context) => [const PopupMenuItem(value: '0', child: Text('Nonaktifkan')), const PopupMenuItem(value: '60000', child: Text('1 Menit')), const PopupMenuItem(value: '3600000', child: Text('1 Jam')), const PopupMenuItem(value: '86400000', child: Text('1 Hari'))]),
            IconButton(icon: const Icon(Icons.videocam), onPressed: () { if (!_isBlockedByMe && !_hasBlockedMe) { _logCall(true); Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(channelName: widget.roomId, isVideoCall: true))); } }),
            IconButton(icon: const Icon(Icons.call), onPressed: () { if (!_isBlockedByMe && !_hasBlockedMe) { _logCall(false); Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(channelName: widget.roomId, isVideoCall: false))); } }),
            PopupMenuButton<String>(icon: const Icon(Icons.more_vert), onSelected: (val) { if (val == 'export') _exportChat(); if (val == 'clear') _clearChat(); }, itemBuilder: (context) => [const PopupMenuItem(value: 'export', child: Text('Ekspor Chat')), const PopupMenuItem(value: 'clear', child: Text('Bersihkan Chat'))]),
          ],
        ),
        body: Column(children: [
          if (_isUploading) const LinearProgressIndicator(color: Color(0xFF25D366)),
          
          if (_pinnedMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), color: isDark ? const Color(0xFF1F2C34) : Colors.white,
              child: Row(children: [
                const Icon(Icons.push_pin, color: Color(0xFF25D366), size: 20), const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Pesan Disematkan', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF25D366), fontSize: 12)), Text(_pinnedMessage!['text'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13))])),
                IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () { FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).update({'pinnedMessage': FieldValue.delete()}); }),
              ]),
            ),

          Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).collection('messages').orderBy('timestamp', descending: true).snapshots(), builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final now = DateTime.now();
            final docs = snapshot.data!.docs.where((doc) { final data = doc.data() as Map<String, dynamic>; if (data['expiresAt'] != null) { final expiresAt = (data['expiresAt'] as Timestamp).toDate(); if (now.isAfter(expiresAt)) { doc.reference.delete(); return false; } } final deletedFor = (data['deletedFor'] as List?) ?? []; return !deletedFor.contains(myUid); }).toList();
            return ListView.builder(controller: _scrollController, reverse: true, padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8), itemCount: docs.length, itemBuilder: (context, index) {
              final doc = docs[index]; final data = doc.data() as Map<String, dynamic>;
              final isMe = data['senderId'] == myUid; final timestamp = data['timestamp'] != null ? DateFormat('HH:mm').format((data['timestamp'] as Timestamp).toDate()) : '';
              final isDeleted = data['isDeleted'] == true; final type = data['type'];
              final replyTo = data['replyTo']; final reactions = data['reactions'] as Map<String, dynamic>? ?? {};
              String displayText = data['text'] ?? '';
              if (isDeleted && !isMe) { displayText = _isAntiDelete ? '👻 [Anti-Delete]: $displayText' : '🚫 Pesan ini telah dihapus'; }
              
              return Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft, 
                child: GestureDetector(
                  onLongPress: () => _showMessageOptions(doc, isMe, displayText, data),
                  onHorizontalDragEnd: (details) { if (details.primaryVelocity! > 0) { setState(() => _replyTo = {'text': displayText, 'senderName': data['senderName']}); } },
                  child: Container(margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: isMe ? (isDark ? const Color(0xFF005C4B) : currentBubbleColor) : (isDark ? const Color(0xFF202C33) : Colors.white), borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (!isMe && widget.roomId != 'global' && _roomType != 'private') Text(data['senderName'], style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00A884))),
                  if (replyTo != null) Container(padding: const EdgeInsets.all(8), margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.black12, borderRadius: BorderRadius.circular(8), border: const Border(left: BorderSide(color: Color(0xFF00A884), width: 4))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(replyTo['senderName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF00A884))), Text(replyTo['text'], maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87))])),
                  if (type == 'image' && data['viewOnce'] == true) GestureDetector(onTap: () => _openMediaViewer(data['mediaUrl'], true, doc), child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)), child: const Row(children: [Icon(Icons.visibility, color: Colors.grey), SizedBox(width: 8), Text('Foto Sekali Lihat', style: TextStyle(fontStyle: FontStyle.italic))])))
                  else if (type == 'image') GestureDetector(onTap: () => _openMediaViewer(data['mediaUrl'], false, doc), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(data['mediaUrl'], width: 220, fit: BoxFit.cover)))
                  else if (type == 'audio') Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.play_circle_fill, color: isMe ? const Color(0xFF00A884) : Colors.blue, size: 36), const Text(' Pesan Suara')])
                  else if (type == 'location') GestureDetector(onTap: () => launchUrl(Uri.parse(data['mediaUrl'])), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)), child: Row(children: [const Icon(Icons.location_on, color: Colors.red), const SizedBox(width: 8), const Text('Lokasi Saya', style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline))])))
                  else if (type == 'document') GestureDetector(onTap: () => _openDocument(data['mediaUrl']), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)), child: Row(children: [const Icon(Icons.insert_drive_file, color: Colors.blue), const SizedBox(width: 8), Expanded(child: Text(displayText, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline)))])))
                  else if (type == 'poll') Container(width: 250, padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.black12, borderRadius: BorderRadius.circular(8)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(data['question'] ?? 'Voting', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)), const SizedBox(height: 8), ...List.generate(2, (i) { final options = List<String>.from(data['options'] ?? []); final votes = Map<String, dynamic>.from(data['votes'] ?? {}); final voteCount = votes.values.where((v) => v == i).length; final totalVotes = votes.length; final percentage = totalVotes == 0 ? 0.0 : (voteCount / totalVotes); return GestureDetector(onTap: () => _votePoll(doc.id, i, votes), child: Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: votes[myUid] == i ? const Color(0xFF25D366).withOpacity(0.3) : Colors.transparent, border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)), child: Stack(children: [Container(width: 200 * percentage, height: 20, color: const Color(0xFF25D366).withOpacity(0.2)), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(options[i], style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14)), Text('$voteCount', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold))])]))); })]))
                  else Text(displayText, style: TextStyle(color: isDeleted && !_isAntiDelete ? Colors.grey : (isDark ? Colors.white : Colors.black), fontStyle: isDeleted && !_isAntiDelete ? FontStyle.italic : FontStyle.normal, fontSize: 16)),
                  if (reactions.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Wrap(spacing: 4, children: reactions.values.map((emoji) => Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: isDark ? Colors.black45 : Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade400)), child: Text(emoji, style: const TextStyle(fontSize: 12)))).toList())),
                  Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.end, children: [if (data['expiresAt'] != null) const Icon(Icons.timer, size: 12, color: Colors.grey), const SizedBox(width: 4), Text(timestamp, style: const TextStyle(fontSize: 10, color: Colors.grey)), if (isMe) ...[const SizedBox(width: 4), Icon(Icons.done_all, size: 14, color: data['status'] == 'read' ? _tickColor : Colors.grey)]]),
                ]))),
              );
            });
          })),
          
          if (_isBlockedByMe || _hasBlockedMe)
            Container(width: double.infinity, padding: const EdgeInsets.all(16), color: isDark ? const Color(0xFF202C33) : Colors.grey[200], child: Text(_isBlockedByMe ? 'Anda telah memblokir kontak ini. Buka blokir di Info Kontak.' : 'Anda tidak dapat mengirim pesan ke kontak ini.', textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.grey : Colors.black54, fontStyle: FontStyle.italic)))
          else ...[
            if (_replyTo != null) Container(padding: const EdgeInsets.all(8), color: isDark ? const Color(0xFF1F2C34) : Colors.white, child: Row(children: [const Icon(Icons.reply, color: Color(0xFF00A884)), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_replyTo!['senderName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF00A884))), Text(_replyTo!['text'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87))])), IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => setState(() => _replyTo = null))])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: Container(decoration: BoxDecoration(color: isDark ? const Color(0xFF1F2C34) : Colors.white, borderRadius: BorderRadius.circular(25)), child: Row(children: [
                IconButton(icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.grey), onPressed: _showEmojiPicker),
                IconButton(icon: const Icon(Icons.attach_file, color: Colors.grey), onPressed: _isUploading ? null : _showAttachmentMenu),
                Expanded(child: TextField(controller: _msgController, onChanged: _onTextChanged, style: TextStyle(color: isDark ? Colors.white : Colors.black), decoration: const InputDecoration(hintText: 'Ketik pesan', hintStyle: TextStyle(color: Colors.grey), border: InputBorder.none))),
              ]))),
              const SizedBox(width: 8),
              GestureDetector(onLongPressStart: _msgController.text.isEmpty ? (_) => _startRecording() : null, onLongPressEnd: _msgController.text.isEmpty ? (_) => _stopRecording() : null, child: CircleAvatar(backgroundColor: _isRecording ? Colors.red : const Color(0xFF25D366), radius: 24, child: IconButton(icon: Icon(_isRecording ? Icons.mic : (_msgController.text.isEmpty ? Icons.mic : Icons.send), color: Colors.white, size: 20), onPressed: _isUploading ? null : (_msgController.text.isEmpty ? null : _sendMessage)))),
            ])),
          ],
        ]),
        floatingActionButton: _showScrollToBottom ? FloatingActionButton.small(onPressed: () { _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut); }, backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white, child: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF25D366))) : null,
      );
    });
  }
}
