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
    // Grid untuk menampung banyak video (Group Call)
    List<Widget> videoWidgets = [];
    
    if (_localUserJoined) {
      videoWidgets.add(AgoraVideoView(controller: VideoViewController(rtcEngine: _engine, canvas: const VideoCanvas(uid: 0))));
    }
    
    for (var uid in _remoteUsers.keys) {
      videoWidgets.add(AgoraVideoView(controller: VideoViewController.remote(rtcEngine: _engine, canvas: VideoCanvas(uid: uid), connection: RtcConnection(channelId: widget.channelName))));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Panggilan Grup: ${widget.channelName}'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: videoWidgets.isEmpty 
              ? const Center(child: Text('Menunggu peserta...', style: TextStyle(color: Colors.white)))
              : GridView.count(
                  crossAxisCount: videoWidgets.length > 1 ? 2 : 1,
                  children: videoWidgets,
                ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: _isMuted ? Colors.red : Colors.white24,
                  child: IconButton(
                    icon: Icon(_isMuted ? Icons.mic_off : Icons.mic, color: Colors.white),
                    onPressed: () {
                      setState(() => _isMuted = !_isMuted);
                      _engine.muteLocalAudioStream(_isMuted);
                    },
                  ),
                ),
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.red,
                  child: IconButton(
                    icon: const Icon(Icons.call_end, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
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
