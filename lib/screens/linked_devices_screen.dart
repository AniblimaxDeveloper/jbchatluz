import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class LinkedDevicesScreen extends StatelessWidget {
  const LinkedDevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : Colors.white,
      appBar: AppBar(title: const Text('Perangkat Tertaut'), backgroundColor: const Color(0xFF075E54), foregroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Tautkan Perangkat Anda', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 8),
          const Text('Untuk menautkan perangkat, buka JBchatluz di perangkat lain dan pindai kode QR ini.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 32),
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: QrImageView(
                data: 'jbchatluz_linked_device_demo',
                version: QrVersions.auto,
                size: 200.0,
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Divider(),
          Text('Perangkat Tertaut (1)', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.phone_android, size: 40, color: Colors.grey),
            title: Text('Perangkat Ini', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            subtitle: const Text('Aktif sekarang', style: TextStyle(color: Color(0xFF25D366))),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fitur logout semua perangkat berhasil.')));
              },
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Keluar dari semua perangkat', style: TextStyle(color: Colors.red)),
            ),
          )
        ],
      ),
    );
  }
}
