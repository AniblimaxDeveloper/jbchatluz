import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'status_screen.dart';
import 'starred_messages_screen.dart';
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
  String _searchQuery = "";
  final String myUid = FirebaseAuth.instance.currentUser?.uid ?? "";

  void _showFeatureDialog(String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: const Text('Fitur ini sedang dalam pengembangan dan akan segera hadir di pembaruan berikutnya.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup')),
        ],
      ),
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
                onTap: () { Navigator.pop(context); _showFeatureDialog('Komunitas Baru'); },
              ),
              ListTile(
                leading: const Icon(Icons.cell_tower),
                title: const Text('Daftar siaran'),
                onTap: () { Navigator.pop(context); _showFeatureDialog('Daftar Siaran'); },
              ),
              ListTile(
                leading: const Icon(Icons.devices),
                title: const Text('Perangkat tertaut'),
                onTap: () { Navigator.pop(context); _showFeatureDialog('Perangkat Tertaut'); },
              ),
              ListTile(
                leading: const Icon(Icons.star),
                title: const Text('Berbintang'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const StarredMessagesScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.done_all),
                title: const Text('Baca semua'),
                onTap: () async {
                  Navigator.pop(context);
                  final rooms = await FirebaseFirestore.instance.collection('rooms').where('members', arrayContains: myUid).get();
                  for(var room in rooms.docs) {
                    final msgs = await room.reference.collection('messages').where('status', isEqualTo: 'sent').get();
                    for (var m in msgs.docs) { m.reference.update({'status': 'read'}); }
                  }
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Semua chat ditandai telah dibaca')));
                },
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
                onTap: () { Navigator.pop(context); FirebaseAuth.instance.signOut(); },
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
    final bgColor = isDark ? const Color(0xFF0B141A) : Colors.white;
    final appBarColor = isDark ? const Color(0xFF1F2C34) : const Color(0xFF075E54);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        title: _currentIndex == 0 
            ? Text('JBchatluz', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white))
            : _currentIndex == 1
                ? Text('Pembaruan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white))
                : _currentIndex == 2
                    ? Text('Komunitas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white))
                    : Text('Panggilan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white)),
        actions: [
          if (_currentIndex == 0) ...[
            IconButton(icon: const Icon(Icons.camera_alt_outlined, color: Colors.white), onPressed: () => _showFeatureDialog('Kamera Cepat')),
            IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: _showPopupMenu),
          ] else ...[
            IconButton(icon: const Icon(Icons.search, color: Colors.white), onPressed: () => _showFeatureDialog('Pencarian Global')),
            IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: () {}),
          ]
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildChatsTab(isDark),
          const StatusScreen(),
          _buildCommunitiesTab(isDark),
          _buildCallsTab(isDark),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
        selectedItemColor: isDark ? const Color(0xFF25D366) : const Color(0xFF075E54),
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), activeIcon: Icon(Icons.chat_bubble), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.circle_outlined), activeIcon: Icon(Icons.circle), label: 'Pembaruan'),
          BottomNavigationBarItem(icon: Icon(Icons.groups_outlined), activeIcon: Icon(Icons.groups), label: 'Komunitas'),
          BottomNavigationBarItem(icon: Icon(Icons.call_outlined), activeIcon: Icon(Icons.call), label: 'Panggilan'),
        ],
      ),
      floatingActionButton: _currentIndex == 0 
          ? FloatingActionButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddContactScreen())),
              backgroundColor: const Color(0xFF25D366),
              child: const Icon(Icons.add_comment, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildChatsTab(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Container(
            height: 45,
            decoration: BoxDecoration(color: isDark ? const Color(0xFF2A3942) : Colors.grey[200], borderRadius: BorderRadius.circular(30)),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Tanya Meta AI atau cari',
                hintStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
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
                  backgroundColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
                  onSelected: (val) => setState(() => _activeFilter = filter),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('rooms').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF00A884)));
              
              var allRooms = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['type'] == 'group' || data['type'] == 'channel' || (data['members'] != null && (data['members'] as List).contains(myUid));
              }).toList();

              // Logika Filter
              if (_activeFilter == 'Grup') {
                allRooms = allRooms.where((doc) => (doc.data() as Map)['type'] == 'group' || (doc.data() as Map)['type'] == 'channel').toList();
              } else if (_activeFilter == 'Belum dibaca') {
                // Simulasi filter belum dibaca (bisa disesuaikan dengan status read)
                allRooms = allRooms.where((doc) => true).toList(); 
              }

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
                        if (uData['photoBase64'] != null && uData['photoBase64'].toString().isNotEmpty) {
                          avatarImage = MemoryImage(base64Decode(uData['photoBase64']));
                        }
                      }

                      // Logika Pencarian
                      if (_searchQuery.isNotEmpty && !name.toLowerCase().contains(_searchQuery) && !status.toLowerCase().contains(_searchQuery)) {
                        return const SizedBox.shrink();
                      }

                      return ListTile(
                        leading: CircleAvatar(radius: 26, backgroundImage: avatarImage ?? const NetworkImage('https://i.pravatar.cc/150?img=12')),
                        title: Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                        subtitle: Text(status, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.grey : Colors.black54)),
                        trailing: Text(time, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(roomId: doc.id, roomName: name))),
                      );
                    },
                  ));
                } else {
                  final groupName = data['name'] ?? 'Grup';
                  if (_searchQuery.isNotEmpty && !groupName.toLowerCase().contains(_searchQuery)) {
                    continue;
                  }

                  tiles.add(ListTile(
                    leading: CircleAvatar(radius: 26, backgroundColor: Colors.blueGrey, child: Icon(data['type'] == 'channel' ? Icons.campaign : Icons.group, color: Colors.white)),
                    title: Text(groupName, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                    trailing: Text(time, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(roomId: doc.id, roomName: groupName))),
                  ));
                }
              }

              return ListView(children: tiles);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCommunitiesTab(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: isDark ? const Color(0xFF1F2C34) : Colors.green[50], shape: BoxShape.circle),
              child: const Icon(Icons.groups, size: 80, color: Color(0xFF25D366)),
            ),
            const SizedBox(height: 24),
            Text('Tetap terhubung dengan komunitas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            const Text('Komunitas menyatukan anggota dalam grup berdasarkan topik dan memudahkan untuk menerima pengumuman admin.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _showFeatureDialog('Mulai Komunitas'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
              child: const Text('Mulai komunitas Anda'),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCallsTab(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildCallAction(Icons.call, 'Telepon', isDark, () async {
              final Uri launchUri = Uri(scheme: 'tel', path: '');
              await launchUrl(launchUri);
            }),
            _buildCallAction(Icons.calendar_today, 'Jadwal', isDark, () => _showFeatureDialog('Jadwal Panggilan')),
            _buildCallAction(Icons.dialpad, 'Keypad', isDark, () => _showFeatureDialog('Keypad Panggilan')),
            _buildCallAction(Icons.favorite_border, 'Favorit', isDark, () => _showFeatureDialog('Kontak Favorit')),
          ],
        ),
        const SizedBox(height: 24),
        Text('Terbaru', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
        const SizedBox(height: 16),
        Center(
          child: Column(
            children: [
              const Icon(Icons.call, size: 60, color: Colors.grey),
              const SizedBox(height: 12),
              Text('Belum ada panggilan terbaru', style: TextStyle(color: Colors.grey[500])),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildCallAction(IconData icon, String label, bool isDark, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: isDark ? const Color(0xFF1F2C34) : Colors.grey[100],
            child: Icon(icon, color: isDark ? Colors.white : Colors.black, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: isDark ? Colors.grey : Colors.black87, fontSize: 13)),
        ],
      ),
    );
  }
}
