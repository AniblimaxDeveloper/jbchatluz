import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

const String agoraAppId = "MASUKKAN_APP_ID_AGORA_ANDA";

class CallScreen extends StatefulWidget {
  final String channelName;
  final bool isVideoCall;
  const CallScreen({super.key, required this.channelName, required this.isVideoCall});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late RtcEngine _engine;
  final Map<int, bool> _remoteUsers = {}; 
  bool _localUserJoined = false;
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isSpeakerOn = true;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    await [Permission.microphone, Permission.camera].request();

    _engine = createAgoraRtcEngine();
    await _engine.initialize(const RtcEngineContext(appId: agoraAppId, channelProfile: ChannelProfileType.channelProfileCommunication));

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) => setState(() => _localUserJoined = true),
        onUserJoined: (RtcConnection connection, int rUid, int elapsed) => setState(() => _remoteUsers[rUid] = true),
        onUserOffline: (RtcConnection connection, int rUid, UserOfflineReasonType reason) => setState(() => _remoteUsers.remove(rUid)),
      ),
    );

    await _engine.enableVideo();
    await _engine.startPreview();
    await _engine.joinChannel(token: "", channelId: widget.channelName, options: const ChannelMediaOptions(), uid: 0);
  }

  @override
  void dispose() {
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B141A),
      body: SafeArea(
        child: Stack(
          children: [
            // Video Lawan Bicara (Layar Penuh)
            Positioned.fill(
              child: _remoteUsers.isNotEmpty
                  ? AgoraVideoView(controller: VideoViewController.remote(rtcEngine: _engine, canvas: VideoCanvas(uid: _remoteUsers.keys.first), connection: RtcConnection(channelId: widget.channelName)))
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircleAvatar(radius: 50, backgroundColor: Colors.white24, child: Icon(Icons.person, size: 50, color: Colors.white)),
                          const SizedBox(height: 20),
                          Text('Memanggil...\n${widget.channelName}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
            ),

            // Video Kita Sendiri (Pojok Kanan Atas)
            if (_localUserJoined && widget.isVideoCall)
              Positioned(
                top: 20, right: 20,
                child: Container(
                  width: 120, height: 160,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AgoraVideoView(controller: VideoViewController(rtcEngine: _engine, canvas: const VideoCanvas(uid: 0))),
                  ),
                ),
              ),

            // Info Nama (Kiri Atas)
            Positioned(
              top: 20, left: 20,
              child: Row(children: [
                const Icon(Icons.lock, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(widget.isVideoCall ? 'Panggilan Video Terenkripsi' : 'Panggilan Suara Terenkripsi', style: const TextStyle(color: Colors.white, fontSize: 12)),
              ]),
            ),

            // Tombol Kontrol di Bawah
            Positioned(
              bottom: 40, left: 0, right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute
                  _buildCallButton(Icons.mic, _isMuted ? Colors.white : Colors.white24, _isMuted ? Colors.black : Colors.white, () {
                    setState(() => _isMuted = !_isMuted);
                    _engine.muteLocalAudioStream(_isMuted);
                  }),
                  
                  // Speaker
                  _buildCallButton(_isSpeakerOn ? Icons.volume_up : Icons.volume_off, Colors.white24, Colors.white, () {
                    setState(() => _isSpeakerOn = !_isSpeakerOn);
                    _engine.setEnableSpeakerphone(_isSpeakerOn);
                  }),

                  // Matikan Video
                  if (widget.isVideoCall)
                    _buildCallButton(_isVideoOff ? Icons.videocam_off : Icons.videocam, Colors.white24, Colors.white, () {
                      setState(() => _isVideoOff = !_isVideoOff);
                      _engine.muteLocalVideoStream(_isVideoOff);
                    }),

                  // Putar Kamera
                  if (widget.isVideoCall)
                    _buildCallButton(Icons.flip_camera_android, Colors.white24, Colors.white, () {
                      _engine.switchCamera();
                    }),

                  // Akhiri Panggilan
                  _buildCallButton(Icons.call_end, Colors.red, Colors.white, () {
                    Navigator.pop(context);
                  }),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCallButton(IconData icon, Color bgColor, Color iconColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        radius: 30,
        backgroundColor: bgColor,
        child: Icon(icon, color: iconColor, size: 28),
      ),
    );
  }
}
