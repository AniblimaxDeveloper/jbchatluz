import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class StorageManagerScreen extends StatefulWidget {
  const StorageManagerScreen({super.key});

  @override
  State<StorageManagerScreen> createState() => _StorageManagerScreenState();
}

class _StorageManagerScreenState extends State<StorageManagerScreen> {
  double _cacheSizeMB = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _calculateCache();
  }

  Future<void> _calculateCache() async {
    setState(() => _isLoading = true);
    try {
      final cacheDir = await getTemporaryDirectory();
      if (cacheDir.existsSync()) {
        int totalSize = 0;
        final files = cacheDir.listSync(recursive: true);
        for (var file in files) {
          if (file is File) {
            totalSize += file.lengthSync();
          }
        }
        setState(() => _cacheSizeMB = totalSize / (1024 * 1024));
      }
    } catch (e) {
      debugPrint("Error calculating cache: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearCache() async {
    setState(() => _isLoading = true);
    try {
      final cacheDir = await getTemporaryDirectory();
      if (cacheDir.existsSync()) {
        cacheDir.deleteSync(recursive: true);
        cacheDir.createSync();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cache berhasil dibersihkan!')));
      }
      _calculateCache();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal membersihkan cache: $e')));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : Colors.white,
      appBar: AppBar(title: const Text('Penyimpanan dan Data'), backgroundColor: isDark ? const Color(0xFF1F2C34) : const Color(0xFF075E54), foregroundColor: Colors.white),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Icon(Icons.cleaning_services, size: 80, color: isDark ? const Color(0xFF25D366) : const Color(0xFF075E54)),
                const SizedBox(height: 16),
                Center(child: Text('${_cacheSizeMB.toStringAsFixed(2)} MB', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textColor))),
                Center(child: Text('Ukuran Cache Aplikasi', style: TextStyle(color: Colors.grey, fontSize: 16))),
                const SizedBox(height: 32),
                const Text('Cache menyimpan file sementara (seperti gambar yang sudah dilihat) agar aplikasi berjalan lebih cepat. Menghapus cache tidak akan menghapus chat atau kontak Anda.', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                    onPressed: _clearCache,
                    icon: const Icon(Icons.delete_sweep, color: Colors.white),
                    label: const Text('Bersihkan Cache', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
    );
  }
}
