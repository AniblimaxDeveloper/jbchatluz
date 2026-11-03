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
  final _autoReplyController = TextEditingController();
  bool _isAutoReplyOn = false;
  String _notificationSound = "Default";

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isAutoReplyOn = prefs.getBool('mod_auto_reply') ?? false;
      _autoReplyController.text = prefs.getString('mod_auto_reply_msg') ?? 'Saya sedang sibuk, akan membalas nanti.';
      _notificationSound = prefs.getString('notification_sound') ?? 'Default';
    });
  }

  void _setPin() { /* Kode PIN sama seperti sebelumnya */ }
  void _removePin() async { /* Kode Hapus PIN sama */ }
  void _pickWallpaper() async { /* Kode Wallpaper sama */ }
  void _showFontPicker() { /* Kode Font sama */ }
  void _showBubbleColorPicker() { /* Kode Bubble Warna sama */ }

  void _showNotificationSoundPicker() {
    final sounds = ["Default", "Ping", "Pop", "Ding", "Chime"];
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Nada Notifikasi"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: sounds.map((sound) {
              return RadioListTile<String>(
                title: Text(sound),
                value: sound,
                groupValue: _notificationSound,
                onChanged: (val) async {
                  if (val != null) {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('notification_sound', val);
                    setState(() => _notificationSound = val);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan MOD'), backgroundColor: const Color(0xFF075E54), foregroundColor: Colors.white),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode),
            title: Text('Mode Gelap', style: TextStyle(color: textColor)),
            value: isDark, activeColor: const Color(0xFF25D366),
            onChanged: (value) async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('darkMode', value);
              themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
            },
          ),
          ListTile(
            leading: const Icon(Icons.palette),
            title: Text('Warna Bubble Chat', style: TextStyle(color: textColor)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showBubbleColorPicker,
          ),
          ListTile(
            leading: const Icon(Icons.font_download),
            title: Text('Ganti Font', style: TextStyle(color: textColor)),
            subtitle: Text('Font: ${fontNotifier.value}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showFontPicker,
          ),
          ListTile(
            leading: const Icon(Icons.wallpaper),
            title: Text('Wallpaper Chat', style: TextStyle(color: textColor)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickWallpaper,
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Notifikasi', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
          ),
          ListTile(
            leading: const Icon(Icons.music_note),
            title: Text('Nada Pesan', style: TextStyle(color: textColor)),
            subtitle: Text(_notificationSound),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showNotificationSoundPicker,
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('MOD Unlimited (Eksklusif)', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.restore_from_trash, color: Colors.purple),
            title: Text('Anti-Delete (Simpan Pesan Dihapus)', style: TextStyle(color: textColor)),
            subtitle: const Text('Pesan yang dihapus orang lain akan tetap terlihat'),
            value: isDark ? false : (ModalRoute.of(context)?.settings.name == 'anti' ? true : null) ?? false,
            activeColor: const Color(0xFF25D366),
            onChanged: (val) async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('mod_anti_delete', val);
              setState(() {});
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.smart_toy, color: Colors.blue),
            title: Text('Auto-Reply (Robot)', style: TextStyle(color: textColor)),
            subtitle: const Text('Membalas pesan masuk secara otomatis'),
            value: _isAutoReplyOn, activeColor: const Color(0xFF25D366),
            onChanged: (val) async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('mod_auto_reply', val);
              setState(() => _isAutoReplyOn = val);
            },
          ),
          if (_isAutoReplyOn)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _autoReplyController, style: TextStyle(color: textColor),
                decoration: InputDecoration(labelText: 'Pesan Auto-Reply', border: const OutlineInputBorder(), suffixIcon: IconButton(icon: const Icon(Icons.check, color: Color(0xFF25D366)), onPressed: () async { final prefs = await SharedPreferences.getInstance(); await prefs.setString('mod_auto_reply_msg', _autoReplyController.text); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Disimpan'))); })),
              ),
            ),
          const Divider(),
          ListTile(leading: const Icon(Icons.lock), title: Text('Kunci Aplikasi (PIN)', style: TextStyle(color: textColor)), trailing: const Icon(Icons.chevron_right), onTap: _setPin),
          ListTile(leading: const Icon(Icons.lock_open, color: Colors.red), title: const Text('Hapus PIN', style: TextStyle(color: Colors.red)), onTap: _removePin),
        ],
      ),
    );
  }
}
