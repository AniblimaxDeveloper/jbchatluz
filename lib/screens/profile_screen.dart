import 'dart:io';
import 'dart:convert'; // Untuk Base64
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  bool _isUploading = false;
  String _jbId = "Memuat...";
  String _email = "";
  String? _photoBase64; // Ganti dari URL ke Base64
  
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
        _jbId = data['jbId'] ?? 'Error';
        _email = data['email'] ?? '';
        _photoBase64 = data['photoBase64']; // Ambil Base64
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
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'isOnline': value ? false : true,
        });
      }
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    // Kompres sangat kecil (kualitas 10) agar tidak memenuhi database Firestore
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 10);
    if (image == null) return;

    setState(() => _isUploading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final bytes = await File(image.path).readAsBytes();
      final base64String = base64Encode(bytes); // Ubah foto jadi teks

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'photoBase64': base64String, // Simpan ke database
        'photoURL': '', // Kosongkan URL lama
      });
      
      if (mounted) {
        setState(() => _photoBase64 = base64String);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto profil berhasil diubah!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
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
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nama berhasil diperbarui!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Tampilan Foto
    ImageProvider? profileImage;
    if (_photoBase64 != null && _photoBase64!.isNotEmpty) {
      profileImage = MemoryImage(base64Decode(_photoBase64!));
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : Colors.white,
      appBar: AppBar(
        title: const Text('Profil Saya'),
        backgroundColor: const Color(0xFF075E54),
        foregroundColor: Colors.white,
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
                    radius: 60,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: profileImage,
                    child: profileImage == null ? const Icon(Icons.person, size: 60) : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: Color(0xFF00A884), shape: BoxShape.circle),
                      child: _isUploading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _nameController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                labelText: 'Nama Lengkap',
                prefixIcon: const Icon(Icons.person),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: _isUploading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check, color: Color(0xFF00A884)),
                  onPressed: _isUploading ? null : _updateName,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.alternate_email),
            title: Text('JBchatluz ID', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            subtitle: SelectableText(_jbId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF00A884))),
          ),
          ListTile(
            leading: const Icon(Icons.email),
            title: Text('Email', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            subtitle: Text(_email, style: const TextStyle(color: Colors.grey)),
          ),
          
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('MOD Privasi', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.done_all, color: Colors.blue),
            title: Text('Sembunyikan Centang Biru', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            value: _hideBlueTick,
            activeColor: const Color(0xFF00A884),
            onChanged: (val) {
              setState(() => _hideBlueTick = val);
              _saveModSetting('mod_hide_tick', val);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.visibility_off, color: Colors.orange),
            title: Text('Sembunyikan Status Online', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            value: _hideOnlineStatus,
            activeColor: const Color(0xFF00A884),
            onChanged: (val) {
              setState(() => _hideOnlineStatus = val);
              _saveModSetting('mod_hide_online', val);
            },
          ),
        ],
      ),
    );
  }
}
