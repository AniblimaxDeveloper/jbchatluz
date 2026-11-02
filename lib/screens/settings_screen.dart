import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  void _setPin() {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Atur PIN Aplikasi"),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          decoration: const InputDecoration(labelText: "Masukkan 4-6 Angka"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('app_pin', pinController.text.trim());
              if (mounted) Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PIN berhasil diatur. Restart aplikasi untuk menguji.")));
            },
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }

  void _removePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('app_pin');
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PIN dihapus.")));
  }

  void _pickWallpaper() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('wallpaper_path', image.path);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Wallpaper berhasil diubah.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan MOD'),
        backgroundColor: const Color(0xFF075E54),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode),
            title: const Text('Mode Gelap (Dark Mode)'),
            subtitle: const Text('Ubah tema aplikasi secara keseluruhan'),
            value: isDark,
            activeColor: const Color(0xFF25D366),
            onChanged: (value) async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('darkMode', value);
              themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
            },
          ),
          ListTile(
            leading: const Icon(Icons.wallpaper),
            title: const Text('Wallpaper Chat'),
            subtitle: const Text('Ganti latar belakang obrolan'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickWallpaper,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('Kunci Aplikasi (App Lock)'),
            subtitle: const Text('Amankan aplikasi dengan PIN rahasia'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _setPin,
          ),
          ListTile(
            leading: const Icon(Icons.lock_open, color: Colors.red),
            title: const Text('Hapus PIN Aplikasi', style: TextStyle(color: Colors.red)),
            onTap: _removePin,
          ),
        ],
      ),
    );
  }
}
