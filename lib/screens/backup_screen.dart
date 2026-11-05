import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:intl/intl.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final String myUid = FirebaseAuth.instance.currentUser?.uid ?? "";
  bool _isBackingUp = false;

  Future<void> _createBackup() async {
    setState(() => _isBackingUp = true);
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(myUid).get();
      if (!userDoc.exists) throw Exception('Data pengguna tidak ditemukan');

      final data = userDoc.data()!;
      // Hapus foto Base64 agar file backup tidak terlalu besar
      data.remove('photoBase64'); 
      data['backupDate'] = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      final jsonString = const JsonEncoder.withIndent('  ').convert(data);
      
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/jbchatluz_backup_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(jsonString);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup berhasil dibuat!')));
        await OpenFilex.open(file.path);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal backup: $e')));
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : Colors.white,
      appBar: AppBar(
        title: const Text('Cadangkan Data (Backup)'),
        backgroundColor: isDark ? const Color(0xFF1F2C34) : const Color(0xFF075E54),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_upload, size: 100, color: isDark ? const Color(0xFF25D366) : const Color(0xFF075E54)),
            const SizedBox(height: 24),
            Text('Buat Salinan Lokal', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 12),
            const Text(
              'Fitur ini akan mengekspor profil (Nama, Email, JBID, Tentang) menjadi file .json yang aman di HP Anda. Anda bisa menyimpannya di Google Drive atau membaginya.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                onPressed: _isBackingUp ? null : _createBackup,
                icon: _isBackingUp ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.backup, color: Colors.white),
                label: Text(_isBackingUp ? 'Memproses...' : 'Mulai Backup Sekarang', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
