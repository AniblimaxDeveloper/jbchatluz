import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'status_screen.dart';
import 'starred_messages_screen.dart';
import 'create_group_screen.dart';
import 'add_contact_screen.dart';
import 'contacts_screen.dart';
import 'broadcast_screen.dart';
import 'linked_devices_screen.dart';

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
  bool _isLockedFolderOpen = false;
  bool _isArchiveFolderOpen = false;

  void _showFeatureDialog(String title) { showDialog(context: context, builder: (context) => AlertDialog(title: Text(title), content: const Text('Fitur ini akan segera hadir.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup'))])); }

  Future<bool> _verifyPin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString('app_pin');
    if (savedPin == null || savedPin.isEmpty) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Atur PIN di Pengaturan.'))); return false; }
    final pinController = TextEditingController();
    final result = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Masukkan PIN'), content: TextField(controller: pinController, keyboardType: TextInputType.number, obscureText: true, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'PIN')), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')), TextButton(onPressed: () { if (pinController.text == savedPin) { Navigator.pop(context, true); } else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN Salah!'))); } }, child: const Text('Buka'))]));
    return result ?? false;
  }

  void _showPopupMenu() {
    showModalBottomSheet(context: context, builder: (context) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.contacts), title: const Text('Buku Kontak'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactsScreen())); }),
      ListTile(leading: const Icon(Icons.group), title: const Text('Grup baru'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateGroupScreen(type: 'group'))); }),
      ListTile(leading: const Icon(Icons.cell_tower), title: const Text('Daftar siaran'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const BroadcastScreen())); }),
      ListTile(leading: const Icon(Icons.devices), title: const Text('Perangkat tertaut'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const LinkedDevicesScreen())); }),
      ListTile(leading: const Icon(Icons.star), title: const Text('Berbintang'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const StarredMessagesScreen())); }),
      ListTile(leading: const Icon(Icons.settings), title: const Text('Pengaturan'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())); }),
    ])));
  }

  void _showChatOptions(String roomId, bool isArchived, bool isPinned, bool isLocked, bool isFavorite) {
    showModalBottomSheet(context: context, builder: (context) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: Icon(isFavorite ? Icons.star : Icons.star_border, color: Colors.orange), title: Text(isFavorite ? 'Hapus dari Favorit' : 'Tandai Favorit'), onTap: () { Navigator.pop(context); FirebaseFirestore.instance.collection('rooms').doc(roomId).update({'isFavorite': !isFavorite}); }),
      ListTile(leading: Icon(isLocked ? Icons.lock_open : Icons.lock), title: Text(isLocked ? 'Buka Kunci Obrolan' : 'Kunci Obrolan'), onTap: () { Navigator.pop(context); FirebaseFirestore.instance.collection('rooms').doc(roomId).update({'isLocked': !isLocked}); if (!isLocked) _isLockedFolderOpen = false; }),
      ListTile(leading: Icon(isPinned ? Icons.push_pin_outlined : Icons.push_pin), title: Text(isPinned ? 'Lepas Sematan' : 'Sematkan Chat'), onTap: () { Navigator.pop(context); FirebaseFirestore.instance.collection('rooms').doc(roomId).update({'isPinned': !isPinned}); }),
      ListTile(leading: Icon(isArchived ? Icons.unarchive : Icons.archive), title: Text(isArchived ? 'Keluarkan dari Arsip' : 'Arsipkan Chat'), onTap: () { Navigator.pop(context); FirebaseFirestore.instance.collection('rooms').doc(roomId).update({'isArchived': !isArchived}); }),
      ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text('Hapus Chat', style: TextStyle(color: Colors.red)), onTap: () { Navigator.pop(context); FirebaseFirestore.instance.collection('rooms').doc(roomId).delete(); }),
    ])));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1F2C34) : const Color(0xFF075E54),
        title: Text(_currentIndex == 0 ? 'JBchatluz' : _currentIndex == 1 ? 'Pembaruan' : _currentIndex == 2 ? 'Komunitas' : _currentIndex == 3 ? 'Panggilan' : 'Profil', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white)),
        actions: [
          if (_currentIndex == 0) ...[
            IconButton(icon: const Icon(Icons.camera_alt_outlined, color: Colors.white), onPressed: () {}),
            IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: _showPopupMenu),
          ] else if (_currentIndex == 4) ...[
            IconButton(icon: const Icon(Icons.edit, color: Colors.white), onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())); }),
          ] else ...[
            IconButton(icon: const Icon(Icons.search, color: Colors.white), onPressed: () {}),
          ]
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: [_buildChatsTab(isDark), const StatusScreen(), _buildCommunitiesTab(isDark), _buildCallsTab(isDark), _buildProfileTab(isDark)]),
      bottomNavigationBar: Container(
        height: 65, decoration: BoxDecoration(color: isDark ? const Color(0xFF1F2C34) : Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -2))]),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _buildNavItem(0, Icons.chat_bubble_outline, Icons.chat_bubble, 'Chat', isDark),
          _buildNavItem(1, Icons.circle_outlined, Icons.circle, 'Pembaruan', isDark),
          _buildNavItem(2, Icons.groups_outlined, Icons.groups, 'Komunitas', isDark),
          _buildNavItem(3, Icons.call_outlined, Icons.call, 'Panggilan', isDark),
          _buildNavItem(4, Icons.person_outline, Icons.person, 'Profil', isDark),
        ]),
      ),
      floatingActionButton: _currentIndex == 0 ? FloatingActionButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddContactScreen())), backgroundColor: const Color(0xFF25D366), child: const Icon(Icons.add_comment, color: Colors.white)) : null,
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label, bool isDark) {
    final isSelected = _currentIndex == index;
    final activeColor = isDark ? const Color(0xFF25D366) : const Color(0xFF075E54);
    final inactiveColor = Colors.grey;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300), curve: Curves.easeOutQuint,
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 16 : 12, vertical: 8),
        decoration: BoxDecoration(color: isSelected ? activeColor.withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(20)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(isSelected ? activeIcon : icon, color: isSelected ? activeColor : inactiveColor, size: 24),
          AnimatedSize(duration: const Duration(milliseconds: 300), child: isSelected ? Padding(padding: const EdgeInsets.only(top: 2), child: Text(label, style: TextStyle(color: activeColor, fontSize: 10, fontWeight: FontWeight.bold))) : const SizedBox.shrink()),
        ]),
      ),
    );
  }

  Widget _buildChatsTab(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    return Column(
      children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Container(height: 45, decoration: BoxDecoration(color: isDark ? const Color(0xFF2A3942) : Colors.grey[200], borderRadius: BorderRadius.circular(30)), child: TextField(onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()), style: TextStyle(color: textColor), decoration: InputDecoration(hintText: 'Tanya Meta AI atau cari', hintStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]), prefixIcon: const Icon(Icons.search, color: Colors.grey), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 12))))),
        SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(children: ['Semua', 'Belum dibaca', 'Favorit', 'Grup'].map((filter) { final isSelected = _activeFilter == filter; return Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(filter), selected: isSelected, selectedColor: isDark ? const Color(0xFF005C4B) : const Color(0xFFD9FDD3), labelStyle: TextStyle(color: isSelected ? (isDark ? Colors.white : const Color(0xFF075E54)) : Colors.grey), backgroundColor: isDark ? const Color(0xFF1F2C34) : Colors.white, onSelected: (val) => setState(() => _activeFilter = filter))); }).toList())),
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('rooms').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF00A884)));
              var allRooms = snapshot.data!.docs.where((doc) { final data = doc.data() as Map<String, dynamic>; return data['type'] == 'group' || data['type'] == 'channel' || (data['members'] != null && (data['members'] as List).contains(myUid)); }).toList();
              
              // FILTER CHAT TERKUNCI
              final lockedRooms = allRooms.where((doc) => (doc.data() as Map)['isLocked'] == true).toList();
              final archivedRooms = allRooms.where((doc) => (doc.data() as Map)['isArchived'] == true && (doc.data() as Map)['isLocked'] != true).toList();
              var activeRooms = allRooms.where((doc) => (doc.data() as Map)['isLocked'] != true && (doc.data() as Map)['isArchived'] != true).toList();

              if (_activeFilter == 'Grup') {
                activeRooms = activeRooms.where((doc) => (doc.data() as Map)['type'] == 'group' || (doc.data() as Map)['type'] == 'channel').toList();
              } else if (_activeFilter == 'Favorit') {
                activeRooms = activeRooms.where((doc) => (doc.data() as Map)['isFavorite'] == true).toList();
              }

              activeRooms.sort((a, b) { final aPinned = (a.data() as Map)['isPinned'] == true; final bPinned = (b.data() as Map)['isPinned'] == true; if (aPinned && !bPinned) return -1; if (!aPinned && bPinned) return 1; Timestamp aTime = (a.data() as Map)['lastMessageTime'] ?? Timestamp.now(); Timestamp bTime = (b.data() as Map)['lastMessageTime'] ?? Timestamp.now(); return bTime.compareTo(aTime); });
              
              List<Widget> tiles = [];
              
              if (archivedRooms.isNotEmpty && _activeFilter == 'Semua') { tiles.add(ListTile(leading: const Icon(Icons.archive, color: Colors.grey), title: Text('Diarsipkan', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)), trailing: Text('${archivedRooms.length}', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)), onTap: () => setState(() => _isArchiveFolderOpen = !_isArchiveFolderOpen))); if (_isArchiveFolderOpen) { for (var doc in archivedRooms) { _buildRoomTile(doc, textColor, isDark, tiles, showArchived: true); } } }
              
              // TAMPILKAN FOLDER TERKUNCI
              if (lockedRooms.isNotEmpty && _activeFilter == 'Semua') { 
                tiles.add(ListTile(leading: const Icon(Icons.lock, color: Color(0xFF25D366)), title: Text('Chat Terkunci', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)), trailing: Text('${lockedRooms.length}', style: const TextStyle(color: Color(0xFF25D366), fontWeight: FontWeight.bold)), onTap: () async { if (!_isLockedFolderOpen) { final unlocked = await _verifyPin(); if (unlocked) setState(() => _isLockedFolderOpen = true); } else { setState(() => _isLockedFolderOpen = false); } })); 
                if (_isLockedFolderOpen) { for (var doc in lockedRooms) { _buildRoomTile(doc, textColor, isDark, tiles, showArchived: false); } } 
              }
              
              if (activeRooms.isEmpty && tiles.isEmpty) { return const Center(child: Text('Tidak ada chat.', style: TextStyle(color: Colors.grey))); }
              
              for (var doc in activeRooms) { _buildRoomTile(doc, textColor, isDark, tiles, showArchived: false); }
              return ListView(children: tiles);
            },
          ),
        ),
      ],
    );
  }

  void _buildRoomTile(DocumentSnapshot doc, Color textColor, bool isDark, List<Widget> tiles, {required bool showArchived}) {
    final data = doc.data() as Map<String, dynamic>;
    final isPrivate = data['type'] == 'private'; final isPinned = data['isPinned'] == true; final isLocked = data['isLocked'] == true; final isArchived = data['isArchived'] == true; final isFavorite = data['isFavorite'] == true;
    final time = data['lastMessageTime'] != null ? DateFormat('HH:mm').format((data['lastMessageTime'] as Timestamp).toDate()) : '';
    if (isArchived && !showArchived) return;
    if (isPrivate) {
      String otherUid = (data['members'] as List).firstWhere((id) => id != myUid, orElse: () => '');
      tiles.add(FutureBuilder<DocumentSnapshot>(future: FirebaseFirestore.instance.collection('users').doc(otherUid).get(), builder: (context, userSnap) {
        String name = 'Pengguna'; String status = data['lastMessage'] ?? ''; ImageProvider? avatarImage;
        if (userSnap.hasData && userSnap.data!.exists) { final uData = userSnap.data!.data() as Map<String, dynamic>; name = uData['displayName'] ?? uData['email'] ?? 'Pengguna'; if (uData['photoBase64'] != null && uData['photoBase64'].toString().isNotEmpty) avatarImage = MemoryImage(base64Decode(uData['photoBase64'])); }
        if (_searchQuery.isNotEmpty && !name.toLowerCase().contains(_searchQuery) && !status.toLowerCase().contains(_searchQuery)) return const SizedBox.shrink();
        return ListTile(
          leading: CircleAvatar(radius: 26, backgroundImage: avatarImage ?? const NetworkImage('https://i.pravatar.cc/150?img=12')), 
          title: Row(children: [Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)), if (isLocked) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.lock, size: 14, color: Colors.grey)), if (isFavorite) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.star, size: 14, color: Colors.orange))]), 
          subtitle: Row(children: [if (isPinned) const Icon(Icons.push_pin, size: 14, color: Colors.grey), if (isPinned) const SizedBox(width: 4), Expanded(child: Text(status, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.grey : Colors.black54)))]), 
          trailing: Text(time, style: const TextStyle(color: Colors.grey, fontSize: 12)), 
          onLongPress: () => _showChatOptions(doc.id, isArchived, isPinned, isLocked, isFavorite), 
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(roomId: doc.id, roomName: name)))
        );
      }));
    } else {
      final groupName = data['name'] ?? 'Grup'; if (_searchQuery.isNotEmpty && !groupName.toLowerCase().contains(_searchQuery)) return;
      tiles.add(ListTile(
        leading: CircleAvatar(radius: 26, backgroundColor: Colors.blueGrey, child: Icon(data['type'] == 'channel' ? Icons.campaign : Icons.group, color: Colors.white)), 
        title: Row(children: [Text(groupName, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)), if (isLocked) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.lock, size: 14, color: Colors.grey)), if (isFavorite) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.star, size: 14, color: Colors.orange))]), 
        trailing: Text(time, style: const TextStyle(color: Colors.grey, fontSize: 12)), 
        onLongPress: () => _showChatOptions(doc.id, isArchived, isPinned, isLocked, isFavorite), 
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(roomId: doc.id, roomName: groupName)))
      ));
    }
  }

  Widget _buildCommunitiesTab(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: isDark ? const Color(0xFF1F2C34) : Colors.green[50], shape: BoxShape.circle), child: const Icon(Icons.groups, size: 80, color: Color(0xFF25D366))), const SizedBox(height: 24), Text('Tetap terhubung dengan komunitas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor), textAlign: TextAlign.center)])));
  }

  Widget _buildCallsTab(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    return Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_buildCallAction(Icons.call, 'Telepon', isDark, () async { await launchUrl(Uri(scheme: 'tel', path: '')); }), _buildCallAction(Icons.calendar_today, 'Jadwal', isDark, () => _showFeatureDialog('Jadwal')), _buildCallAction(Icons.dialpad, 'Keypad', isDark, () => _showFeatureDialog('Keypad')), _buildCallAction(Icons.favorite_border, 'Favorit', isDark, () => _showFeatureDialog('Favorit'))])),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Align(alignment: Alignment.centerLeft, child: Text('Terbaru', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)))), const SizedBox(height: 8),
      Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('call_logs').where('callerId', isEqualTo: myUid).orderBy('timestamp', descending: true).snapshots(), builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('Belum ada panggilan terbaru', style: TextStyle(color: Colors.grey)));
        return ListView.builder(itemCount: docs.length, itemBuilder: (context, index) {
          final data = docs[index].data() as Map<String, dynamic>; final isVideo = data['type'] == 'video'; final time = data['timestamp'] != null ? DateFormat('dd/MM HH:mm').format((data['timestamp'] as Timestamp).toDate()) : ''; final receiverId = data['receiverId'];
          return FutureBuilder<DocumentSnapshot>(future: FirebaseFirestore.instance.collection('users').doc(receiverId).get(), builder: (context, userSnap) {
            String name = 'Pengguna'; if (userSnap.hasData && userSnap.data!.exists) name = userSnap.data!['displayName'] ?? 'Pengguna';
            return ListTile(leading: CircleAvatar(backgroundColor: Colors.grey, child: Icon(isVideo ? Icons.videocam : Icons.call, color: Colors.white)), title: Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)), subtitle: Row(children: [const Icon(Icons.call_made, size: 14, color: Colors.green), const SizedBox(width: 4), Text(time, style: const TextStyle(color: Colors.grey))]), trailing: Icon(isVideo ? Icons.videocam : Icons.call, color: const Color(0xFF25D366)));
          });
        });
      })),
    ]);
  }

  Widget _buildCallAction(IconData icon, String label, bool isDark, VoidCallback onTap) { return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(50), child: Column(children: [CircleAvatar(radius: 30, backgroundColor: isDark ? const Color(0xFF1F2C34) : Colors.grey[100], child: Icon(icon, color: isDark ? Colors.white : Colors.black, size: 28)), const SizedBox(height: 8), Text(label, style: TextStyle(color: isDark ? Colors.grey : Colors.black87, fontSize: 13))])); }

  Widget _buildProfileTab(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(myUid).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!.data() as Map<String, dynamic>;
        ImageProvider? avatar;
        if (data['photoBase64'] != null && data['photoBase64'].toString().isNotEmpty) avatar = MemoryImage(base64Decode(data['photoBase64']));

        return ListView(padding: const EdgeInsets.all(16), children: [
          const SizedBox(height: 20),
          Center(child: CircleAvatar(radius: 60, backgroundColor: Colors.grey, backgroundImage: avatar, child: avatar == null ? const Icon(Icons.person, size: 60, color: Colors.white) : null)),
          const SizedBox(height: 16),
          Center(child: Text(data['displayName'] ?? 'User', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor))),
          Center(child: Text(data['email'] ?? '', style: const TextStyle(fontSize: 16, color: Colors.grey))),
          const SizedBox(height: 24),
          ListTile(leading: const Icon(Icons.info_outline), title: Text('Tentang', style: TextStyle(color: textColor)), subtitle: Text(data['about'] ?? 'Tersedia', style: const TextStyle(color: Colors.grey))),
          ListTile(leading: const Icon(Icons.alternate_email), title: Text('JBchatluz ID', style: TextStyle(color: textColor)), subtitle: Text(data['jbId'] ?? 'Error', style: const TextStyle(color: Color(0xFF25D366), fontWeight: FontWeight.bold))),
          const Divider(),
          ListTile(leading: const Icon(Icons.settings), title: Text('Pengaturan', style: TextStyle(color: textColor)), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
          ListTile(leading: const Icon(Icons.edit), title: Text('Edit Profil', style: TextStyle(color: textColor)), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()))),
          ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text('Keluar', style: TextStyle(color: Colors.red)), onTap: () => FirebaseAuth.instance.signOut()),
        ]);
      },
    );
  }
}
