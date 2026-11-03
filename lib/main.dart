import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/auth_screen.dart';
import 'screens/chat_list_screen.dart';
import 'screens/lock_screen.dart';
import 'notification_service.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
final ValueNotifier<String> fontNotifier = ValueNotifier("Default");
final ValueNotifier<Color> bubbleColorNotifier = ValueNotifier(const Color(0xFFD9FDD3));

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try { await Firebase.initializeApp(); } catch (e) { runApp(MaterialApp(home: Scaffold(body: Center(child: Text("Firebase Error: $e"))))); return; }
  try { await NotificationService.initialize(); } catch (e) { debugPrint("Notif error: $e"); }

  final prefs = await SharedPreferences.getInstance();
  themeNotifier.value = (prefs.getBool('darkMode') ?? false) ? ThemeMode.dark : ThemeMode.light;
  fontNotifier.value = prefs.getString('app_font') ?? "Default";
  bubbleColorNotifier.value = Color(prefs.getInt('bubble_color') ?? 0xFFD9FDD3);

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAppLock();
  }

  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // PERBAIKAN: Cek apakah Mode Hantu aktif
    final prefs = await SharedPreferences.getInstance();
    final isGhostMode = prefs.getBool('mod_hide_online') ?? false;
    if (isGhostMode) return;

    if (state == AppLifecycleState.resumed) {
      FirebaseFirestore.instance.collection('users').doc(user.uid).update({'isOnline': true, 'lastSeen': FieldValue.serverTimestamp()}).catchError((e) {});
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      FirebaseFirestore.instance.collection('users').doc(user.uid).update({'isOnline': false, 'lastSeen': FieldValue.serverTimestamp()}).catchError((e) {});
    }
  }

  void _checkAppLock() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pin = prefs.getString('app_pin') ?? "";
      if (mounted) setState(() { _isLocked = pin.isNotEmpty; _isCheckingLock = false; });
    } catch (e) { if (mounted) setState(() { _isLocked = false; _isCheckingLock = false; }); }
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
        return MaterialApp(
          title: 'JBchatluz', debugShowCheckedModeBanner: false, themeMode: currentMode,
          theme: ThemeData(colorSchemeSeed: const Color(0xFF00A884), useMaterial3: true, brightness: Brightness.light, textTheme: _getTextTheme(currentFont)),
          darkTheme: ThemeData(colorSchemeSeed: const Color(0xFF00A884), useMaterial3: true, brightness: Brightness.dark, scaffoldBackgroundColor: const Color(0xFF0B141A), textTheme: _getTextTheme(currentFont)),
          home: _isLocked ? LockScreen(onUnlocked: () => setState(() => _isLocked = false)) : StreamBuilder<User?>(stream: FirebaseAuth.instance.authStateChanges(), builder: (context, snapshot) { if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator()); if (snapshot.hasData) return const ChatListScreen(); return const AuthScreen(); }),
        );
      });
    });
  }
}
