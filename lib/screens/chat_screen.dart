import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:gal/gal.dart';
import '../main.dart';
import 'call_screen.dart';
import 'contact_info_screen.dart';
import 'group_info_screen.dart';
import 'forward_screen.dart';
import 'media_preview_screen.dart';

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
  final _searchController = TextEditingController();
  
  bool _isUploading = false;
  String myUid = FirebaseAuth.instance.currentUser?.uid ?? "";
  String _otherUid = "";
  String _otherName = "";
  String _otherPhoto = "";
  String _otherStatus = "";
  String _roomType = "private";
  String? _wallpaperPath;
  
  bool _isAdmin = false;
  bool _isAnnouncement = false;
  
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isAntiDelete = false;
  bool _isAutoReply = false;
  bool _antiViewOnce = false;
  bool _autoDownloadImage = true;
  bool _autoDownloadAudio = true;
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
  bool _isSearching = false;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadReceiverProfile();
    _markMessagesAsRead();
    _loadModSettings();
    _loadWallpaper();
    _listenToTyping();
    _listenToRoomData();
    _checkBlockStatus();
    
    _scrollController.addListener(() {
      if (_scrollController.hasClients) { setState(() { _showScrollToBottom = _scrollController.offset > 500; }); }
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
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadWallpaper() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() { _wallpaperPath = prefs.getString('wallpaper_${widget.roomId}') ?? prefs.getString('wallpaper_path'); });
  }

  Future<void> _pickWallpaper() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('wallpaper_${widget.roomId}', image.path);
      setState(() => _wallpaperPath = image.path);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Wallpaper diubah.")));
    }
  }

  Future<void> _downloadMedia(String url) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mengunduh media...')));
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        await Gal.putImageBytes(response.bodyBytes, name: 'jbchatluz_${DateTime.now().millisecondsSinceEpoch}');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Media berhasil disimpan ke Galeri!')));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal mengunduh media.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _openProfilePicture(String photoData) {
    if (photoData.isEmpty) return;
    ImageProvider imageProvider;
    if (photoData.startsWith('http')) { imageProvider = NetworkImage(photoData); } else { imageProvider = MemoryImage(base64Decode(photoData)); }

    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text(_otherName), actions: [
        IconButton(icon: const Icon(Icons.download), onPressed: () {
          if (photoData.startsWith('http')) _downloadMedia(photoData);
          else {
            Gal.putImageBytes(base64Decode(photoData), name: 'profile_${_otherUid}');
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto profil disimpan!')));
          }
        })
      ]),
      body: Center(child: InteractiveViewer(panEnabled: true, minScale: 0.5, maxScale: 4.0, child: Image(image: imageProvider))),
    )));
  }

  Future<void> _translateMessage(String text) async {
    showDialog(context: context, builder: (context) => const Center(child: CircularProgressIndicator()));
    try {
      final url = Uri.parse('https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=id&dt=t&q=${Uri.encodeComponent(text)}');
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final translated = data[0][0][0];
        if (mounted) { Navigator.pop(context); showDialog(context: context, builder: (context) => AlertDialog(title: const Text('Terjemahan (ID)'), content: Text(translated), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup'))])); }
      } else { if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menerjemahkan'))); } }
    } catch (e) { if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'))); } }
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
      if (snap.exists) {
        final data = snap.data()!;
        final admins = (data['admins'] as List?) ?? [];
        setState(() {
          _pinnedMessage = data['pinnedMessage'] as Map<String, dynamic>?;
          _isAdmin = admins.contains(myUid);
          _isAnnouncement = data['isAnnouncement'] ?? false;
        });
      }
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
      _autoDownloadImage = prefs.getBool('auto_download_image') ?? true;
      _autoDownloadAudio = prefs.getBool('auto_download_audio') ?? true;
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

  void _scheduleMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ketik pesan terlebih dahulu sebelum menjadwalkan.')));
      return;
    }
    DateTime selectedDate = DateTime.now().add(const Duration(minutes: 5));
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text('Jadwalkan Pesan'), content: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('Pilih waktu pengiriman pesan:'), const SizedBox(height: 16),
      ListTile(leading: const Icon(Icons.calendar_today), title: Text(DateFormat('dd MMM yyyy').format(selectedDate)), onTap: () async { final picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365))); if (picked != null) selectedDate = DateTime(picked.year, picked.month, picked.day, selectedDate.hour, selectedDate.minute); }),
      ListTile(leading: const Icon(Icons.access_time), title: Text(DateFormat('HH:mm').format(selectedDate)), onTap: () async { final picked = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(selectedDate)); if (picked != null) selectedDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, picked.hour, picked.minute); }),
    ]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')), TextButton(onPressed: () async { Navigator.pop(context); _msgController.clear(); await FirebaseFirestore.instance.collection('scheduled_messages').add({'roomId': widget.roomId, 'text': text, 'senderId': myUid, 'senderName': FirebaseAuth.instance.currentUser?.displayName ?? 'User', 'scheduledTime': Timestamp.fromDate(selectedDate), 'status': 'pending'}); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pesan dijadwalkan pada ${DateFormat('dd/MM HH:mm').format(selectedDate)}'))); }, child: const Text('Jadwalkan'))]));
  }

  // FITUR BARU: BALAS PRIBADI (REPLY PRIVATELY)
  Future<void> _replyPrivately(String senderId, String senderName) async {
    final roomQuery = await FirebaseFirestore.instance.collection('rooms')
        .where('type', isEqualTo: 'private')
        .where('members', arrayContains: myUid).get();

    String roomId = '';
    for (var doc in roomQuery.docs) {
      final members = doc.data()['members'] as List;
      if (members.contains(senderId)) { roomId = doc.id; break; }
    }

    if (roomId.isEmpty) {
      final newRoom = await FirebaseFirestore.instance.collection('rooms').add({
        'type': 'private', 'members': [myUid, senderId],
        'lastMessage': 'Chat pribadi dimulai', 'lastMessageTime': FieldValue.serverTimestamp(),
      });
      roomId = newRoom.id;
    }

    if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(roomId: roomId, roomName: senderName)));
  }

  // FITUR BARU: LIHAT SIAPA YANG MEMILIH POLLING
  void _showPollDetails(Map<String, dynamic> votes, int optionIndex, List<String> options) {
    final List<String> voters = [];
    votes.forEach((uid, voteIdx) { if (voteIdx == optionIndex) voters.add(uid); });

    showModalBottomSheet(context: context, builder: (context) {
      return SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.all(16), child: Text('Pemilih: ${options[optionIndex]}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
        const Divider(),
        if (voters.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Belum ada yang memilih opsi ini.')),
        ...voters.map((uid) => FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
          builder: (context, userSnap) {
            if (!userSnap.hasData) return const ListTile(title: Text('Memuat...'));
            final name = userSnap.data!.data() != null ? (userSnap.data!.data() as Map)['displayName'] ?? 'Pengguna' : 'Pengguna';
            return ListTile(leading: const Icon(Icons.person), title: Text(name));
          },
        )),
      ]));
    });
  }

  Future<void> _showAttachmentMenu() async {
    if (_isBlockedByMe || _hasBlockedMe) return;
    showModalBottomSheet(context: context, builder: (context) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.image, color: Colors.blue), title: const Text('Galeri / Foto'), onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery, false); }),
      ListTile(leading: const Icon(Icons.person, color: Colors.teal), title: const Text('Bagikan Kontak'), onTap: () { Navigator.pop(context); _showContactPicker(); }),
      ListTile(leading: const Icon(Icons.videocam, color: Colors.purple), title: const Text('Rekam Video Langsung'), onTap: () { Navigator.pop(context); _pickVideo(ImageSource.camera); }),
      ListTile(leading: const Icon(Icons.video_library, color: Colors.deepPurple), title: const Text('Video dari Galeri'), onTap: () { Navigator.pop(context); _pickVideo(ImageSource.gallery); }),
      ListTile(leading: const Icon(Icons.insert_drive_file, color: Colors.orange), title: const Text('Dokumen'), onTap: () { Navigator.pop(context); _pickDocument(); }),
      ListTile(leading: const Icon(Icons.location_on, color: Colors.red), title: const Text('Lokasi'), onTap: () { Navigator.pop(context); _shareLocation(); }),
      ListTile(leading: const Icon(Icons.bar_chart, color: Colors.purple), title: const Text('Polling (Voting)'), onTap: () { Navigator.pop(context); _createPoll(); }),
      ListTile(leading: const Icon(Icons.schedule, color: Colors.blueGrey), title: const Text('Jadwalkan Pesan'), onTap: () { Navigator.pop(context); _scheduleMessage(); }),
    ])));
  }

  void _showContactPicker() {
    showModalBottomSheet(context: context, builder: (context) {
      return StatefulBuilder(builder: (context, setModalState) {
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(myUid).get(),
          builder: (context, mySnap) {
            if (!mySnap.hasData) return const Center(child: CircularProgressIndicator());
            final List<String> contactUids = List<String>.from((mySnap.data!.data() as Map)['contacts'] ?? []);
            if (contactUids.isEmpty) return const Center(child: Text('Belum ada kontak.'));

            return ListView.builder(itemCount: contactUids.length, itemBuilder: (context, index) {
              final uid = contactUids[index];
              return FutureBuilder<DocumentSnapshot>(future: FirebaseFirestore.instance.collection('users').doc(uid).get(), builder: (context, userSnap) {
                if (!userSnap.hasData || !userSnap.data!.exists) return const SizedBox.shrink();
                final uData = userSnap.data!.data() as Map<String, dynamic>;
                final name = uData['displayName'] ?? 'Pengguna'; final jbId = uData['jbId'] ?? ''; final photo = uData['photoBase64'] ?? '';
                return ListTile(leading: CircleAvatar(backgroundImage: photo.isNotEmpty ? MemoryImage(base64Decode(photo)) : null, child: photo.isEmpty ? const Icon(Icons.person) : null), title: Text(name), subtitle: Text(jbId), onTap: () { Navigator.pop(context); _sendContact(uid, name, jbId, photo); });
              });
            });
          },
        );
      });
    });
  }

  Future<void> _sendContact(String uid, String name, String jbId, String photoBase64) async {
    Timestamp? expiresAt; if (_disappearingDuration > 0) expiresAt = Timestamp.fromDate(DateTime.now().add(Duration(milliseconds: _disappearingDuration)));
    await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).collection('messages').add({'type': 'contact', 'contactUid': uid, 'contactName': name, 'contactJbId': jbId, 'contactPhoto': photoBase64, 'text': '👤 Kontak', 'senderId': myUid, 'senderName': FirebaseAuth.instance.currentUser?.displayName ?? 'User', 'timestamp': FieldValue.serverTimestamp(), 'status': 'sent', 'expiresAt': expiresAt});
    if (widget.roomId != 'global') { FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).update({'lastMessage': '👤 Kontak', 'lastMessageTime': FieldValue.serverTimestamp()}); }
  }

  Future<void> _pickVideo(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: source, maxDuration: const Duration(minutes: 1));
    if (video == null) return;
    setState(() => _isUploading = true);
    try {
      final ref = FirebaseStorage.instance.ref().child('chat_videos/${DateTime.now().millisecondsSinceEpoch}.mp4');
      await ref.putFile(File(video.path));
      final downloadUrl = await ref.getDownloadURL();
      Timestamp? expiresAt; if (_disappearingDuration > 0) expiresAt = Timestamp.fromDate(DateTime.now().add(Duration(milliseconds: _disappearingDuration)));
      await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).collection('messages').add({'type': 'video', 'mediaUrl': downloadUrl, 'text': '', 'senderId': myUid, 'senderName': FirebaseAuth.instance.currentUser?.displayName ?? 'User', 'timestamp': FieldValue.serverTimestamp(), 'status': 'sent', 'expiresAt': expiresAt, 'replyTo': _replyTo});
      setState(() => _replyTo = null);
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal upload video. Pastikan Storage Blaze aktif.'))); } finally { setState(() => _isUploading = false); }
  }

  void _sendSticker(String stickerUrl) async {
    Timestamp? expiresAt; if (_disappearingDuration > 0) expiresAt = Timestamp.fromDate(DateTime.now().add(Duration(milliseconds: _disappearingDuration)));
    await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).collection('messages').add({'type': 'sticker', 'mediaUrl': stickerUrl, 'text': '', 'senderId': myUid, 'senderName': FirebaseAuth.instance.currentUser?.displayName ?? 'User', 'timestamp': FieldValue.serverTimestamp(), 'status': 'sent', 'expiresAt': expiresAt});
    if (widget.roomId != 'global') { FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).update({'lastMessage': 'Stiker', 'lastMessageTime': FieldValue.serverTimestamp()}); }
    Navigator.pop(context);
  }

  void _showStickerPicker() {
    final stickers = ['https://i.imgur.com/3h4k5qP.png', 'https://i.imgur.com/8QO2v9w.png', 'https://i.imgur.com/9Xz7l2b.png', 'https://i.imgur.com/K5zP4qJ.png'];
    showModalBottomSheet(context: context, builder: (context) { return Container(height: 250, padding: const EdgeInsets.all(8), child: GridView.builder(gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8), itemCount: stickers.length, itemBuilder: (context, index) => GestureDetector(onTap: () => _sendSticker(stickers[index]), child: Image.network(stickers[index], fit: BoxFit.contain)))); });
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
    Navigator.push(context, MaterialPageRoute(builder: (_) => MediaPreviewScreen(file: media, isViewOnce: isViewOnce, onSend: (caption) { Navigator.pop(context); _uploadImage(File(media.path), caption, isViewOnce); })));
  }

  Future<void> _uploadImage(File file, String caption, bool isViewOnce) async {
    setState(() => _isUploading = true);
    try {
      const String imgbbApiKey = String.fromEnvironment('IMGBB_API_KEY');
      final request = http.MultipartRequest('POST', Uri.parse('https://api.imgbb.com/1/upload?key=$imgbbApiKey'));
      request.files.add(await http.MultipartFile.fromPath('image', file.path));
      final response = await request.send();
      final jsonData = jsonDecode(await response.stream.bytesToString());
      if (jsonData['success'] == true) {
        Timestamp? expiresAt; if (_disappearingDuration > 0) expiresAt = Timestamp.fromDate(DateTime.now().add(Duration(milliseconds: _disappearingDuration)));
        await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).collection('messages').add({'type': 'image', 'mediaUrl': jsonData['data']['url'], 'text': caption, 'senderId': myUid, 'senderName': FirebaseAuth.instance.currentUser?.displayName ?? 'User', 'timestamp': FieldValue.serverTimestamp(), 'status': 'sent', 'expiresAt': expiresAt, 'replyTo': _replyTo, 'viewOnce': isViewOnce});
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

  void _editMessage(DocumentSnapshot doc, String currentText) {
    final controller = TextEditingController(text: currentText);
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text('Edit Pesan'), content: TextField(controller: controller, decoration: const InputDecoration(border: OutlineInputBorder())), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')), TextButton(onPressed: () async { if (controller.text.trim().isNotEmpty) { await doc.reference.update({'text': controller.text.trim(), 'isEdited': true}); if (context.mounted) Navigator.pop(context); } }, child: const Text('Simpan'))]));
  }

  void _showMessageInfo(DocumentSnapshot doc, Map<String, dynamic> data) {
    final time = data['timestamp'] != null ? DateFormat('dd/MM/yyyy HH:mm').format((data['timestamp'] as Timestamp).toDate()) : 'Tidak diketahui';
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text('Info Pesan'), content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [ListTile(leading: const Icon(Icons.done_all, color: Colors.blue), title: const Text('Dikirim'), subtitle: Text(time)), if (data['status'] == 'read') ListTile(leading: const Icon(Icons.done_all, color: Colors.blue), title: const Text('Dibaca'), subtitle: const Text('Baru saja'))]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup'))]));
  }

  void _showMessageOptions(DocumentSnapshot doc, bool isMe, String text, Map<String, dynamic> data) {
    showModalBottomSheet(context: context, builder: (context) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: ['❤️', '👍', '😂', '😮', '😢', '🙏'].map((emoji) => GestureDetector(onTap: () async { final reactions = Map<String, dynamic>.from(data['reactions'] ?? {}); reactions[myUid] = emoji; await doc.reference.update({'reactions': reactions}); if (context.mounted) Navigator.pop(context); }, child: Text(emoji, style: const TextStyle(fontSize: 28)))).toList())),
      const Divider(),
      // FITUR REPLY PRIVATELY DI GRUP
      if (widget.roomId != 'global' && _roomType != 'private' && !isMe)
        ListTile(leading: const Icon(Icons.person, color: Colors.blue), title: const Text('Balas Pribadi', style: TextStyle(color: Colors.blue)), onTap: () { Navigator.pop(context); _replyPrivately(data['senderId'], data['senderName']); }),
      
      ListTile(leading: const Icon(Icons.translate, color: Colors.teal), title: const Text('Terjemahkan ke ID', style: TextStyle(color: Colors.teal)), onTap: () { Navigator.pop(context); _translateMessage(text); }),
      ListTile(leading: const Icon(Icons.info_outline, color: Colors.blue), title: const Text('Info Pesan', style: TextStyle(color: Colors.blue)), onTap: () { Navigator.pop(context); _showMessageInfo(doc, data); }),
      if (isMe && data['type'] == 'text') ListTile(leading: const Icon(Icons.edit, color: Colors.blue), title: const Text('Edit Pesan', style: TextStyle(color: Colors.blue)), onTap: () { Navigator.pop(context); _editMessage(doc, text); }),
      if (data['type'] != 'text' && data['type'] != 'poll' && data['type'] != 'contact') ListTile(leading: const Icon(Icons.share, color: Colors.green), title: const Text('Bagikan ke...', style: TextStyle(color: Colors.green)), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => ForwardScreen(messageData: data))); }),
      ListTile(leading: const Icon(Icons.push_pin, color: Colors.blue), title: const Text('Sematkan Pesan'), onTap: () async { await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).update({'pinnedMessage': {'text': text, 'senderName': data['senderName']}}); if (context.mounted) Navigator.pop(context); }),
      ListTile(leading: const Icon(Icons.reply), title: const Text('Balas'), onTap: () { setState(() => _replyTo = {'text': text, 'senderName': data['senderName']}); Navigator.pop(context); }),
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
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
      backgroundColor: Colors.black, 
      appBar: AppBar(
        backgroundColor: Colors.black, 
        foregroundColor: Colors.white, 
        title: Text(isViewOnce ? 'Sekali Lihat' : 'Foto'),
        actions: [
          IconButton(icon: const Icon(Icons.download), onPressed: () => _downloadMedia(imageUrl)),
        ],
      ), 
      body: Center(child: InteractiveViewer(panEnabled: true, child: Image.network(imageUrl)))
    )));
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
          title: _isSearching 
            ? TextField(controller: _searchController, autofocus: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'Cari pesan...', hintStyle: TextStyle(color: Colors.white70), border: InputBorder.none), onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()))
            : InkWell(
                onTap: () { if (_roomType == 'group' || _roomType == 'channel') { Navigator.push(context, MaterialPageRoute(builder: (_) => GroupInfoScreen(roomId: widget.roomId, roomName: widget.roomName))); } else if (_otherUid.isNotEmpty) { Navigator.push(context, MaterialPageRoute(builder: (_) => ContactInfoScreen(userId: _otherUid))); } },
                child: Row(children: [
                  GestureDetector(
                    onTap: () => _openProfilePicture(_otherPhoto),
                    child: CircleAvatar(radius: 20, backgroundImage: headerImage ?? const NetworkImage('https://i.pravatar.cc/150'), backgroundColor: Colors.grey[300]),
                  ),
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
            IconButton(icon: Icon(_isSearching ? Icons.close : Icons.search), onPressed: () { setState(() { _isSearching = !_isSearching; if (!_isSearching) { _searchController.clear(); _searchQuery = ""; } }); }),
            if (!_isSearching) PopupMenuButton<String>(icon: const Icon(Icons.more_vert), onSelected: (val) { 
              if (val == 'export') _exportChat(); 
              if (val == 'clear') _clearChat(); 
              if (val == 'wallpaper') _pickWallpaper();
            }, itemBuilder: (context) => [
              const PopupMenuItem(value: 'wallpaper', child: Text('Ganti Wallpaper Obrolan')),
              const PopupMenuItem(value: 'export', child: Text('Ekspor Chat')), 
              const PopupMenuItem(value: 'clear', child: Text('Bersihkan Chat'))
            ]),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0B141A) : const Color(0xFFEFEAE2),
            image: _wallpaperPath != null ? DecorationImage(image: FileImage(File(_wallpaperPath!)), fit: BoxFit.cover, opacity: 0.3) : null,
          ),
          child: Column(children: [
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
              final docs = snapshot.data!.docs.where((doc) { 
                final data = doc.data() as Map<String, dynamic>; 
                if (data['expiresAt'] != null) { final expiresAt = (data['expiresAt'] as Timestamp).toDate(); if (now.isAfter(expiresAt)) { doc.reference.delete(); return false; } } 
                final deletedFor = (data['deletedFor'] as List?) ?? []; 
                if (deletedFor.contains(myUid)) return false;
                if (_searchQuery.isNotEmpty) { final txt = data['text']?.toString().toLowerCase() ?? ''; if (!txt.contains(_searchQuery)) return false; }
                return true; 
              }).toList();
              return ListView.builder(controller: _scrollController, reverse: true, padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8), itemCount: docs.length, itemBuilder: (context, index) {
                final doc = docs[index]; final data = doc.data() as Map<String, dynamic>;
                final isMe = data['senderId'] == myUid; final timestamp = data['timestamp'] != null ? DateFormat('HH:mm').format((data['timestamp'] as Timestamp).toDate()) : '';
                final isDeleted = data['isDeleted'] == true; final type = data['type']; final isEdited = data['isEdited'] == true;
                final replyTo = data['replyTo']; final reactions = data['reactions'] as Map<String, dynamic>? ?? {};
                String displayText = data['text'] ?? '';
                if (isDeleted && !isMe) { displayText = _isAntiDelete ? '👻 [Anti-Delete]: $displayText' : '🚫 Pesan ini telah dihapus'; }
                
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft, 
                  child: GestureDetector(
                    onLongPress: () => _showMessageOptions(doc, isMe, displayText, data),
                    onHorizontalDragEnd: (details) { if (details.primaryVelocity! > 0) { setState(() => _replyTo = {'text': displayText, 'senderName': data['senderName']}); } },
                    onDoubleTap: () async { // FITUR DOUBLE TAP UNTUK REACTION
                      final reactionsList = Map<String, dynamic>.from(data['reactions'] ?? {});
                      reactionsList[myUid] = '❤️';
                      await doc.reference.update({'reactions': reactionsList});
                    },
                    child: Container(margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: isMe ? (isDark ? const Color(0xFF005C4B) : currentBubbleColor) : (isDark ? const Color(0xFF202C33) : Colors.white), borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (!isMe && widget.roomId != 'global' && _roomType != 'private') Text(data['senderName'], style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00A884))),
                    if (replyTo != null) Container(padding: const EdgeInsets.all(8), margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.black12, borderRadius: BorderRadius.circular(8), border: const Border(left: BorderSide(color: Color(0xFF00A884), width: 4))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(replyTo['senderName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF00A884))), Text(replyTo['text'], maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87))])),
                    
                    if (type == 'video') _VideoPlayerWidget(url: data['mediaUrl'])
                    else if (type == 'image' && !_autoDownloadImage && !isMe)
                      GestureDetector(onTap: () => _openMediaViewer(data['mediaUrl'], false, doc), child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)), child: const Row(children: [Icon(Icons.download, color: Colors.blue), SizedBox(width: 8), Text('Unduh Foto', style: TextStyle(color: Colors.blue))])))
                    else if (type == 'image' && data['viewOnce'] == true) GestureDetector(onTap: () => _openMediaViewer(data['mediaUrl'], true, doc), child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)), child: const Row(children: [Icon(Icons.visibility, color: Colors.grey), SizedBox(width: 8), Text('Foto Sekali Lihat', style: TextStyle(fontStyle: FontStyle.italic))])))
                    else if (type == 'image') GestureDetector(onTap: () => _openMediaViewer(data['mediaUrl'], false, doc), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(data['mediaUrl'], width: 220, fit: BoxFit.cover)), if (displayText.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(displayText, style: TextStyle(color: isDark ? Colors.white : Colors.black)))]))
                    
                    else if (type == 'contact') 
                      Container(width: 220, padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.black12, borderRadius: BorderRadius.circular(8)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [CircleAvatar(radius: 20, backgroundImage: data['contactPhoto'] != null && data['contactPhoto'].toString().isNotEmpty ? MemoryImage(base64Decode(data['contactPhoto'])) : null, child: data['contactPhoto'] == null || data['contactPhoto'].toString().isEmpty ? const Icon(Icons.person, color: Colors.white) : null), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(data['contactName'] ?? 'Kontak', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)), Text(data['contactJbId'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12))]))]),
                        const Divider(),
                        GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ContactInfoScreen(userId: data['contactUid']))), child: const Text('Lihat Profil', style: TextStyle(color: Color(0xFF25D366), fontWeight: FontWeight.bold, fontSize: 13))),
                      ]))

                    else if (type == 'sticker') GestureDetector(onTap: () {}, child: Image.network(data['mediaUrl'], width: 150, height: 150, fit: BoxFit.contain))
                    else if (type == 'audio' && !_autoDownloadAudio && !isMe) Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)), child: const Row(children: [Icon(Icons.download, color: Colors.blue), SizedBox(width: 8), Text('Unduh Pesan Suara', style: TextStyle(color: Colors.blue))]))
                    else if (type == 'audio') _AudioPlayerWidget(url: data['mediaUrl'], isMe: isMe)
                    else if (type == 'location') GestureDetector(onTap: () => launchUrl(Uri.parse(data['mediaUrl'])), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)), child: Row(children: [const Icon(Icons.location_on, color: Colors.red), const SizedBox(width: 8), const Text('Lokasi Saya', style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline))])))
                    else if (type == 'document') GestureDetector(onTap: () => _openDocument(data['mediaUrl']), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)), child: Row(children: [const Icon(Icons.insert_drive_file, color: Colors.blue), const SizedBox(width: 8), Expanded(child: Text(displayText, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline)))])))
                    else if (type == 'poll') Container(width: 250, padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.black12, borderRadius: BorderRadius.circular(8)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(data['question'] ?? 'Voting', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)), const SizedBox(height: 8), 
                      ...List.generate(2, (i) { 
                        final options = List<String>.from(data['options'] ?? []); 
                        final votes = Map<String, dynamic>.from(data['votes'] ?? {}); 
                        final voteCount = votes.values.where((v) => v == i).length; 
                        final totalVotes = votes.length; 
                        final percentage = totalVotes == 0 ? 0.0 : (voteCount / totalVotes); 
                        return GestureDetector(
                          onTap: () => _votePoll(doc.id, i, votes), 
                          onLongPress: () => _showPollDetails(votes, i, options), // FITUR LIHAT PEMILIH
                          child: Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: votes[myUid] == i ? const Color(0xFF25D366).withOpacity(0.3) : Colors.transparent, border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)), child: Stack(children: [Container(width: 200 * percentage, height: 20, color: const Color(0xFF25D366).withOpacity(0.2)), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(options[i], style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14)), Text('$voteCount', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold))])]))
                        ); 
                      })
                    ]))
                    else Text.rich(TextSpan(children: _parseLinks(displayText, TextStyle(color: isDeleted && !_isAntiDelete ? Colors.grey : (isDark ? Colors.white : Colors.black), fontStyle: isDeleted && !_isAntiDelete ? FontStyle.italic : FontStyle.normal, fontSize: 16)))),
                    
                    if (reactions.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Wrap(spacing: 4, children: reactions.values.map((emoji) => Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: isDark ? Colors.black45 : Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade400)), child: Text(emoji, style: const TextStyle(fontSize: 12)))).toList())),
                    Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.end, children: [if (data['expiresAt'] != null) const Icon(Icons.timer, size: 12, color: Colors.grey), const SizedBox(width: 4), Text(timestamp, style: const TextStyle(fontSize: 10, color: Colors.grey)), if (isMe) ...[const SizedBox(width: 4), Icon(Icons.done_all, size: 14, color: data['status'] == 'read' ? _tickColor : Colors.grey)]]),
                  ]))),
                );
              });
            })),
            
            if ((_isBlockedByMe || _hasBlockedMe))
              Container(width: double.infinity, padding: const EdgeInsets.all(16), color: isDark ? const Color(0xFF202C33) : Colors.grey[200], child: Text(_isBlockedByMe ? 'Anda telah memblokir kontak ini. Buka blokir di Info Kontak.' : 'Anda tidak dapat mengirim pesan ke kontak ini.', textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.grey : Colors.black54, fontStyle: FontStyle.italic)))
            else if (_isAnnouncement && !_isAdmin)
              Container(width: double.infinity, padding: const EdgeInsets.all(16), color: isDark ? const Color(0xFF202C33) : Colors.grey[200], child: const Text('Hanya admin yang dapat mengirim pesan di grup ini.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)))
            else ...[
              if (_replyTo != null) Container(padding: const EdgeInsets.all(8), color: isDark ? const Color(0xFF1F2C34) : Colors.white, child: Row(children: [const Icon(Icons.reply, color: Color(0xFF00A884)), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_replyTo!['senderName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF00A884))), Text(_replyTo!['text'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87))])), IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => setState(() => _replyTo = null))])),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(child: Container(decoration: BoxDecoration(color: isDark ? const Color(0xFF1F2C34) : Colors.white, borderRadius: BorderRadius.circular(25)), child: Row(children: [
                  IconButton(icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.grey), onPressed: _showEmojiPicker),
                  IconButton(icon: const Icon(Icons.sticky_note_2_outlined, color: Colors.grey), onPressed: _showStickerPicker),
                  IconButton(icon: const Icon(Icons.attach_file, color: Colors.grey), onPressed: _isUploading ? null : _showAttachmentMenu),
                  Expanded(child: TextField(controller: _msgController, onChanged: _onTextChanged, style: TextStyle(color: isDark ? Colors.white : Colors.black), decoration: const InputDecoration(hintText: 'Ketik pesan', hintStyle: TextStyle(color: Colors.grey), border: InputBorder.none))),
                ]))),
                const SizedBox(width: 8),
                GestureDetector(onLongPressStart: _msgController.text.isEmpty ? (_) => _startRecording() : null, onLongPressEnd: _msgController.text.isEmpty ? (_) => _stopRecording() : null, child: CircleAvatar(backgroundColor: _isRecording ? Colors.red : const Color(0xFF25D366), radius: 24, child: IconButton(icon: Icon(_isRecording ? Icons.mic : (_msgController.text.isEmpty ? Icons.mic : Icons.send), color: Colors.white, size: 20), onPressed: _isUploading ? null : (_msgController.text.isEmpty ? null : _sendMessage)))),
              ])),
            ],
          ]),
        ),
        floatingActionButton: _showScrollToBottom ? FloatingActionButton.small(onPressed: () { _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut); }, backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white, child: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF25D366))) : null,
      );
    });
  }
}

