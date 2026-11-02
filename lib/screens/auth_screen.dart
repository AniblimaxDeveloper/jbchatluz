import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _isLogin = true;

  final String _webClientId = "MASUKKAN_WEB_CLIENT_ID_ANDA_DISINI";

  String _generateJBId() {
    final random = Random();
    int id = random.nextInt(900000000) + 100000000; // 9 digit
    return id.toString();
  }

  Future<void> _saveUserToFirestore(User user) async {
    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final docSnap = await docRef.get();
    
    String jbId = docSnap.exists ? (docSnap.data()?['jbId'] ?? _generateJBId()) : _generateJBId();

    await docRef.set({
      'uid': user.uid,
      'displayName': user.displayName ?? user.email?.split('@')[0] ?? 'User',
      'email': user.email,
      'photoURL': user.photoURL,
      'jbId': jbId,
      'isOnline': true,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _submitEmail() async {
    setState(() => _loading = true);
    try {
      if (_isLogin) {
        final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text.trim(),
        );
        if (cred.user != null) await _saveUserToFirestore(cred.user!);
      } else {
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text.trim(),
        );
        if (cred.user != null) await _saveUserToFirestore(cred.user!);
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Error')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(serverClientId: _webClientId);
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final cred = await FirebaseAuth.instance.signInWithCredential(credential);
      if (cred.user != null) await _saveUserToFirestore(cred.user!);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Google Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.forum, size: 80, color: Color(0xFF00A884)),
                  const SizedBox(height: 16),
                  const Text('JBchatluz', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF00A884))),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _signInWithGoogle,
                      icon: const Icon(Icons.g_mobiledata, size: 32, color: Colors.red),
                      label: const Text('Masuk dengan Google', style: TextStyle(color: Colors.black87)),
                      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('ATAU GUNAKAN EMAIL', style: TextStyle(color: Colors.grey)),
                  ),
                  TextField(
                    controller: _email,
                    decoration: InputDecoration(labelText: 'Email', filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: InputDecoration(labelText: 'Password', filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00A884), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      onPressed: _loading ? null : _submitEmail,
                      child: _loading ? const CircularProgressIndicator(color: Colors.white) : Text(_isLogin ? 'Login' : 'Daftar'),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _isLogin = !_isLogin),
                    child: Text(_isLogin ? 'Belum punya akun? Daftar' : 'Sudah punya akun? Login', style: const TextStyle(color: Color(0xFF00A884))),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
