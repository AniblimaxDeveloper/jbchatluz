import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
    });
  }

  void _toggleDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', value);
    setState(() => _isDarkMode = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Pengaturan', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF075E54),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Tampilan & Tema', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode, color: Colors.grey),
            title: const Text('Mode Gelap (Dark Mode)'),
            subtitle: const Text('Ubah tema aplikasi menjadi hitam'),
            value: _isDarkMode,
            activeColor: const Color(0xFF25D366),
            onChanged: _toggleDarkMode,
          ),
          ListTile(
            leading: const Icon(Icons.wallpaper, color: Colors.grey),
            title: const Text('Wallpaper Chat'),
            subtitle: const Text('Ganti latar belakang obrolan'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.font_download, color: Colors.grey),
            title: const Text('Ganti Font'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Privasi MOD', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.visibility_off, color: Colors.grey),
            title: const Text('Sembunyikan Centang Biru'),
            subtitle: const Text('Aktifkan centang biru palsu (Mod)'),
            value: true,
            activeColor: const Color(0xFF25D366),
            onChanged: (val) {},
          ),
          SwitchListTile(
            secondary: const Icon(Icons.visibility, color: Colors.grey),
            title: const Text('Kunci Aplikasi (App Lock)'),
            subtitle: const Text('Amankan aplikasi dengan PIN'),
            value: false,
            activeColor: const Color(0xFF25D366),
            onChanged: (val) {},
          ),
        ],
      ),
    );
  }
}
