import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
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
            onTap: () {},
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Privasi & Keamanan MOD'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
