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
        content: const Text('Fitur ini akan segera hadir di pembaruan berikutnya.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup'))],
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
                leading: const Icon(Icons.group), title: const Text('Grup baru'),
                onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateGroupScreen(type: 'group'))); },
              ),
              ListTile(leading: const Icon(Icons.people), title: const Text('Komunitas baru'), onTap: () { Navigator.pop(context); _showFeatureDialog('Komunitas'); }),
              ListTile(leading: const Icon(Icons.star), title: const Text('Berbintang'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const StarredMessagesScreen())); }),
              ListTile(leading: const Icon(Icons.settings), title: const Text('Pengaturan'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())); }),
            ],
          ),
        );
      },
    );
  }

  void _showChatOptions(String roomId, bool isArchived, bool isPinned) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(isPinned ? Icons.push_pin_outlined : Icons.push_pin),
                title: Text(isPinned ? 'Lepas Sematan' : 'Sematkan Chat'),
                onTap: () {
                  Navigator.pop(context);
                  FirebaseFirestore.instance.collection('rooms').doc(roomId).update({'isPinned': !isPinned});
                },
              ),
              ListTile(
                leading: Icon(isArchived ? Icons.unarchive : Icons.archive),
                title: Text(isArchived ? 'Keluarkan dari Arsip' : 'Arsipkan Chat'),
                onTap: () {
                  Navigator.pop(context);
                  FirebaseFirestore.instance.collection('rooms').doc(roomId).update({'isArchived': !isArchived});
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Hapus Chat', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  FirebaseFirestore.instance.collection('rooms').doc(roomId).delete();
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
    final bgColor = isDark ? const Color(0xFF0B141A) : Colors.white;
    final appBarColor = isDark ? const Color(0xFF1F2C34) : const Color(0xFF075E54);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        title: Text(_currentIndex == 0 ? 'JBchatluz' : _currentIndex == 1 ? 'Pembaruan' : _currentIndex == 2 ? 'Komunitas' : 'Panggilan', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white)),
        actions: [
          if (_currentIndex == 0) ...[
            IconButton(icon: const Icon(Icons.camera_alt_outlined, color: Colors.white), onPressed: () {}),
            IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: _showPopupMenu),
          ] else ...[
            IconButton(icon: const Icon(Icons.search, color: Colors.white), onPressed: () {}),
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
          ? FloatingActionButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddContactScreen())), backgroundColor: const Color(0xFF25D366), child: const Icon(Icons.add_comment, color: Colors.white))
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
              decoration: InputDecoration(hintText: 'Tanya Meta AI atau cari', hintStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]), prefixIcon: const Icon(Icons.search, color: Colors.grey), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 12)),
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
                  label: Text(filter), selected: isSelected, selectedColor: isDark ? const Color(0xFF005C4B) : const Color(0xFFD9FDD3),
                  labelStyle: TextStyle(color: isSelected ? (isDark ? Colors.white : const Color(0xFF075E54)) : Colors.grey),
                  backgroundColor: isDark ? const Color(0xFF1F2C34) : Colors.white, onSelected: (val) => setState(() => _activeFilter = filter),
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

              // Filter
              if (_activeFilter == 'Grup') allRooms = allRooms.where((doc) => (doc.data() as Map)['type'] == 'group' || (doc.data() as Map)['type'] == 'channel').toList();

              // Pisahkan Arsip dan Non-Arsip
              final archivedRooms = allRooms.where((doc) => (doc.data() as Map)['isArchived'] == true).toList();
              var activeRooms = allRooms.where((doc) => (doc.data() as Map)['isArchived'] != true).toList();

              // Sorting: Pin ke atas, lalu waktu
              activeRooms.sort((a, b) {
                final aPinned = (a.data() as Map)['isPinned'] == true;
                final bPinned = (b.data() as Map)['isPinned'] == true;
                if (aPinned && !bPinned) return -1;
                if (!aPinned && bPinned) return 1;
                Timestamp aTime = (a.data() as Map)['lastMessageTime'] ?? Timestamp.now();
                Timestamp bTime = (b.data() as Map)['lastMessageTime'] ?? Timestamp.now();
                return bTime.compareTo(aTime);
              });

              List<Widget> tiles = [];

              // Tampilkan folder Arsip jika ada
              if (archivedRooms.isNotEmpty) {
                tiles.add(ListTile(
                  leading: const Icon(Icons.archive, color: Colors.grey),
                  title: Text('Diarsipkan', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                  trailing: Text('${archivedRooms.length}', style: const TextStyle(color: Color(0xFF25D366))),
                  onTap: () {
                    // Logika membuka folder arsip bisa ditambahkan di sini
                  },
                ));
              }

              for (var doc in activeRooms) {
                final data = doc.data() as Map<String, dynamic>;
                final isPrivate = data['type'] == 'private';
                final isPinned = data['isPinned'] == true;
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
                        if (uData['photoBase64'] != null && uData['photoBase64'].toString().isNotEmpty) avatarImage = MemoryImage(base64Decode(uData['photoBase64']));
                      }

                      if (_searchQuery.isNotEmpty && !name.toLowerCase().contains(_searchQuery) && !status.toLowerCase().contains(_searchQuery)) return const SizedBox.shrink();

                      return ListTile(
                        leading: CircleAvatar(radius: 26, backgroundImage: avatarImage ?? const NetworkImage('https://i.pravatar.cc/150?img=12')),
                        title: Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                        subtitle: Row(
                          children: [
                            if (isPinned) const Icon(Icons.push_pin, size: 14, color: Colors.grey),
                            if (isPinned) const SizedBox(width: 4),
                            Expanded(child: Text(status, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.grey : Colors.black54))),
                          ],
                        ),
                        trailing: Text(time, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        onLongPress: () => _showChatOptions(doc.id, false, isPinned),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(roomId: doc.id, roomName: name))),
                      );
                    },
                  ));
                } else {
                  final groupName = data['name'] ?? 'Grup';
                  if (_searchQuery.isNotEmpty && !groupName.toLowerCase().contains(_searchQuery)) continue;

                  tiles.add(ListTile(
                    leading: CircleAvatar(radius: 26, backgroundColor: Colors.blueGrey, child: Icon(data['type'] == 'channel' ? Icons.campaign : Icons.group, color: Colors.white)),
                    title: Text(groupName, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                    trailing: Text(time, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    onLongPress: () => _showChatOptions(doc.id, false, isPinned),
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
            Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: isDark ? const Color(0xFF1F2C34) : Colors.green[50], shape: BoxShape.circle), child: const Icon(Icons.groups, size: 80, color: Color(0xFF25D366))),
            const SizedBox(height: 24),
            Text('Tetap terhubung dengan komunitas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor), textAlign: TextAlign.center),
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
            _buildCallAction(Icons.call, 'Telepon', isDark, () async { await launchUrl(Uri(scheme: 'tel', path: '')); }),
            _buildCallAction(Icons.calendar_today, 'Jadwal', isDark, () => _showFeatureDialog('Jadwal')),
            _buildCallAction(Icons.dialpad, 'Keypad', isDark, () => _showFeatureDialog('Keypad')),
            _buildCallAction(Icons.favorite_border, 'Favorit', isDark, () => _showFeatureDialog('Favorit')),
          ],
        ),
        const SizedBox(height: 24),
        Text('Terbaru', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
      ],
    );
  }

  Widget _buildCallAction(IconData icon, String label, bool isDark, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Column(
        children: [
          CircleAvatar(radius: 30, backgroundColor: isDark ? const Color(0xFF1F2C34) : Colors.grey[100], child: Icon(icon, color: isDark ? Colors.white : Colors.black, size: 28)),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: isDark ? Colors.grey : Colors.black87, fontSize: 13)),
        ],
      ),
    );
  }
}
