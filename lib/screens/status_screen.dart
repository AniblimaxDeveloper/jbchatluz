import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  final String myUid = FirebaseAuth.instance.currentUser?.uid ?? "";
  bool _isUploading = false;
  bool _autoViewEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadModSettings();
  }

  Future<void> _loadModSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _autoViewEnabled = prefs.getBool('mod_auto_view_status') ?? false);
  }

  Future<void> _uploadImageStatus() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 20);
    if (image == null) return;

    setState(() => _isUploading = true);
    try {
      final bytes = await File(image.path).readAsBytes();
      final base64String = base64Encode(bytes);
      await FirebaseFirestore.instance.collection('statuses').add({
        'uid': myUid, 'userName': FirebaseAuth.instance.currentUser?.displayName ?? 'User',
        'type': 'image', 'photoBase64': base64String, 'timestamp': FieldValue.serverTimestamp(), 'views': []
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status diunggah!')));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'))); } finally { if (mounted) setState(() => _isUploading = false); }
  }

  void _addTextStatus() {
    final textController = TextEditingController();
    Color selectedColor = Colors.blueGrey;
    final colors = [Colors.blueGrey, Colors.red, Colors.green, Colors.purple, Colors.orange, Colors.teal];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Status Teks'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 150, width: double.infinity, color: selectedColor,
                    alignment: Alignment.center, padding: const EdgeInsets.all(8),
                    child: Text(textController.text, style: const TextStyle(color: Colors.white, fontSize: 20), textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: textController,
                    decoration: const InputDecoration(hintText: 'Ketik status Anda...', border: OutlineInputBorder()),
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Wrap(spacing: 8, children: colors.map((c) => GestureDetector(onTap: () => setModalState(() => selectedColor = c), child: CircleAvatar(backgroundColor: c, radius: 16))).toList())
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
                TextButton(
                  onPressed: () async {
                    if (textController.text.trim().isNotEmpty) {
                      await FirebaseFirestore.instance.collection('statuses').add({
                        'uid': myUid, 'userName': FirebaseAuth.instance.currentUser?.displayName ?? 'User',
                        'type': 'text', 'text': textController.text.trim(), 'backgroundColor': selectedColor.value,
                        'timestamp': FieldValue.serverTimestamp(), 'views': []
                      });
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  child: const Text('Kirim'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _viewStatus(DocumentSnapshot doc, Map<String, dynamic> data) async {
    final views = (data['views'] as List?) ?? [];
    if (!views.contains(myUid)) { await doc.reference.update({'views': FieldValue.arrayUnion([myUid])}); }
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text(data['userName'] ?? 'Status'), actions: [if (data['uid'] == myUid) IconButton(icon: const Icon(Icons.remove_red_eye), onPressed: () { showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Dilihat oleh'), content: Text('${views.length} orang telah melihat status ini.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup'))])); })]),
      body: Center(
        child: data['type'] == 'text'
            ? Container(
                width: double.infinity, height: double.infinity,
                color: Color(data['backgroundColor']),
                alignment: Alignment.center, padding: const EdgeInsets.all(24),
                child: Text(data['text'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              )
            : InteractiveViewer(child: Image.memory(base64Decode(data['photoBase64']))),
      ),
    )));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : Colors.white,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.all(16), child: Text('Status', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor))),
        ListTile(leading: Stack(children: [CircleAvatar(radius: 24, backgroundColor: Colors.grey[300], child: const Icon(Icons.person, color: Colors.white)), Positioned(bottom: 0, right: 0, child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Color(0xFF25D366), shape: BoxShape.circle), child: const Icon(Icons.add, size: 16, color: Colors.white)))]), title: Text('Status Saya', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)), subtitle: Text('Ketuk untuk menambah pembaruan status', style: TextStyle(color: isDark ? Colors.grey : Colors.black54)), onTap: _isUploading ? null : _uploadImageStatus),
        const Divider(),
        Padding(padding: const EdgeInsets.all(16), child: Text('Pembaruan Terbaru', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.grey : Colors.black54))),
        Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('statuses').orderBy('timestamp', descending: true).snapshots(), builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final now = DateTime.now();
          final docs = snapshot.data!.docs.where((doc) { final data = doc.data() as Map<String, dynamic>; if (data['uid'] == myUid) return false; final timestamp = (data['timestamp'] as Timestamp).toDate(); return now.difference(timestamp).inHours < 24; }).toList();
          if (docs.isEmpty) return const Center(child: Text('Belum ada pembaruan status.', style: TextStyle(color: Colors.grey)));
          
          if (_autoViewEnabled) { for (var doc in docs) { final views = (doc.data() as Map)['views'] as List? ?? []; if (!views.contains(myUid)) { doc.reference.update({'views': FieldValue.arrayUnion([myUid])}); } } }

          return ListView.builder(itemCount: docs.length, itemBuilder: (context, index) {
            final doc = docs[index]; final data = doc.data() as Map<String, dynamic>;
            final isViewed = (data['views'] as List).contains(myUid);
            final time = DateFormat('HH:mm').format((data['timestamp'] as Timestamp).toDate());
            return ListTile(
              leading: CircleAvatar(
                radius: 26, backgroundColor: isViewed ? Colors.grey : const Color(0xFF25D366),
                child: data['type'] == 'text' ? const Icon(Icons.text_fields, color: Colors.white) : CircleAvatar(radius: 23, backgroundImage: MemoryImage(base64Decode(data['photoBase64']))),
              ),
              title: Text(data['userName'] ?? 'User', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
              subtitle: Text(time, style: TextStyle(color: isDark ? Colors.grey : Colors.black54)),
              onTap: () => _viewStatus(doc, data),
            );
          });
        })),
      ]),
      floatingActionButton: FloatingActionButton(onPressed: _isUploading ? null : _addTextStatus, backgroundColor: const Color(0xFF25D366), child: _isUploading ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.edit, color: Colors.white)),
    );
  }
}
