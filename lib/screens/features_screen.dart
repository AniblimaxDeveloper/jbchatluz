import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FeaturesScreen extends StatefulWidget {
  const FeaturesScreen({super.key});

  @override
  State<FeaturesScreen> createState() => _FeaturesScreenState();
}

class _FeaturesScreenState extends State<FeaturesScreen> {
  bool _videoAutoDownload = true;
  bool _ttsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _videoAutoDownload = prefs.getBool('video_auto_download') ?? true;
      _ttsEnabled = prefs.getBool('tts_enabled') ?? true;
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  void _showLinkGenerator() {
    final jbId = FirebaseAuth.instance.currentUser?.email?.split('@')[0] ?? "user";
    final link = "jbch.at/$jbId";
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tautan Profil Saya'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Bagikan tautan ini agar orang lain bisa menemukan Anda dengan mudah.'),
            const SizedBox(height: 16),
            SelectableText(link, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF25D366))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup')),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: link));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tautan disalin!')));
              Navigator.pop(context);
            },
            child: const Text('Salin'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : Colors.white,
      appBar: AppBar(title: const Text('Pusat Fitur Baru'), backgroundColor: const Color(0xFF075E54), foregroundColor: Colors.white),
      body: ListView(
        children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('Fitur Interaktif & Bisnis', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          SwitchListTile(
            secondary: const Icon(Icons.volume_up, color: Colors.blue),
            title: Text('Baca Pesan (TTS)', style: TextStyle(color: textColor)),
            subtitle: const Text('Aktifkan tombol "Baca Keras" di obrolan'),
            value: _ttsEnabled,
            activeColor: const Color(0xFF25D366),
            onChanged: (val) { setState(() => _ttsEnabled = val); _saveSetting('tts_enabled', val); },
          ),
          ListTile(
            leading: const Icon(Icons.link, color: Colors.orange),
            title: Text('Generator Tautan Profil', style: TextStyle(color: textColor)),
            subtitle: const Text('Buat tautan khusus untuk profil Anda'),
            onTap: _showLinkGenerator,
          ),
          const Divider(),
          const Padding(padding: EdgeInsets.all(16), child: Text('Pengaturan Media', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          SwitchListTile(
            secondary: const Icon(Icons.videocam, color: Colors.purple),
            title: Text('Auto-Download Video', style: TextStyle(color: textColor)),
            subtitle: const Text('Unduh video secara otomatis (Hemat data)'),
            value: _videoAutoDownload,
            activeColor: const Color(0xFF25D366),
            onChanged: (val) { setState(() => _videoAutoDownload = val); _saveSetting('video_auto_download', val); },
          ),
        ],
      ),
    );
  }
}
