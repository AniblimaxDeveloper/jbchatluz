import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

class FakeCallScreen extends StatefulWidget {
  final String callerName;
  const FakeCallScreen({super.key, required this.callerName});

  @override
  State<FakeCallScreen> createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<FakeCallScreen> {
  final AudioPlayer _player = AudioPlayer();
  bool _isCallActive = false;
  int _seconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Mainkan nada dering (menggunakan URL dummy, pastikan ada koneksi internet)
    _player.setReleaseMode(ReleaseMode.loop);
    _player.play(UrlSource('https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3'));
  }

  @override
  void dispose() {
    _player.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _acceptCall() {
    _player.stop();
    setState(() => _isCallActive = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _seconds++);
    });
  }

  void _endCall() {
    _player.stop();
    _timer?.cancel();
    Navigator.pop(context);
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B141A),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(height: 50),
            Column(
              children: [
                const CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.person, size: 60, color: Colors.white),
                ),
                const SizedBox(height: 20),
                Text(widget.callerName, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 10),
                Text(_isCallActive ? _formatDuration(_seconds) : 'Panggilan masuk...', style: const TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 50),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Tombol Tolak
                  Column(
                    children: [
                      CircleAvatar(
                        radius: 35,
                        backgroundColor: Colors.red,
                        child: IconButton(
                          icon: const Icon(Icons.call_end, color: Colors.white, size: 35),
                          onPressed: _endCall,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text('Tolak', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                  // Tombol Terima
                  if (!_isCallActive)
                    Column(
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: const Color(0xFF25D366),
                          child: IconButton(
                            icon: const Icon(Icons.call, color: Colors.white, size: 35),
                            onPressed: _acceptCall,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text('Terima', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