class _AudioPlayerWidget extends StatefulWidget {
  final String url; final bool isMe;
  const _AudioPlayerWidget({required this.url, required this.isMe});
  @override State<_AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}
class _AudioPlayerWidgetState extends State<_AudioPlayerWidget> {
  final AudioPlayer _player = AudioPlayer();
  Duration _duration = Duration.zero; Duration _position = Duration.zero; bool _isPlaying = false;
  @override void initState() { super.initState(); _player.onDurationChanged.listen((d) => setState(() => _duration = d)); _player.onPositionChanged.listen((p) => setState(() => _position = p)); _player.onPlayerComplete.listen((_) => setState(() { _isPlaying = false; _position = Duration.zero; })); }
  @override Widget build(BuildContext context) { return Row(mainAxisSize: MainAxisSize.min, children: [ IconButton(icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, color: widget.isMe ? const Color(0xFF00A884) : Colors.blue, size: 36), onPressed: () async { if (_isPlaying) { await _player.pause(); } else { await _player.play(UrlSource(widget.url)); } setState(() => _isPlaying = !_isPlaying); }), Expanded(child: Slider(value: _position.inMilliseconds.toDouble(), max: _duration.inMilliseconds.toDouble() > 0 ? _duration.inMilliseconds.toDouble() : 1, onChanged: (val) { _player.seek(Duration(milliseconds: val.toInt())); })), Text('${_position.inMinutes}:${(_position.inSeconds % 60).toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 10, color: Colors.grey)) ]); }
}

class _VideoPlayerWidget extends StatefulWidget {
  final String url; const _VideoPlayerWidget({required this.url});
  @override State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}
class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  late VideoPlayerController _controller; bool _isInit = false;
  @override void initState() { super.initState(); _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))..initialize().then((_) { setState(() => _isInit = true); _controller.setLooping(true); }); }
  @override void dispose() { _controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) { if (!_isInit) return const SizedBox(width: 200, height: 150, child: Center(child: CircularProgressIndicator())); return SizedBox(width: 220, child: AspectRatio(aspectRatio: _controller.value.aspectRatio, child: Stack(alignment: Alignment.center, children: [VideoPlayer(_controller), GestureDetector(onTap: () { setState(() { _controller.value.isPlaying ? _controller.pause() : _controller.play(); }); }, child: Icon(_controller.value.isPlaying ? Icons.pause : Icons.play_arrow, size: 50, color: Colors.white70))]))); }
}
