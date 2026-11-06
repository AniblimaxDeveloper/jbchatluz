import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final String myUid = FirebaseAuth.instance.currentUser?.uid ?? "";
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _results = [];
    });

    try {
      final roomsSnap = await FirebaseFirestore.instance
          .collection('rooms')
          .where('members', arrayContains: myUid)
          .get();

      final List<Map<String, dynamic>> allResults = [];

      for (var room in roomsSnap.docs) {
        final roomData = room.data();
        String roomName = roomData['name'] ?? 'Chat';

        // Jika chat pribadi, ambil nama lawan bicara
        if (roomData['type'] == 'private') {
          final members = (roomData['members'] as List?) ?? [];
          final otherUid = members.firstWhere((id) => id != myUid, orElse: () => '');
          if (otherUid.isNotEmpty) {
            final userSnap = await FirebaseFirestore.instance.collection('users').doc(otherUid).get();
            if (userSnap.exists) {
              roomName = userSnap.data()?['displayName'] ?? 'Pengguna';
            }
          }
        }

        // Cari pesan di dalam ruangan ini (menggunakan prefix match)
        final msgsSnap = await room.reference
            .collection('messages')
            .where('text', isGreaterThanOrEqualTo: query)
            .where('text', isLessThan: '$query\uf8ff')
            .limit(10)
            .get();

        for (var msg in msgsSnap.docs) {
          allResults.add({
            'roomId': room.id,
            'roomName': roomName,
            ...msg.data(),
          });
        }
      }

      setState(() => _results = allResults);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1F2C34) : const Color(0xFF075E54),
        foregroundColor: Colors.white,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Cari semua pesan...',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
          onSubmitted: (_) => _performSearch(),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: _performSearch),
        ],
      ),
      body: _isSearching
          ? const Center(child: CircularProgressIndicator())
          : !_hasSearched
              ? const Center(child: Text('Ketik kata kunci untuk mencari pesan di semua chat.', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center))
              : _results.isEmpty
                  ? const Center(child: Text('Tidak ada pesan yang ditemukan.', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final data = _results[index];
                        final time = data['timestamp'] != null
                            ? DateFormat('dd/MM/yy HH:mm').format((data['timestamp'] as Timestamp).toDate())
                            : '';
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isDark ? const Color(0xFF25D366) : const Color(0xFF075E54),
                            child: const Icon(Icons.chat, color: Colors.white),
                          ),
                          title: Text(data['roomName'] ?? 'Chat', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['text'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.grey : Colors.black54)),
                              Text(time, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(roomId: data['roomId'], roomName: data['roomName'] ?? 'Chat')));
                          },
                        );
                      },
                    ),
    );
  }
}
