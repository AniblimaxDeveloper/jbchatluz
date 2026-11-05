import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descController = TextEditingController();
  File? _imageFile;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image != null) setState(() => _imageFile = File(image.path));
  }

  Future<void> _saveProduct() async {
    if (_nameController.text.isEmpty || _priceController.text.isEmpty || _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nama, Harga, dan Foto wajib diisi!')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final myUid = FirebaseAuth.instance.currentUser!.uid;
      // Upload foto ke ImgBB
      const String imgbbApiKey = String.fromEnvironment('IMGBB_API_KEY');
      final request = http.MultipartRequest('POST', Uri.parse('https://api.imgbb.com/1/upload?key=$imgbbApiKey'));
      request.files.add(await http.MultipartFile.fromPath('image', _imageFile!.path));
      final response = await request.send();
      final jsonData = jsonDecode(await response.stream.bytesToString());
      
      if (jsonData['success'] == true) {
        final imageUrl = jsonData['data']['url'];
        
        // Simpan ke Firestore
        await FirebaseFirestore.instance.collection('users').doc(myUid).collection('catalog').add({
          'name': _nameController.text.trim(),
          'price': _priceController.text.trim(),
          'description': _descController.text.trim(),
          'imageUrl': imageUrl,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produk berhasil ditambahkan!')));
          Navigator.pop(context);
        }
      } else {
        throw Exception('Gagal upload foto');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : Colors.white,
      appBar: AppBar(title: const Text('Tambah Produk'), backgroundColor: const Color(0xFF075E54), foregroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 200,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(12), image: _imageFile != null ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover) : null),
              child: _imageFile == null ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo, size: 50, color: Colors.grey), SizedBox(height: 8), Text('Pilih Foto Produk', style: TextStyle(color: Colors.grey))])) : null,
            ),
          ),
          const SizedBox(height: 16),
          TextField(controller: _nameController, style: TextStyle(color: textColor), decoration: const InputDecoration(labelText: 'Nama Produk', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _priceController, keyboardType: TextInputType.number, style: TextStyle(color: textColor), decoration: const InputDecoration(labelText: 'Harga (Rp)', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _descController, maxLines: 3, style: TextStyle(color: textColor), decoration: const InputDecoration(labelText: 'Deskripsi', border: OutlineInputBorder())),
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
              onPressed: _isLoading ? null : _saveProduct,
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Simpan Produk', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}
