import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _aboutController = TextEditingController();
  bool _isUploading = false;
  String _jbId = "Memuat...";
  String _email = "";
  String? _photoBase64;
  
  bool _hideBlueTick = false;
  bool _hideOnlineStatus = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadModSettings();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _nameController.text = data['displayName'] ?? '';
        _aboutController.text = data['about'] ?? 'Tersedia';
        _jbId = data['jbId'] ?? 'Error';
        _email = data['email'] ?? '';
        _photoBase64 = data['photoBase64'];
      });
    }
  }

  Future<void> _loadModSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hideBlueTick = prefs.getBool('mod_hide_tick') ?? false;
      _hideOnlineStatus = prefs.getBool('mod_hide_online') ?? false;
    });
  }

  Future<void> _saveModSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    if (key == 'mod_hide_online') {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'isOnline': value ? false : true});
      }
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 10);
    if (image == null) return;

    setState(() => _isUploading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final bytes = await File(image.path).readAsBytes();
      final base64String = base64Encode(bytes);

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'photoBase64': base64String});
      
      if (mounted) {
        setState(() => _photoBase64 = base64String);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto profil diubah!')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _updateName() async {
    setState(() => _isUploading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'displayName': _nameController.text.trim(),
      });
      await user.updateDisplayName(_nameController.text.trim());
      
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nama diperbarui!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _updateAbout() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'about': _aboutController.text.trim(),
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status Tentang diperbarui')));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0B141A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final appBarColor = isDark ? const Color(0xFF1F2C34) : const Color(0xFF075E54);

    ImageProvider? profileImage;
    if (_photoBase64 != null && _photoBase64!.isNotEmpty) {
      profileImage = MemoryImage(base64Decode(_photoBase64!));
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Profil'),
        backgroundColor: appBarColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.qr_code), onPressed: () {}),
          IconButton(icon: const Icon(Icons.edit), onPressed: () {}),
        ],
      ),
      body: ListView(
        children: [
          const SizedBox(height: 24),
          Center(
            child: GestureDetector(
              onTap: _isUploading ? null : _pickAndUploadPhoto,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 70,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: profileImage,
                    child: profileImage == null ? const Icon(Icons.person, size: 70) : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(color: Color(0xFF25D366), shape: BoxShape.circle),
                      child: _isUploading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.camera_alt, color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          
          _buildProfileItem(Icons.person_outline, 'Nama', _nameController.text, textColor, () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Ubah Nama'),
                content: TextField(controller: _nameController, decoration: const InputDecoration(border: OutlineInputBorder())),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
                  TextButton(onPressed: () { _updateName(); Navigator.pop(context); }, child: const Text('Simpan')),
                ],
              ),
            );
          }),
          
          _buildProfileItem(Icons.info_outline, 'Tentang', _aboutController.text, textColor, () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Ubah Status'),
                content: TextField(controller: _aboutController, decoration: const InputDecoration(border: OutlineInputBorder())),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
                  TextButton(onPressed: () { _updateAbout(); Navigator.pop(context); }, child: const Text('Simpan')),
                ],
              ),
            );
          }),
          
          _buildProfileItem(Icons.alternate_email, 'Nama pengguna', _jbId, textColor, () {}),
          _buildProfileItem(Icons.phone_outlined, 'Email', _email, textColor, () {}),
          _buildProfileItem(Icons.link, 'Tautan', 'Tambah tautan', textColor, () {}, isLink: true),
          
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('MOD Privasi (Eksklusif)', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.done_all, color: Colors.blue),
            title: Text('Sembunyikan Centang Biru', style: TextStyle(color: textColor)),
            value: _hideBlueTick,
            activeColor: const Color(0xFF25D366),
            onChanged: (val) {
              setState(() => _hideBlueTick = val);
              _saveModSetting('mod_hide_tick', val);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.visibility_off, color: Colors.orange),
            title: Text('Sembunyikan Status Online', style: TextStyle(color: textColor)),
            value: _hideOnlineStatus,
            activeColor: const Color(0xFF25D366),
            onChanged: (val) {
              setState(() => _hideOnlineStatus = val);
              _saveModSetting('mod_hide_online', val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfileItem(IconData icon, String label, String value, Color textColor, VoidCallback onTap, {bool isLink = false}) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey),
      title: Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 14)),
      subtitle: Text(value, style: TextStyle(color: isLink ? const Color(0xFF25D366) : textColor, fontSize: 17, fontWeight: isLink ? FontWeight.normal : FontWeight.w500)),
      onTap: onTap,
    );
  }
}
