import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'status_screen.dart';
import 'ai_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

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
          // Tombol Status (Story)
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFF00A884),
              child: Icon(Icons.add, color: Colors.white),
            ),
            title: Text('Status Saya', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
            subtitle: Text('Ketuk untuk menambah pembaruan status', style: TextStyle(color: isDark ? Colors.grey : Colors.black54)),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatusScreen())),
          ),
          const Divider(height: 1),
          
          // Daftar Chat
          Expanded(
            child: ListView(
              children: [
                _buildChatTile(context, 'Ruang Global', 'Ngobrol dengan semua orang', '14:30', 'https://i.pravatar.cc/150?img=11', 'global', 2, isDark),
                _buildChatTile(context, 'Ruang Teknologi', 'Diskusi seputar IT', 'Kemarin', 'https://i.pravatar.cc/150?img=33', 'tech', 0, isDark),
                _buildAiTile(context, isDark),
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

  Widget _buildChatTile(BuildContext context, String title, String subtitle, String time, String avatarUrl, String roomId, int unreadCount, bool isDark) {
    return ListTile(
      leading: CircleAvatar(radius: 26, backgroundImage: NetworkImage(avatarUrl)),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
      subtitle: Text(subtitle, style: TextStyle(color: isDark ? Colors.grey : Colors.black54)),
      trailing: Text(time, style: TextStyle(color: isDark ? Colors.grey : Colors.grey, fontSize: 12)),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(roomId: roomId, roomName: title))),
    );
  }

  Widget _buildAiTile(BuildContext context, bool isDark) {
    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: Colors.purple,
        child: Icon(Icons.smart_toy, color: Colors.white),
      ),
      title: Text('Gemini AI', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
      subtitle: Text('Tanya apa saja ke AI', style: TextStyle(color: isDark ? Colors.grey : Colors.black54)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiScreen())),
    );
  }
}
