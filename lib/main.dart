import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'screens/auth_screen.dart';
import 'screens/chat_list_screen.dart';
import 'screens/lock_screen.dart';
import 'notification_service.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
final ValueNotifier<String> fontNotifier = ValueNotifier("Default");
final ValueNotifier<Color> bubbleColorNotifier = ValueNotifier(const Color(0xFFD9FDD3));
final ValueNotifier<double> fontSizeNotifier = ValueNotifier(1.0);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try { await Firebase.initializeApp(); } catch (e) { runApp(MaterialApp(home: Scaffold(body: Center(child: Text("Firebase Error: $e"))))); return; }
  try { await NotificationService.initialize(); } catch (e) { debugPrint("Notif error: $e"); }

  final prefs = await SharedPreferences.getInstance();
  themeNotifier.value = (prefs.getBool('darkMode') ?? false) ? ThemeMode.dark : ThemeMode.light;
  fontNotifier.value = prefs.getString('app_font') ?? "Default";
  bubbleColorNotifier.value = Color(prefs.getInt('bubble_color') ?? 0xFFD9FDD3);
  fontSizeNotifier.value = prefs.getDouble('font_size_scale') ?? 1.0;

  runApp(const JBChatLuzApp());
}

class JBChatLuzApp extends StatefulWidget {
  const JBChatLuzApp({super.key});
  @override
  State<JBChatLuzApp> createState() => _JBChatLuzAppState();
}

class _JBChatLuzAppState extends State<JBChatLuzApp> with WidgetsBindingObserver {
  bool _isLocked = false;
  bool _isCheckingLock = true;
  final LocalAuthentication _auth = LocalAuthentication();
  Timer? _scheduleTimer;

  @override
  void initState() { 
    super.initState(); 
    WidgetsBinding.instance.addObserver(this); 
    _checkAppLock(); 
    _startScheduleChecker(); // Memulai timer pengecekan jadwal
  }
  
  @override
  void dispose() { 
    _scheduleTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this); 
    super.dispose(); 
  }

  void _startScheduleChecker() {
    _scheduleTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      try {
        final now = Timestamp.now();
        final snap = await FirebaseFirestore.instance.collection('scheduled_messages')
            .where('senderId', isEqualTo: user.uid)
            .where('status', isEqualTo: 'pending')
            .get();

        for (var doc in snap.docs) {
          final data = doc.data();
          final scheduledTime = data['scheduledTime'] as Timestamp?;
          
          if (scheduledTime != null && scheduledTime.toDate().isBefore(now.toDate())) {
            final roomId = data['roomId'];
            final text = data['text'];
            
            // Kirim pesan ke ruangan
            await FirebaseFirestore.instance.collection('rooms').doc(roomId).collection('messages').add({
              'type': 'text',
              'text': text,
              'senderId': user.uid,
              'senderName': user.displayName ?? 'User',
              'timestamp': FieldValue.serverTimestamp(),
              'status': 'sent',
            });
            
            // Update pesan terakhir
            await FirebaseFirestore.instance.collection('rooms').doc(roomId).update({
              'lastMessage': text,
              'lastMessageTime': FieldValue.serverTimestamp(),
            });

            // Hapus dari antrean jadwal karena sudah terkirim
            await doc.reference.delete();
          }
        }
      } catch (e) {
        debugPrint("Error executing scheduled messages: $e");
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    
    final isGhostMode = prefs.getBool('mod_hide_online') ?? false;
    final isAlwaysOnline = prefs.getBool('mod_always_online') ?? false;
    final isFreezeLastSeen = prefs.getBool('mod_freeze_lastseen') ?? false;

    if (isAlwaysOnline) { FirebaseFirestore.instance.collection('users').doc(user.uid).update({'isOnline': true, 'lastSeen': FieldValue.serverTimestamp()}).catchError((e) {}); return; }
    if (isGhostMode) { FirebaseFirestore.instance.collection('users').doc(user.uid).update({'isOnline': false}).catchError((e) {}); if (!isFreezeLastSeen) FirebaseFirestore.instance.collection('users').doc(user.uid).update({'lastSeen': FieldValue.serverTimestamp()}).catchError((e) {}); return; }

    if (state == AppLifecycleState.resumed) {
      FirebaseFirestore.instance.collection('users').doc(user.uid).update({'isOnline': true, 'lastSeen': FieldValue.serverTimestamp()}).catchError((e) {});
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      FirebaseFirestore.instance.collection('users').doc(user.uid).update({'isOnline': false}).catchError((e) {});
      if (!isFreezeLastSeen) FirebaseFirestore.instance.collection('users').doc(user.uid).update({'lastSeen': FieldValue.serverTimestamp()}).catchError((e) {});
    }
  }

  void _checkAppLock() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pin = prefs.getString('app_pin') ?? "";
      final isBio = prefs.getBool('biometric_lock') ?? false;
      if (mounted) setState(() { _isLocked = pin.isNotEmpty || isBio; _isCheckingLock = false; });
    } catch (e) { if (mounted) setState(() { _isLocked = false; _isCheckingLock = false; }); }
  }

  Future<bool> _authenticateBiometric() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      if (!canAuthenticate) return false;
      return await _auth.authenticate(localizedReason: 'Pindai sidik jari untuk membuka JBchatluz', options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true));
    } catch (e) { return false; }
  }

  TextTheme _getTextTheme(String fontName) {
    if (fontName == "Poppins") return GoogleFonts.poppinsTextTheme();
    if (fontName == "Roboto") return GoogleFonts.robotoTextTheme();
    if (fontName == "Lora") return GoogleFonts.loraTextTheme();
    if (fontName == "Oswald") return GoogleFonts.oswaldTextTheme();
    return ThemeData.light().textTheme;
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingLock) return const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator())));
    return ValueListenableBuilder<ThemeMode>(valueListenable: themeNotifier, builder: (context, currentMode, child) {
      return ValueListenableBuilder<String>(valueListenable: fontNotifier, builder: (context, currentFont, child) {
        return ValueListenableBuilder<double>(valueListenable: fontSizeNotifier, builder: (context, currentSize, child) {
          return MaterialApp(
            title: 'JBchatluz', debugShowCheckedModeBanner: false, themeMode: currentMode,
            theme: ThemeData(colorSchemeSeed: const Color(0xFF00A884), useMaterial3: true, brightness: Brightness.light, textTheme: _getTextTheme(currentFont)),
            darkTheme: ThemeData(colorSchemeSeed: const Color(0xFF00A884), useMaterial3: true, brightness: Brightness.dark, scaffoldBackgroundColor: const Color(0xFF0B141A), textTheme: _getTextTheme(currentFont)),
            builder: (context, child) {
              return MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(currentSize)), child: child!);
            },
            home: _isLocked ? LockScreen(onUnlocked: () => setState(() => _isLocked = false), authBiometric: _authenticateBiometric) : StreamBuilder<User?>(stream: FirebaseAuth.instance.authStateChanges(), builder: (context, snapshot) { if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator()); if (snapshot.hasData) return const ChatListScreen(); return const AuthScreen(); }),
          );
        });
      });
    });
  }
}
