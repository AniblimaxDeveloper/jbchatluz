import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('JBchatluz'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          )
        ],
      ),
      body: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
              child: user?.photoURL == null ? const Icon(Icons.person) : null,
            ),
            title: Text(user?.displayName ?? 'Pengguna'),
            subtitle: Text(user?.email ?? 'Email tidak tersedia'),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              children: [
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.public)),
                  title: const Text('Ruang Global'),
                  subtitle: const Text('Ngobrol dengan semua orang'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChatScreen(roomId: 'global', roomName: 'Ruang Global'),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.code)),
                  title: const Text('Ruang Teknologi'),
                  subtitle: const Text('Diskusi seputar IT'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChatScreen(roomId: 'tech', roomName: 'Ruang Teknologi'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
