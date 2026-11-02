import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _pinController = TextEditingController();
  String _savedPin = "";
  String _error = "";

  @override
  void initState() {
    super.initState();
    _loadPin();
  }

  void _loadPin() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedPin = prefs.getString('app_pin') ?? "";
    });
  }

  void _checkPin() {
    if (_pinController.text == _savedPin) {
      widget.onUnlocked();
    } else {
      setState(() => _error = "PIN Salah. Coba lagi.");
      _pinController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF075E54),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 80, color: Colors.white),
            const SizedBox(height: 20),
            const Text("JBchatluz Terkunci", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Masukkan PIN Anda", style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 30),
            SizedBox(
              width: 200,
              child: TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 10, color: Colors.white),
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: Colors.white24,
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _checkPin(),
              ),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(_error, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _checkPin,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
              child: const Text("Buka Kunci", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }
}
