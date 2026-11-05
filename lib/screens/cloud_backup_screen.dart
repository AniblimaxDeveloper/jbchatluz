import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CloudBackupScreen extends StatefulWidget {
  const CloudBackupScreen({super.key});

  @override
  State<CloudBackupScreen> createState() => _CloudBackupScreenState();
}

class _CloudBackupScreenState extends State<CloudBackupScreen> {
  final String myUid = FirebaseAuth.instance.currentUser?.uid ?? "";
  bool _isLoading = false;

  Future<void> _backupToCloud() async {
    setState(() => _isLoading = true);
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(myUid).get();
      if (!userDoc.exists) throw Exception('Data tidak ditemukan');

      final data = userDoc.data()!;
      data['lastCloudBackup'] = FieldValue.serverTimestamp();

      await FirebaseFirestore.instance.collection('cloud_backups').doc(myUid).set(data);

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup ke Cloud berhasil!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal backup: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreFromCloud() async {
    setState(() => _isLoading = true);
    try {
      final backupDoc = await FirebaseFirestore.instance.collection('cloud_backups').doc(myUid).get();
      if (!backupDoc.exists) throw Exception('Backup Cloud tidak ditemukan');

      final data = backupDoc.data()!;
      data.remove('lastCloudBackup');
      data['restoredAt'] = FieldValue.serverTimestamp();

      await FirebaseFirestore.instance.collection('users').doc(myUid).update(data);

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restore dari Cloud berhasil!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal restore: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : Colors.white,
      appBar: AppBar(title: const Text('Cloud Backup'), backgroundColor: isDark ? const Color(0xFF1F2C34) : const Color(0xFF075E54), foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_sync, size: 100, color: isDark ? const Color(0xFF25D366) : const Color(0xFF075E54)),
            const SizedBox(height: 24),
            Text('Cadangkan ke Server', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            const Text('Simpan profil dan daftar kontak Anda langsung ke server Firebase. Jika Anda mengganti HP, Anda bisa memulihkannya kembali.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 32),
            
            SizedBox(
              width: double.infinity, height: 50,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                onPressed: _isLoading ? null : _backupToCloud,
                icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.backup, color: Colors.white),
                label: const Text('Mulai Backup ke Cloud', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
            
            SizedBox(
              width: double.infinity, height: 50,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF25D366))),
                onPressed: _isLoading ? null : _restoreFromCloud,
                icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Color(0xFF25D366), strokeWidth: 2)) : const Icon(Icons.restore, color: Color(0xFF25D366)),
                label: const Text('Restore dari Cloud', style: TextStyle(color: Color(0xFF25D366), fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
