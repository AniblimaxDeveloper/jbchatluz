import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  bool _isProcessing = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? jbId = barcodes.first.rawValue;
    if (jbId == null || jbId.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      final myUid = FirebaseAuth.instance.currentUser!.uid;
      
      // Cari user berdasarkan JBID yang dipindai
      final userQuery = await FirebaseFirestore.instance.collection('users').where('jbId', isEqualTo: jbId).get();
      
      if (userQuery.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ID tidak ditemukan!')));
          setState(() => _isProcessing = false);
        }
        return;
      }

      final targetUser = userQuery.docs.first;
      final targetUid = targetUser.id;
      final targetName = targetUser.data()['displayName'] ?? 'Pengguna';

      // Tambahkan ke kontak
      await FirebaseFirestore.instance.collection('users').doc(myUid).update({
        'contacts': FieldValue.arrayUnion([targetUid]),
      });

      // Cari atau buat room private
      final roomQuery = await FirebaseFirestore.instance.collection('rooms')
          .where('type', isEqualTo: 'private')
          .where('members', arrayContains: myUid)
          .get();

      String roomId = '';
      for (var doc in roomQuery.docs) {
        final members = doc.data()['members'] as List;
        if (members.contains(targetUid)) { roomId = doc.id; break; }
      }

      if (roomId.isEmpty) {
        final newRoom = await FirebaseFirestore.instance.collection('rooms').add({
          'type': 'private', 'members': [myUid, targetUid],
          'lastMessage': 'Chat pribadi dimulai', 'lastMessageTime': FieldValue.serverTimestamp(),
        });
        roomId = newRoom.id;
      }

      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ChatScreen(roomId: roomId, roomName: targetName)));
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pindai QR Code'), backgroundColor: const Color(0xFF075E54), foregroundColor: Colors.white),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: _onDetect,
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF25D366), width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
