import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'status_screen.dart';
import 'ai_screen.dart';
import 'create_group_screen.dart';
import 'add_contact_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final String myUid = FirebaseAuth.instance.currentUser?.uid ?? "";

  void _showCreateMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person_add, color: Colors.blue),
                title: const Text('Tambah Kontak (via ID)'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AddContactScreen()));
                },
              ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF202C33) : const Color(0xFF075E54),
        title: Text('JBchatluz', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: isDark ? Colors.white : Colors.white)),
        actions: [
          IconButton(icon: const Icon(Icons.camera_alt, color: Colors.white), onPressed: () {}),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
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
          // Fitur Status Saya
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFF00A884), 
              child: Icon(Icons.add, color: Colors.white)
            ),
            title: Text('Status Saya', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
            subtitle: Text('Ketuk untuk menambah pembaruan status', style: TextStyle(color: isDark ? Colors.grey : Colors.black54)),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatusScreen())),
          ),
          const Divider(height: 1),
          
          // Daftar Chat
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('rooms').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error memuat data: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF00A884)));
                }

                // Ambil semua room, filter di memori agar tidak butuh index Firestore
                final allRooms = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['type'] == 'group' || data['type'] == 'channel' || (data['members'] != null && (data['members'] as List).contains(myUid));
                }).toList();

                // Urutkan berdasarkan waktu terakhir
                allRooms.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  Timestamp aTime = aData['lastMessageTime'] ?? Timestamp.now();
                  Timestamp bTime = bData['lastMessageTime'] ?? Timestamp.now();
                  return bTime.compareTo(aTime);
                });

                List<Widget> tiles = [
                  // Room Global (Hardcoded)
                  ListTile(
                    leading: const CircleAvatar(radius: 26, backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=11')),
                    title: Text('Ruang Global', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                    subtitle: Text('Ngobrol dengan semua orang', style: TextStyle(color: isDark ? Colors.grey : Colors.black54)),
                    trailing: const Text('Sekarang', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen(roomId: 'global', roomName: 'Ruang Global'))),
                  ),
                ];

                // Tambahkan Room dari Database
                for (var doc in allRooms) {
                  final data = doc.data() as Map<String, dynamic>;
                  final roomId = doc.id;
                  final isPrivate = data['type'] == 'private';
                  final time = data['lastMessageTime'] != null ? DateFormat('HH:mm').format((data['lastMessageTime'] as Timestamp).toDate()) : '';

                  if (isPrivate) {
                    // Untuk chat pribadi, cari UID lawan bicara
                    String otherUid = (data['members'] as List).firstWhere((id) => id != myUid, orElse: () => '');
                    
                    tiles.add(FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(otherUid).get(),
                      builder: (context, userSnap) {
                        String name = 'Pengguna';
                        String photoUrl = 'https://i.pravatar.cc/150?img=12';
                        String status = data['lastMessage'] ?? 'Belum ada pesan';
                        Color statusColor = isDark ? Colors.grey : Colors.black54;

                        if (userSnap.hasData && userSnap.data!.exists) {
                          final uData = userSnap.data!.data() as Map<String, dynamic>;
                          name = uData['displayName'] ?? uData['email'] ?? 'Pengguna';
                          if (uData['photoURL'] != null && uData['photoURL'].toString().isNotEmpty) photoUrl = uData['photoURL'];
                          
                          if (uData['isOnline'] == true) {
                            status = 'Online';
                            statusColor = const Color(0xFF25D366);
                          } else if (uData['lastSeen'] != null) {
                            status = 'Terakhir dilihat ${DateFormat('HH:mm').format((uData['lastSeen'] as Timestamp).toDate())}';
                          }
                        }

                        return ListTile(
                          leading: CircleAvatar(radius: 26, backgroundImage: NetworkImage(photoUrl)),
                          title: Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                          subtitle: Text(status, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: statusColor)),
                          trailing: Text(time, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(roomId: roomId, roomName: name))),
                        );
                      },
                    ));
                  } else {
                    // Untuk Grup / Channel
                    tiles.add(ListTile(
                      leading: CircleAvatar(radius: 26, backgroundColor: Colors.blueGrey, child: Icon(data['type'] == 'channel' ? Icons.campaign : Icons.group, color: Colors.white)),
                      title: Text(data['name'] ?? 'Grup', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                      subtitle: Text(data['lastMessage'] ?? 'Belum ada pesan', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.grey : Colors.black54)),
                      trailing: Text(time, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(roomId: roomId, roomName: data['name'] ?? 'Grup'))),
                    ));
                  }
                }

                // Tambahkan AI
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
