import 'package:flutter/material.dart';

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  final Future<bool> Function() authBiometric;
  const LockScreen({super.key, required this.onUnlocked, required this.authBiometric});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _pinController = TextEditingController();
  String _error = "";

  @override
  void initState() {
    super.initState();
    // Coba login biometrik otomatis saat layar dibuka
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final success = await widget.authBiometric();
      if (success) widget.onUnlocked();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B141A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 80, color: Colors.white),
            const SizedBox(height: 20),
            const Text("JBchatluz Terkunci", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            IconButton(
              icon: const Icon(Icons.fingerprint, size: 80, color: Color(0xFF25D366)),
              onPressed: () async {
                final success = await widget.authBiometric();
                if (success) widget.onUnlocked();
              },
            ),
            const SizedBox(height: 10),
            const Text("Atau masukkan PIN", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 10),
            SizedBox(
              width: 200,
              child: TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 10, color: Colors.white),
                decoration: const InputDecoration(filled: true, fillColor: Colors.white24, border: OutlineInputBorder()),
                onSubmitted: (_) async {
                  // Logika PIN divalidasi di sini
                  widget.onUnlocked(); // Sementara bypass PIN untuk demo sidik jari
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
