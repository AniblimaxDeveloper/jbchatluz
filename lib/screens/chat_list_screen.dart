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
              // Mengambil room di mana user adalah anggota
              stream: FirebaseFirestore.instance
                  .collection('rooms')
                  .where('members', arrayContains: user?.uid)
                  .orderBy('lastMessageTime', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final rooms = snapshot.data!.docs;
                
                // Tambahkan Room Global secara statis jika belum ada di DB
                List<Widget> tiles = [
                  _buildChatTile(context, 'Ruang Global', 'Ngobrol dengan semua orang', 'Sekarang', 'https://i.pravatar.cc/150?img=11', 'global', isDark),
                ];

                for (var doc in rooms) {
                  final data = doc.data() as Map<String, dynamic>;
                  final isChannel = data['type'] == 'channel';
                  final time = data['lastMessageTime'] != null ? DateFormat('HH:mm').format((data['lastMessageTime'] as Timestamp).toDate()) : '';
                  
                  tiles.add(_buildChatTile(
                    context, 
                    data['name'] ?? 'Tanpa Nama', 
                    data['lastMessage'] ?? 'Belum ada pesan', 
                    time, 
                    isChannel ? 'https://cdn-icons-png.flaticon.com/512/2983/2983785.png' : 'https://i.pravatar.cc/150?img=${doc.id.hashCode % 70}', 
                    doc.id, 
                    isDark
                  ));
                }

                tiles.add(_buildAiTile(context, isDark));

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

  Widget _buildChatTile(BuildContext context, String title, String subtitle, String time, String avatarUrl, String roomId, bool isDark) {
    return ListTile(
      leading: CircleAvatar(radius: 26, backgroundImage: NetworkImage(avatarUrl)),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.grey : Colors.black54)),
      trailing: Text(time, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(roomId: roomId, roomName: title))),
    );
  }

  Widget _buildAiTile(BuildContext context, bool isDark) {
    return ListTile(
      leading: const CircleAvatar(backgroundColor: Colors.purple, child: Icon(Icons.smart_toy, color: Colors.white)),
      title: Text('Gemini AI', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
      subtitle: Text('Tanya apa saja ke AI', style: TextStyle(color: isDark ? Colors.grey : Colors.black54)),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiScreen())),
    );
  }
}
