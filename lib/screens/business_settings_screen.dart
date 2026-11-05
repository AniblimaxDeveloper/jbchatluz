import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BusinessSettingsScreen extends StatefulWidget {
  const BusinessSettingsScreen({super.key});

  @override
  State<BusinessSettingsScreen> createState() => _BusinessSettingsScreenState();
}

class _BusinessSettingsScreenState extends State<BusinessSettingsScreen> {
  final _greetingController = TextEditingController();
  final _awayController = TextEditingController();
  bool _isGreetingOn = false;
  bool _isAwayOn = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isGreetingOn = prefs.getBool('biz_greeting_on') ?? false;
      _greetingController.text = prefs.getString('biz_greeting_msg') ?? 'Halo! Terima kasih telah menghubungi kami. Ada yang bisa dibantu?';
      _isAwayOn = prefs.getBool('biz_away_on') ?? false;
      _awayController.text = prefs.getString('biz_away_msg') ?? 'Mohon maaf, saat ini saya sedang sibuk. Saya akan membalas pesan Anda secepatnya.';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biz_greeting_on', _isGreetingOn);
    await prefs.setString('biz_greeting_msg', _greetingController.text.trim());
    await prefs.setBool('biz_away_on', _isAwayOn);
    await prefs.setString('biz_away_msg', _awayController.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pengaturan Bisnis disimpan!')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : Colors.white,
      appBar: AppBar(title: const Text('Fitur Bisnis'), backgroundColor: const Color(0xFF075E54), foregroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Otomatisasi Pesan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 16),
          
          // AUTO-GREETING
          SwitchListTile(
            secondary: const Icon(Icons.waving_hand, color: Colors.orange),
            title: Text('Pesan Salam Otomatis', style: TextStyle(color: textColor)),
            subtitle: const Text('Kirim salam ke kontak baru secara otomatis'),
            value: _isGreetingOn,
            activeColor: const Color(0xFF25D366),
            onChanged: (val) => setState(() => _isGreetingOn = val),
          ),
          if (_isGreetingOn)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _greetingController,
                maxLines: 3,
                style: TextStyle(color: textColor),
                decoration: const InputDecoration(labelText: 'Isi Pesan Salam', border: OutlineInputBorder()),
              ),
            ),
          const Divider(),
          
          // AUTO-AWAY
          SwitchListTile(
            secondary: const Icon(Icons.do_not_disturb_on, color: Colors.red),
            title: Text('Pesan Saat Sibuk', style: TextStyle(color: textColor)),
            subtitle: const Text('Balas otomatis saat Anda sedang sibuk'),
            value: _isAwayOn,
            activeColor: const Color(0xFF25D366),
            onChanged: (val) => setState(() => _isAwayOn = val),
          ),
          if (_isAwayOn)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _awayController,
                maxLines: 3,
                style: TextStyle(color: textColor),
                decoration: const InputDecoration(labelText: 'Isi Pesan Sibuk', border: OutlineInputBorder()),
              ),
            ),
          
          const SizedBox(height: 32),
          SizedBox(
            height: 50,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
              onPressed: _saveSettings,
              child: const Text('Simpan Pengaturan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}
