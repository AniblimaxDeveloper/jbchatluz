import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FakeChatScreen extends StatefulWidget {
  const FakeChatScreen({super.key});

  @override
  State<FakeChatScreen> createState() => _FakeChatScreenState();
}

class _FakeChatScreenState extends State<FakeChatScreen> {
  final _msgController = TextEditingController();
  final _nameController = TextEditingController(text: "Teman Palsu");
  final List<Map<String, dynamic>> _messages = [];
  bool _isEditingName = false;

  void _addMessage(bool isMe) {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add({
        'text': text,
        'isMe': isMe,
        'time': DateFormat('HH:mm').format(DateTime.now()),
      });
      _msgController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFEFEAE2),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1F2C34) : const Color(0xFF075E54),
        foregroundColor: Colors.white,
        title: _isEditingName 
            ? TextField(
                controller: _nameController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(hintText: 'Nama Kontak', hintStyle: TextStyle(color: Colors.white70)),
                onSubmitted: (_) => setState(() => _isEditingName = false),
              )
            : Text(_nameController.text),
        actions: [
          IconButton(icon: const Icon(Icons.edit), onPressed: () => setState(() => _isEditingName = !_isEditingName)),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Align(
                  alignment: msg['isMe'] ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: msg['isMe'] ? const Color(0xFFD9FDD3) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(msg['text'], style: const TextStyle(color: Colors.black, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(msg['time'], style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            color: isDark ? const Color(0xFF1F2C34) : Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      hintText: 'Ketik pesan palsu...',
                      hintStyle: TextStyle(color: isDark ? Colors.grey : Colors.black54),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.blue),
                  onPressed: () => _addMessage(false),
                  tooltip: 'Pesan Masuk (Kiri)',
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF25D366)),
                  onPressed: () => _addMessage(true),
                  tooltip: 'Pesan Keluar (Kanan)',
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
