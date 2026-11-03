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
    });
  }

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
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PIN diatur. Restart aplikasi.")));
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Wallpaper diubah.")));
    }
  }

  void _showFontPicker() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Pilih Font"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ["Default", "Poppins", "Roboto", "Lora", "Oswald"].map((font) {
              return RadioListTile<String>(
                title: Text(font), value: font, groupValue: fontNotifier.value,
                onChanged: (val) async {
                  if (val != null) {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('app_font', val);
                    fontNotifier.value = val;
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

  void _showBubbleColorPicker() {
    final colors = [const Color(0xFFD9FDD3), const Color(0xFFD2E8FF), const Color(0xFFFFE4E1), const Color(0xFFF0E6FF)];
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Warna Bubble Chat"),
          content: Wrap(
            spacing: 10,
            children: colors.map((color) {
              return GestureDetector(
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setInt('bubble_color', color.value);
                  bubbleColorNotifier.value = color;
                  if (context.mounted) Navigator.pop(context);
                },
                child: Container(width: 50, height: 50, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.grey))),
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
            value: isDark,
            activeColor: const Color(0xFF25D366),
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
            child: Text('MOD Unlimited (Eksklusif)', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
          ),
          
          // Anti Delete
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
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(val ? 'Anti-Delete Aktif' : 'Anti-Delete Nonaktif')));
            },
          ),

          // Auto Reply
          SwitchListTile(
            secondary: const Icon(Icons.smart_toy, color: Colors.blue),
            title: Text('Auto-Reply (Robot)', style: TextStyle(color: textColor)),
            subtitle: const Text('Membalas pesan masuk secara otomatis'),
            value: _isAutoReplyOn,
            activeColor: const Color(0xFF25D366),
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
                controller: _autoReplyController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'Pesan Auto-Reply',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.check, color: Color(0xFF25D366)),
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('mod_auto_reply_msg', _autoReplyController.text);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pesan Auto-Reply disimpan')));
                    },
                  ),
                ),
              ),
            ),
          
          const Divider(),
          ListTile(
            leading: const Icon(Icons.lock),
            title: Text('Kunci Aplikasi (PIN)', style: TextStyle(color: textColor)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _setPin,
          ),
          ListTile(
            leading: const Icon(Icons.lock_open, color: Colors.red),
            title: const Text('Hapus PIN', style: TextStyle(color: Colors.red)),
            onTap: _removePin,
          ),
        ],
      ),
    );
  }
}
