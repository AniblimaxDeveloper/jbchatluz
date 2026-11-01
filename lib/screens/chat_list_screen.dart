import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF075E54),
        title: const Text('JBchatluz', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: () {},
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'settings') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              } else if (value == 'profile') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
              } else if (value == 'logout') {
                FirebaseAuth.instance.signOut();
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem(value: 'profile', child: Text('Profil Saya')),
                const PopupMenuItem(value: 'settings', child: Text('Pengaturan')),
                const PopupMenuItem(value: 'logout', child: Text('Keluar')),
              ];
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.white,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(30),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: 'Tanya Meta AI atau cari chat',
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          // Chat List
          Expanded(
            child: ListView(
              children: [
                _buildChatTile(
                  context, 
                  'Ruang Global', 
                  'Halo semuanya, ada yang online?', 
                  '14:30', 
                  'https://i.pravatar.cc/150?img=11', 
                  'global', 
                  2
                ),
                _buildChatTile(
                  context, 
                  'Ruang Teknologi', 
                  'Diskusi seputar IT', 
                  'Kemarin', 
                  'https://i.pravatar.cc/150?img=33', 
                  'tech', 
                  0
                ),
                _buildChatTile(
                  context, 
                  'Meta AI', 
                  'Halo! Saya asisten AI Anda.', 
                  'Senin', 
                  'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Meta_Platforms_Inc._logo.svg/1200px-Meta_Platforms_Inc._logo.svg.png', 
                  'ai', 
                  0
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xFF25D366),
        child: const Icon(Icons.chat, color: Colors.white),
      ),
    );
  }

  Widget _buildChatTile(BuildContext context, String title, String subtitle, String time, String avatarUrl, String roomId, int unreadCount) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 26,
        backgroundImage: NetworkImage(avatarUrl),
        backgroundColor: Colors.grey[300],
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600])),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(time, style: TextStyle(color: unreadCount > 0 ? const Color(0xFF25D366) : Colors.grey, fontSize: 12)),
          const SizedBox(height: 6),
          if (unreadCount > 0)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: Color(0xFF25D366), shape: BoxShape.circle),
              child: Text(unreadCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(roomId: roomId, roomName: title)));
      },
    );
  }
}
