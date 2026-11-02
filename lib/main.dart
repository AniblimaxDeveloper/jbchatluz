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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService.initialize();

  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('darkMode') ?? false;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  
  final savedFont = prefs.getString('app_font') ?? "Default";
  fontNotifier.value = savedFont;

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
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (state == AppLifecycleState.resumed) {
      // Aplikasi dibuka: Set Online
      FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Aplikasi ditutup: Set Offline
      FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    }
  }

  void _checkAppLock() async {
    final prefs = await SharedPreferences.getInstance();
    final pin = prefs.getString('app_pin') ?? "";
    setState(() {
      _isLocked = pin.isNotEmpty;
      _isCheckingLock = false;
    });
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

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return ValueListenableBuilder<String>(
          valueListenable: fontNotifier,
          builder: (context, currentFont, child) {
            return MaterialApp(
              title: 'JBchatluz',
              debugShowCheckedModeBanner: false,
              themeMode: currentMode,
              theme: ThemeData(
                colorSchemeSeed: const Color(0xFF00A884), 
                useMaterial3: true, 
                brightness: Brightness.light,
                textTheme: _getTextTheme(currentFont),
              ),
              darkTheme: ThemeData(
                colorSchemeSeed: const Color(0xFF00A884), 
                useMaterial3: true, 
                brightness: Brightness.dark, 
                scaffoldBackgroundColor: const Color(0xFF0B141A),
                textTheme: _getTextTheme(currentFont),
              ),
              home: _isLocked 
                  ? LockScreen(onUnlocked: () => setState(() => _isLocked = false))
                  : StreamBuilder<User?>(
                      stream: FirebaseAuth.instance.authStateChanges(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasData) return const ChatListScreen();
                        return const AuthScreen();
                      },
                    ),
            );
          }
        );
      },
    );
  }
}
