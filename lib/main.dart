import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/auth_screen.dart';
import 'screens/chat_list_screen.dart';
import 'screens/lock_screen.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('darkMode') ?? false;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

  runApp(const JBChatLuzApp());
}

class JBChatLuzApp extends StatefulWidget {
  const JBChatLuzApp({super.key});

  @override
  State<JBChatLuzApp> createState() => _JBChatLuzAppState();
}

class _JBChatLuzAppState extends State<JBChatLuzApp> {
  bool _isLocked = false;
  bool _isCheckingLock = true;

  @override
  void initState() {
    super.initState();
    _checkAppLock();
  }

  void _checkAppLock() async {
    final prefs = await SharedPreferences.getInstance();
    final pin = prefs.getString('app_pin') ?? "";
    setState(() {
      _isLocked = pin.isNotEmpty;
      _isCheckingLock = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingLock) return const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator())));

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'JBchatluz',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: ThemeData(colorSchemeSeed: const Color(0xFF00A884), useMaterial3: true, brightness: Brightness.light),
          darkTheme: ThemeData(colorSchemeSeed: const Color(0xFF00A884), useMaterial3: true, brightness: Brightness.dark, scaffoldBackgroundColor: const Color(0xFF0B141A)),
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
      },
    );
  }
}
