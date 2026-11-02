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
                title: Text(font),
                value: font,
                groupValue: fontNotifier.value,
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
                child: Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.grey)),
                ),
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

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan MOD'), backgroundColor: const Color(0xFF075E54), foregroundColor: Colors.white),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode),
            title: const Text('Mode Gelap'),
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
            title: const Text('Warna Bubble Chat'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showBubbleColorPicker,
          ),
          ListTile(
            leading: const Icon(Icons.font_download),
            title: const Text('Ganti Font'),
            subtitle: Text('Font: ${fontNotifier.value}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showFontPicker,
          ),
          ListTile(
            leading: const Icon(Icons.wallpaper),
            title: const Text('Wallpaper Chat'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickWallpaper,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('Kunci Aplikasi (PIN)'),
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
