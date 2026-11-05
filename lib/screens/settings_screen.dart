import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../main.dart';
import 'storage_manager_screen.dart';
import 'fake_chat_screen.dart';
import 'blocked_contacts_screen.dart';
import 'backup_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _autoReplyController = TextEditingController();
  bool _isAutoReplyOn = false;
  bool _isDarkMode = false;
  bool _antiDelete = false;
  bool _hideTyping = false;
  bool _alwaysOnline = false;
  bool _freezeLastSeen = false;
  bool _hideOnline = false;
  bool _hideBlueTick = false;
  bool _autoViewStatus = false;
  bool _antiViewOnce = false;
  bool _hideRecording = false;
  String _tickColor = 'blue';
  bool _autoDownloadImage = true;
  bool _autoDownloadAudio = true;
  double _fontSize = 1.0;

  @override
  void initState() { super.initState(); _loadSettings(); }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
      _isAutoReplyOn = prefs.getBool('mod_auto_reply') ?? false;
      _autoReplyController.text = prefs.getString('mod_auto_reply_msg') ?? 'Saya sedang sibuk.';
      _antiDelete = prefs.getBool('mod_anti_delete') ?? false;
      _hideTyping = prefs.getBool('mod_hide_typing') ?? false;
      _alwaysOnline = prefs.getBool('mod_always_online') ?? false;
      _freezeLastSeen = prefs.getBool('mod_freeze_lastseen') ?? false;
      _hideOnline = prefs.getBool('mod_hide_online') ?? false;
      _hideBlueTick = prefs.getBool('mod_hide_tick') ?? false;
      _autoViewStatus = prefs.getBool('mod_auto_view_status') ?? false;
      _antiViewOnce = prefs.getBool('mod_anti_viewonce') ?? false;
      _hideRecording = prefs.getBool('mod_hide_recording') ?? false;
      _tickColor = prefs.getString('mod_tick_color') ?? 'blue';
      _autoDownloadImage = prefs.getBool('auto_download_image') ?? true;
      _autoDownloadAudio = prefs.getBool('auto_download_audio') ?? true;
      _fontSize = prefs.getDouble('font_size_scale') ?? 1.0;
    });
  }

  void _setPin() { final pinController = TextEditingController(); showDialog(context: context, builder: (context) => AlertDialog(title: const Text("Atur PIN"), content: TextField(controller: pinController, keyboardType: TextInputType.number, obscureText: true, decoration: const InputDecoration(labelText: "PIN Baru")), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")), TextButton(onPressed: () async { final prefs = await SharedPreferences.getInstance(); await prefs.setString('app_pin', pinController.text.trim()); if (context.mounted) Navigator.pop(context); }, child: const Text("Simpan"))])); }
  void _removePin() async { final prefs = await SharedPreferences.getInstance(); await prefs.remove('app_pin'); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PIN dihapus."))); }
  void _pickWallpaper() async { final picker = ImagePicker(); final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50); if (image != null) { final prefs = await SharedPreferences.getInstance(); await prefs.setString('wallpaper_path', image.path); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Wallpaper diubah."))); } }
  void _showFontPicker() { showDialog(context: context, builder: (context) => AlertDialog(title: const Text("Pilih Font"), content: Column(mainAxisSize: MainAxisSize.min, children: ["Default", "Poppins", "Roboto", "Lora", "Oswald"].map((font) => RadioListTile<String>(title: Text(font), value: font, groupValue: fontNotifier.value, onChanged: (val) async { if (val != null) { final prefs = await SharedPreferences.getInstance(); await prefs.setString('app_font', val); fontNotifier.value = val; if (context.mounted) Navigator.pop(context); } })).toList()))); }
  void _showBubbleColorPicker() { final colors = [const Color(0xFFD9FDD3), const Color(0xFFD2E8FF), const Color(0xFFFFE4E1), const Color(0xFFF0E6FF)]; showDialog(context: context, builder: (context) => AlertDialog(title: const Text("Warna Bubble Chat"), content: Wrap(spacing: 10, children: colors.map((color) => GestureDetector(onTap: () async { final prefs = await SharedPreferences.getInstance(); await prefs.setInt('bubble_color', color.value); bubbleColorNotifier.value = color; if (context.mounted) Navigator.pop(context); }, child: Container(width: 50, height: 50, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.grey))))).toList()))); }
  void _showTickColorPicker() { showDialog(context: context, builder: (context) => AlertDialog(title: const Text("Warna Centang"), content: Column(mainAxisSize: MainAxisSize.min, children: ['blue', 'grey', 'purple', 'green'].map((color) => RadioListTile<String>(title: Text(color.toUpperCase()), value: color, groupValue: _tickColor, onChanged: (val) async { if (val != null) { final prefs = await SharedPreferences.getInstance(); await prefs.setString('mod_tick_color', val); setState(() => _tickColor = val); if (context.mounted) Navigator.pop(context); } })).toList()))); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan MOD'), backgroundColor: const Color(0xFF075E54), foregroundColor: Colors.white),
      body: ListView(
        children: [
          SwitchListTile(secondary: const Icon(Icons.dark_mode), title: Text('Mode Gelap', style: TextStyle(color: textColor)), value: _isDarkMode, activeColor: const Color(0xFF25D366), onChanged: (val) async { final prefs = await SharedPreferences.getInstance(); await prefs.setBool('darkMode', val); themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light; setState(() => _isDarkMode = val); }),
          ListTile(leading: const Icon(Icons.format_size), title: Text('Ukuran Teks', style: TextStyle(color: textColor)), subtitle: Slider(value: _fontSize, min: 0.8, max: 1.5, divisions: 7, activeColor: const Color(0xFF25D366), onChanged: (val) { setState(() => _fontSize = val); fontSizeNotifier.value = val; SharedPreferences.getInstance().then((prefs) => prefs.setDouble('font_size_scale', val)); })),
          ListTile(leading: const Icon(Icons.palette), title: Text('Warna Bubble Chat', style: TextStyle(color: textColor)), trailing: const Icon(Icons.chevron_right), onTap: _showBubbleColorPicker),
          ListTile(leading: const Icon(Icons.font_download), title: Text('Ganti Font', style: TextStyle(color: textColor)), subtitle: Text('Font: ${fontNotifier.value}'), trailing: const Icon(Icons.chevron_right), onTap: _showFontPicker),
          ListTile(leading: const Icon(Icons.wallpaper), title: Text('Wallpaper Chat (Global)', style: TextStyle(color: textColor)), trailing: const Icon(Icons.chevron_right), onTap: _pickWallpaper),
          ListTile(leading: const Icon(Icons.check_circle, color: Colors.blue), title: Text('Warna Centang', style: TextStyle(color: textColor)), subtitle: Text(_tickColor.toUpperCase()), trailing: const Icon(Icons.chevron_right), onTap: _showTickColorPicker),
          
          const Divider(),
          Padding(padding: const EdgeInsets.all(16), child: Text('Alat & Penyimpanan', style: TextStyle(fontWeight: FontWeight.bold, color: textColor))),
          ListTile(leading: const Icon(Icons.storage, color: Colors.orange), title: Text('Penyimpanan dan Data', style: TextStyle(color: textColor)), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StorageManagerScreen()))),
          ListTile(leading: const Icon(Icons.backup, color: Colors.blue), title: Text('Cadangkan Data (Backup)', style: TextStyle(color: textColor)), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupScreen()))),
          ListTile(leading: const Icon(Icons.chat_bubble, color: Colors.purple), title: Text('Fake Chat Generator (MOD)', style: TextStyle(color: textColor)), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FakeChatScreen()))),

          const Divider(),
          Padding(padding: const EdgeInsets.all(16), child: Text('Privasi & Keamanan', style: TextStyle(fontWeight: FontWeight.bold, color: textColor))),
          ListTile(leading: const Icon(Icons.block, color: Colors.red), title: Text('Kontak Diblokir', style: TextStyle(color: textColor)), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BlockedContactsScreen()))),
          ListTile(leading: const Icon(Icons.lock), title: Text('Kunci Aplikasi (PIN)', style: TextStyle(color: textColor)), trailing: const Icon(Icons.chevron_right), onTap: _setPin),
          ListTile(leading: const Icon(Icons.lock_open, color: Colors.red), title: const Text('Hapus PIN', style: TextStyle(color: Colors.red)), onTap: _removePin),
          
          const Divider(),
          Padding(padding: const EdgeInsets.all(16), child: Text('MOD Unlimited (Eksklusif)', style: TextStyle(fontWeight: FontWeight.bold, color: textColor))),
          SwitchListTile(secondary: const Icon(Icons.restore_from_trash, color: Colors.purple), title: Text('Anti-Delete', style: TextStyle(color: textColor)), value: _antiDelete, activeColor: const Color(0xFF25D366), onChanged: (val) async { final prefs = await SharedPreferences.getInstance(); await prefs.setBool('mod_anti_delete', val); setState(() => _antiDelete = val); }),
          SwitchListTile(secondary: const Icon(Icons.visibility, color: Colors.orange), title: Text('Anti-View Once', style: TextStyle(color: textColor)), value: _antiViewOnce, activeColor: const Color(0xFF25D366), onChanged: (val) async { final prefs = await SharedPreferences.getInstance(); await prefs.setBool('mod_anti_viewonce', val); setState(() => _antiViewOnce = val); }),
          SwitchListTile(secondary: const Icon(Icons.remove_red_eye, color: Colors.green), title: Text('Auto-View Status', style: TextStyle(color: textColor)), value: _autoViewStatus, activeColor: const Color(0xFF25D366), onChanged: (val) async { final prefs = await SharedPreferences.getInstance(); await prefs.setBool('mod_auto_view_status', val); setState(() => _autoViewStatus = val); }),
          SwitchListTile(secondary: const Icon(Icons.mic_off, color: Colors.red), title: Text('Sembunyikan Merekam', style: TextStyle(color: textColor)), value: _hideRecording, activeColor: const Color(0xFF25D366), onChanged: (val) async { final prefs = await SharedPreferences.getInstance(); await prefs.setBool('mod_hide_recording', val); setState(() => _hideRecording = val); }),
          SwitchListTile(secondary: const Icon(Icons.keyboard_hide, color: Colors.orange), title: Text('Sembunyikan "Mengetik"', style: TextStyle(color: textColor)), value: _hideTyping, activeColor: const Color(0xFF25D366), onChanged: (val) async { final prefs = await SharedPreferences.getInstance(); await prefs.setBool('mod_hide_typing', val); setState(() => _hideTyping = val); }),
          SwitchListTile(secondary: const Icon(Icons.public, color: Colors.green), title: Text('Selalu Online', style: TextStyle(color: textColor)), value: _alwaysOnline, activeColor: const Color(0xFF25D366), onChanged: (val) async { final prefs = await SharedPreferences.getInstance(); await prefs.setBool('mod_always_online', val); setState(() => _alwaysOnline = val); }),
          SwitchListTile(secondary: const Icon(Icons.ac_unit, color: Colors.blue), title: Text('Bekukan Terakhir Dilihat', style: TextStyle(color: textColor)), value: _freezeLastSeen, activeColor: const Color(0xFF25D366), onChanged: (val) async { final prefs = await SharedPreferences.getInstance(); await prefs.setBool('mod_freeze_lastseen', val); setState(() => _freezeLastSeen = val); }),
          SwitchListTile(secondary: const Icon(Icons.visibility_off, color: Colors.red), title: Text('Sembunyikan Online', style: TextStyle(color: textColor)), value: _hideOnline, activeColor: const Color(0xFF25D366), onChanged: (val) async { final prefs = await SharedPreferences.getInstance(); await prefs.setBool('mod_hide_online', val); setState(() => _hideOnline = val); }),

          const Divider(),
          SwitchListTile(secondary: const Icon(Icons.smart_toy, color: Colors.blue), title: Text('Auto-Reply (Robot)', style: TextStyle(color: textColor)), value: _isAutoReplyOn, activeColor: const Color(0xFF25D366), onChanged: (val) async { final prefs = await SharedPreferences.getInstance(); await prefs.setBool('mod_auto_reply', val); setState(() => _isAutoReplyOn = val); }),
          if (_isAutoReplyOn) Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: TextField(controller: _autoReplyController, style: TextStyle(color: textColor), decoration: InputDecoration(labelText: 'Pesan Auto-Reply', border: const OutlineInputBorder(), suffixIcon: IconButton(icon: const Icon(Icons.check, color: Color(0xFF25D366)), onPressed: () async { final prefs = await SharedPreferences.getInstance(); await prefs.setString('mod_auto_reply_msg', _autoReplyController.text); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Disimpan'))); })))),
        ],
      ),
    );
  }
}
