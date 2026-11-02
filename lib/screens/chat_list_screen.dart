import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
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
  int _currentIndex = 0;
  String _activeFilter = 'Semua';
  final String myUid = FirebaseAuth.instance.currentUser?.uid ?? "";
  final TextEditingController _searchController = TextEditingController();

  void _showNewChatMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(padding: EdgeInsets.all(16), child: Text('Pilih opsi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
              ListTile(
                leading: const Icon(Icons.person_add),
                title: const Text('Tambah Kontak (via ID)'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AddContactScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.group),
                title: const Text('Grup baru'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateGroupScreen(type: 'group')));
                },
              ),
              ListTile(
                leading: const Icon(Icons.campaign),
                title: const Text('Komunitas baru'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.cell_tower),
                title: const Text('Daftar siaran'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPopupMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: const Icon(Icons.group),
                title: const Text('Grup baru'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateGroupScreen(type: 'group')));
                },
              ),
              ListTile(
                leading: const Icon(Icons.people),
                title: const Text('Komunitas baru'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.cell_tower),
                title: const Text('Daftar siaran'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.devices),
                title: const Text('Perangkat tertaut'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.star),
                title: const Text('Berbintang'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.done_all),
                title: const Text('Baca semua'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Pengaturan'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: const Text('Alihkan akun'),
                onTap: () {
                  Navigator.pop(context);
                  FirebaseAuth.instance.signOut();
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
        title: Text('JBchatluz', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white)),
        actions: [
          IconButton(icon: const Icon(Icons.camera_alt, color: Colors.white), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: _showPopupMenu),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildChatsTab(isDark),
          const StatusScreen(),
          _buildPlaceholderTab('Komunitas', isDark),
          _buildPlaceholderTab('Panggilan', isDark),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
        selectedItemColor: isDark ? const Color(0xFF25D366) : const Color(0xFF075E54),
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.circle_notifications), label: 'Pembaruan'),
          BottomNavigationBarItem(icon: Icon(Icons.groups), label: 'Komunitas'),
          BottomNavigationBarItem(icon: Icon(Icons.call), label: 'Panggilan'),
        ],
      ),
      floatingActionButton: _currentIndex == 0 
          ? FloatingActionButton(
              onPressed: _showNewChatMenu,
              backgroundColor: const Color(0xFF25D366),
              child: const Icon(Icons.add_comment, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildPlaceholderTab(String title, bool isDark) {
    return Center(child: Text('Halaman $title segera hadir', style: TextStyle(color: isDark ? Colors.white : Colors.black)));
  }

  Widget _buildChatsTab(bool isDark) {
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            decoration: BoxDecoration(color: isDark ? const Color(0xFF202C33) : Colors.grey[200], borderRadius: BorderRadius.circular(30)),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: 'Tanya Meta AI atau cari',
                hintStyle: TextStyle(color: isDark ? Colors.grey : Colors.grey[600]),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),

        // Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: ['Semua', 'Belum dibaca', 'Favorit', 'Grup'].map((filter) {
              final isSelected = _activeFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(filter),
                  selected: isSelected,
                  selectedColor: isDark ? const Color(0xFF005C4B) : const Color(0xFFD9FDD3),
                  labelStyle: TextStyle(color: isSelected ? (isDark ? Colors.white : const Color(0xFF075E54)) : Colors.grey),
                  backgroundColor: isDark ? const Color(0xFF202C33) : Colors.grey[100],
                  onSelected: (val) => setState(() => _activeFilter = filter),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),

        // Folder (Locked / Archived)
        ListTile(
          leading: const Icon(Icons.lock, color: Colors.grey),
          title: Text('Chat Terkunci', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
          onTap: () {},
        ),
        ListTile(
          leading: const Icon(Icons.archive, color: Colors.grey),
          title: Text('Diarsipkan', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
          onTap: () {},
        ),
        const Divider(height: 1),

        // List Chat
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('rooms').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF00A884)));
              
              final allRooms = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['type'] == 'group' || data['type'] == 'channel' || (data['members'] != null && (data['members'] as List).contains(myUid));
              }).toList();

              allRooms.sort((a, b) {
                Timestamp aTime = (a.data() as Map)['lastMessageTime'] ?? Timestamp.now();
                Timestamp bTime = (b.data() as Map)['lastMessageTime'] ?? Timestamp.now();
                return bTime.compareTo(aTime);
              });

              List<Widget> tiles = [];
              for (var doc in allRooms) {
                final data = doc.data() as Map<String, dynamic>;
                final isPrivate = data['type'] == 'private';
                final time = data['lastMessageTime'] != null ? DateFormat('HH:mm').format((data['lastMessageTime'] as Timestamp).toDate()) : '';

                if (isPrivate) {
                  String otherUid = (data['members'] as List).firstWhere((id) => id != myUid, orElse: () => '');
                  tiles.add(FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(otherUid).get(),
                    builder: (context, userSnap) {
                      String name = 'Pengguna';
                      String status = data['lastMessage'] ?? '';
                      ImageProvider? avatarImage;

                      if (userSnap.hasData && userSnap.data!.exists) {
                        final uData = userSnap.data!.data() as Map<String, dynamic>;
                        name = uData['displayName'] ?? uData['email'] ?? 'Pengguna';
                        
                        // Tampilkan Foto Profil dari Base64 atau URL
                        if (uData['photoBase64'] != null && uData['photoBase64'].toString().isNotEmpty) {
                          avatarImage = MemoryImage(base64Decode(uData['photoBase64']));
                        } else if (uData['photoURL'] != null && uData['photoURL'].toString().isNotEmpty) {
                          avatarImage = NetworkImage(uData['photoURL']);
                        }
                      }

                      return ListTile(
                        leading: CircleAvatar(
                          radius: 26, 
                          backgroundImage: avatarImage ?? const NetworkImage('https://i.pravatar.cc/150?img=12')
                        ),
                        title: Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                        subtitle: Text(status, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.grey : Colors.black54)),
                        trailing: Text(time, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(roomId: doc.id, roomName: name))),
                      );
                    },
                  ));
                } else {
                  tiles.add(ListTile(
                    leading: CircleAvatar(radius: 26, backgroundColor: Colors.blueGrey, child: Icon(data['type'] == 'channel' ? Icons.campaign : Icons.group, color: Colors.white)),
                    title: Text(data['name'] ?? 'Grup', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                    trailing: Text(time, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(roomId: doc.id, roomName: data['name'] ?? 'Grup'))),
                  ));
                }
              }

              tiles.add(ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.purple, child: Icon(Icons.smart_toy, color: Colors.white)),
                title: Text('Gemini AI', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiScreen())),
              ));

              return ListView(children: tiles);
            },
          ),
        ),
      ],
    );
  }
}
