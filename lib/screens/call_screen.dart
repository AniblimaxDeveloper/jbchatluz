import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

// GANTI DENGAN APP ID AGORA ANDA
const String agoraAppId = "1e5b3eeaff7943dd9a69f4abd749301e";

class CallScreen extends StatefulWidget {
  final String channelName;
  final bool isVideoCall;

  const CallScreen({super.key, required this.channelName, required this.isVideoCall});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late RtcEngine _engine;
  int? _remoteUid;
  bool _localUserJoined = false;
  bool _isMuted = false;
  bool _isVideoOff = false;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    await [Permission.microphone, Permission.camera].request();

    _engine = createAgoraRtcEngine();
    await _engine.initialize(const RtcEngineContext(
      appId: agoraAppId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          setState(() {
            _localUserJoined = true;
          });
        },
        onUserJoined: (RtcConnection connection, int rUid, int elapsed) {
          setState(() {
            _remoteUid = rUid;
          });
        },
        onUserOffline: (RtcConnection connection, int rUid, UserOfflineReasonType reason) {
          setState(() {
            _remoteUid = null;
          });
        },
      ),
    );

    await _engine.enableVideo();
    await _engine.startPreview();

    await _engine.joinChannel(
      token: "", // Kosongkan jika di Agora Console mode "Testing" (App ID saja)
      channelId: widget.channelName,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
      ),
      uid: 0,
    );
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
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video Lawan Bicara (Layar Penuh)
          Center(
            child: _remoteUid != null
                ? AgoraVideoView(
                    controller: VideoViewController.remote(
                      rtcEngine: _engine,
                      canvas: VideoCanvas(uid: _remoteUid!),
                      connection: RtcConnection(channelId: widget.channelName),
                    ),
                  )
                : const Text(
                    'Menunggu lawan bicara bergabung...',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
          ),
          
          // Video Kita Sendiri (Kotak Kecil di Pojok)
          if (_localUserJoined && widget.isVideoCall)
            Positioned(
              top: 50,
              right: 20,
              child: SizedBox(
                width: 120,
                height: 160,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AgoraVideoView(
                    controller: VideoViewController(
                      rtcEngine: _engine,
                      canvas: const VideoCanvas(uid: 0),
                    ),
                  ),
                ),
              ),
            ),

          // Tombol Kontrol di Bawah
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Tombol Mute
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white24,
                  child: IconButton(
                    icon: Icon(_isMuted ? Icons.mic_off : Icons.mic, color: Colors.white),
                    onPressed: () {
                      setState(() => _isMuted = !_isMuted);
                      _engine.muteLocalAudioStream(_isMuted);
                    },
                  ),
                ),
                // Tombol Matikan Kamera
                if (widget.isVideoCall)
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white24,
                    child: IconButton(
                      icon: Icon(_isVideoOff ? Icons.videocam_off : Icons.videocam, color: Colors.white),
                      onPressed: () {
                        setState(() => _isVideoOff = !_isVideoOff);
                        _engine.muteLocalVideoStream(_isVideoOff);
                      },
                    ),
                  ),
                // Tombol Akhiri Panggilan
                CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.red,
                  child: IconButton(
                    icon: const Icon(Icons.call_end, color: Colors.white, size: 30),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ),
                // Tombol Putar Kamera
                if (widget.isVideoCall)
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white24,
                    child: IconButton(
                      icon: const Icon(Icons.flip_camera_android, color: Colors.white),
                      onPressed: () {
                        _engine.switchCamera();
                      },
                    ),
                  ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
