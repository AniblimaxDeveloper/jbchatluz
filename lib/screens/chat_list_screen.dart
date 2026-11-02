import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'status_screen.dart';
import 'ai_screen.dart';
import 'create_group_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<String> _pinnedRooms = [];

  @override
  void initState() {
    super.initState();
    _loadPinnedRooms();
  }

  Future<void> _loadPinnedRooms() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pinnedRooms = prefs.getStringList('pinned_rooms') ?? [];
    });
  }

  Future<void> _togglePin(String roomId) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_pinnedRooms.contains(roomId)) {
        _pinnedRooms.remove(roomId);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chat dilepas dari sematan')));
      } else {
        _pinnedRooms.add(roomId);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chat disematkan')));
      }
    });
    await prefs.setStringList('pinned_rooms', _pinnedRooms);
  }

  void _showCreateMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.group, color: Color(0xFF00A884)),
                title: const Text('Grup Baru'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateGroupScreen(type: 'group')));
                },
              ),
              ListTile(
                leading: const Icon(Icons.campaign, color: Colors.orange),
                title: const Text('Channel Baru'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateGroupScreen(type: 'channel')));
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF202C33) : const Color(0xFF075E54),
        title: const Text('JBchatluz', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.camera_alt), onPressed: () {}),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'settings') Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              if (value == 'profile') Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
              if (value == 'logout') FirebaseAuth.instance.signOut();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'profile', child: Text('Profil Saya')),
              const PopupMenuItem(value: 'settings', child: Text('Pengaturan')),
              const PopupMenuItem(value: 'logout', child: Text('Keluar')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFF00A884), child: Icon(Icons.add, color: Colors.white)),
            title: Text('Status Saya', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatusScreen())),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('rooms')
                  .where('members', arrayContains: user?.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final rooms = snapshot.data!.docs;
                
                List<Map<String, dynamic>> allRooms = [];
                // Tambahkan Room Global statis
                allRooms.add({
                  'id': 'global',
                  'name': 'Ruang Global',
                  'lastMessage': 'Ngobrol dengan semua orang',
                  'time': 'Sekarang',
                  'avatar': 'https://i.pravatar.cc/150?img=11',
                  'type': 'global',
                  'lastMessageTime': Timestamp.now(),
                });

                for (var doc in rooms) {
                  final data = doc.data() as Map<String, dynamic>;
                  allRooms.add({
                    'id': doc.id,
                    'name': data['name'] ?? 'Tanpa Nama',
                    'lastMessage': data['lastMessage'] ?? 'Belum ada pesan',
                    'time': data['lastMessageTime'] != null ? DateFormat('HH:mm').format((data['lastMessageTime'] as Timestamp).toDate()) : '',
                    'avatar': data['type'] == 'channel' ? 'https://cdn-icons-png.flaticon.com/512/2983/2983785.png' : 'https://i.pravatar.cc/150?img=${doc.id.hashCode % 70}',
                    'type': data['type'],
                    'lastMessageTime': data['lastMessageTime'] ?? Timestamp.now(),
                  });
                }

                // Urutkan: Pin paling atas, lalu berdasarkan waktu
                allRooms.sort((a, b) {
                  final aPinned = _pinnedRooms.contains(a['id']);
                  final bPinned = _pinnedRooms.contains(b['id']);
                  if (aPinned && !bPinned) return -1;
                  if (!aPinned && bPinned) return 1;
                  return (b['lastMessageTime'] as Timestamp).compareTo(a['lastMessageTime'] as Timestamp);
                });

                List<Widget> tiles = allRooms.map((room) {
                  final isPinned = _pinnedRooms.contains(room['id']);
                  return ListTile(
                    leading: CircleAvatar(radius: 26, backgroundImage: NetworkImage(room['avatar'])),
                    title: Text(room['name'], style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                    subtitle: Row(
                      children: [
                        if (isPinned) ...[
                          const Icon(Icons.push_pin, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                        ],
                        Expanded(child: Text(room['lastMessage'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.grey : Colors.black54))),
                      ],
                    ),
                    trailing: Text(room['time'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    onLongPress: () => _togglePin(room['id']),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(roomId: room['id'], roomName: room['name']))),
                  );
                }).toList();

                tiles.add(ListTile(
                  leading: const CircleAvatar(backgroundColor: Colors.purple, child: Icon(Icons.smart_toy, color: Colors.white)),
                  title: Text('Gemini AI', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                  subtitle: Text('Tanya apa saja ke AI', style: TextStyle(color: isDark ? Colors.grey : Colors.black54)),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiScreen())),
                ));

                return ListView(children: tiles);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateMenu,
        backgroundColor: const Color(0xFF25D366),
        child: const Icon(Icons.add_comment, color: Colors.white),
      ),
    );
  }
}
