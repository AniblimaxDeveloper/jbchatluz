import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'screens/auth_screen.dart';
import 'screens/chat_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // GANTI DENGAN APP ID DAN APP SIGN DARI ZEGOCLOUD
  const int appID = 1177731752; 
  const String appSign "0e41c9efeda472a0b6e3ae858a12b8b99c6a2f4c1126aa111269a8408539ff67";

  ZegoUIKitPrebuiltCallInvitationService().init(
    appID: appID,
    appSign: appSign,
    userID: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
    userName: FirebaseAuth.instance.currentUser?.displayName ?? 'User',
    plugins: [ZegoUIKitSignalingPlugin()],
  );

  runApp(const JBChatLuzApp());
}

class JBChatLuzApp extends StatelessWidget {
  const JBChatLuzApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JBchatluz',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.blueAccent, useMaterial3: true),
      home: StreamBuilder<User?>(
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
}
