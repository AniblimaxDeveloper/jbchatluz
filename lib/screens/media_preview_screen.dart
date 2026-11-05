import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class MediaPreviewScreen extends StatefulWidget {
  final XFile file;
  final bool isViewOnce;
  final Function(String caption) onSend;

  const MediaPreviewScreen({
    super.key,
    required this.file,
    required this.isViewOnce,
    required this.onSend,
  });

  @override
  State<MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends State<MediaPreviewScreen> {
  final _captionController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.isViewOnce ? 'Foto Sekali Lihat' : 'Pratinjau Foto'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Image.file(File(widget.file.path), fit: BoxFit.contain),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.black,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _captionController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Tambahkan keterangan...',
                      hintStyle: const TextStyle(color: Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF1F2C34),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFF25D366),
                  radius: 24,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: () {
                      widget.onSend(_captionController.text.trim());
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
