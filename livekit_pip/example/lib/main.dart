import 'dart:async';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_pip/livekit_pip.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'livekit_pip Example',
      theme: ThemeData.dark(useMaterial3: true),
      home: const ConnectPage(),
    );
  }
}

// ──── Connect Page ──────────────────────────────────────────────────────

class ConnectPage extends StatefulWidget {
  const ConnectPage({super.key});

  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  final _urlController = TextEditingController(
    text: 'wss://piptest-fiws50ef.livekit.cloud',
  );
  final _tokenController = TextEditingController(
    text:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJBUEkyUWFVVEM3d3ozRkIiLCJzdWIiOiJ1c2VyMiIsIm5iZiI6MTc4MTc3NTMxNSwiZXhwIjoxNzgxNzc4OTE1LCJuYW1lIjoiVXNlciAyIiwidmlkZW8iOnsicm9vbSI6InRlc3Qtcm9vbSIsInJvb21Kb2luIjp0cnVlLCJjYW5QdWJsaXNoIjp0cnVlLCJjYW5TdWJzY3JpYmUiOnRydWUsImNhblB1Ymxpc2hEYXRhIjp0cnVlfX0.CJMIThK4f1HaJ5JkaI6B6sVoQx46ehr7kLDTt-BBB2E',
  );
  bool _connecting = false;

  @override
  void dispose() {
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final url = _urlController.text.trim();
    final token = _tokenController.text.trim();
    if (url.isEmpty || token.isEmpty) return;
    setState(() => _connecting = true);
    try {
      final room = Room();
      await room.connect(url, token);
      await room.localParticipant?.setCameraEnabled(true);
      await room.localParticipant?.setMicrophoneEnabled(true);
      if (!mounted) {
        await room.disconnect();
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => CallPage(room: room)),
      );
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Connect failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('livekit_pip — Connect')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                hintText: 'wss://your-project.livekit.cloud',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _tokenController,
              decoration: const InputDecoration(
                labelText: 'Token',
                hintText: 'Paste JWT token here',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              autocorrect: false,
            ),
            const SizedBox(height: 8),
            Text(
              'Generate: node scripts/gen_tokens.mjs my-room',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _connecting ? null : _connect,
              child: _connecting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Connect'),
            ),
          ],
        ),
      ),
    );
  }
}

// ──── Call Page ─────────────────────────────────────────────────────────

class CallPage extends StatefulWidget {
  const CallPage({required this.room, super.key});

  final Room room;

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  late final EventsListener<RoomEvent> _listener;
  final _pip = LiveKitPip();

  @override
  void initState() {
    super.initState();
    _listener = widget.room.createListener()
      ..on<ParticipantConnectedEvent>((_) => setState(() {}))
      ..on<ParticipantDisconnectedEvent>((_) => setState(() {}))
      ..on<TrackSubscribedEvent>((_) => setState(() {}))
      ..on<TrackUnsubscribedEvent>((_) => setState(() {}))
      ..on<LocalTrackPublishedEvent>((_) => setState(() {}))
      ..on<LocalTrackUnpublishedEvent>((_) => setState(() {}));
    unawaited(_initPip());
  }

  Future<void> _initPip() async {
    try {
      await _pip.initialize(
        room: widget.room,
        config: LiveKitPipConfiguration(
          android: AndroidPipConfiguration(
            pipWidgetBuilder: (ctx, room) => const _AndroidPipContent(),
          ),
          ios: const IosPipConfiguration(),
        ),
      );
    } on Exception catch (e) {
      debugPrint('[livekit_pip] initialize failed: $e');
    }
  }

  Future<void> _hangUp() async {
    await _pip.dispose();
    await widget.room.disconnect();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    unawaited(_pip.dispose());
    unawaited(_listener.dispose());
    unawaited(widget.room.disconnect());
    super.dispose();
  }

  VideoTrack? _localVideo() {
    final local = widget.room.localParticipant;
    if (local == null) return null;
    for (final pub in local.videoTrackPublications) {
      if (pub.source == TrackSource.camera) return pub.track;
    }
    return null;
  }

  List<_ParticipantVideo> _remoteVideos() {
    final result = <_ParticipantVideo>[];
    for (final p in widget.room.remoteParticipants.values) {
      for (final pub in p.videoTrackPublications) {
        if (pub.source == TrackSource.camera) {
          final t = pub.track;
          if (t != null) {
            result.add(
              _ParticipantVideo(
                name: p.name.isNotEmpty ? p.name : p.identity,
                track: t,
              ),
            );
          }
        }
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final remoteVideos = _remoteVideos();
    final localVideo = _localVideo();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // iOS: transparent source view for AVPictureInPictureController.
          // Must fill the screen so isPictureInPicturePossible stays true.
          // Placed first (lowest z-order) so Flutter content renders on top.
          Positioned.fill(child: LiveKitPipView(room: widget.room)),

          if (remoteVideos.isEmpty)
            const Center(
              child: Text(
                'Waiting for participants…',
                style: TextStyle(color: Colors.white54),
              ),
            )
          else
            _VideoGrid(videos: remoteVideos),

          if (localVideo != null)
            Positioned(
              right: 16,
              bottom: 100,
              width: 96,
              height: 128,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: VideoTrackRenderer(
                  localVideo,
                  mirrorMode: VideoViewMirrorMode.mirror,
                  fit: VideoViewFit.cover,
                ),
              ),
            ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: _BottomBar(room: widget.room, onHangUp: _hangUp),
            ),
          ),
        ],
      ),
    );
  }
}

// ──── Video grid ────────────────────────────────────────────────────────

class _ParticipantVideo {
  const _ParticipantVideo({required this.name, required this.track});

  final String name;
  final VideoTrack track;
}

class _VideoGrid extends StatelessWidget {
  const _VideoGrid({required this.videos});

  final List<_ParticipantVideo> videos;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: videos.length == 1 ? 1 : 2,
        childAspectRatio: 3 / 4,
      ),
      itemCount: videos.length,
      itemBuilder: (_, i) {
        final v = videos[i];
        return RepaintBoundary(
          key: ValueKey(v.track),
          child: Stack(
            children: [
              VideoTrackRenderer(v.track, fit: VideoViewFit.cover),
              Positioned(
                bottom: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    v.name,
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ──── Bottom control bar ────────────────────────────────────────────────

class _BottomBar extends StatefulWidget {
  const _BottomBar({required this.room, required this.onHangUp});

  final Room room;
  final VoidCallback onHangUp;

  @override
  State<_BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<_BottomBar> {
  late final EventsListener<RoomEvent> _listener;

  @override
  void initState() {
    super.initState();
    _listener = widget.room.createListener()
      ..on<TrackMutedEvent>((_) => setState(() {}))
      ..on<TrackUnmutedEvent>((_) => setState(() {}))
      ..on<LocalTrackPublishedEvent>((_) => setState(() {}))
      ..on<LocalTrackUnpublishedEvent>((_) => setState(() {}));
  }

  @override
  void dispose() {
    unawaited(_listener.dispose());
    super.dispose();
  }

  bool get _micEnabled =>
      widget.room.localParticipant?.isMicrophoneEnabled() ?? false;
  bool get _camEnabled =>
      widget.room.localParticipant?.isCameraEnabled() ?? false;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(_micEnabled ? Icons.mic : Icons.mic_off),
            color: _micEnabled ? Colors.white : Colors.red,
            onPressed: () async {
              await widget.room.localParticipant?.setMicrophoneEnabled(
                !_micEnabled,
              );
            },
          ),
          IconButton(
            icon: Icon(_camEnabled ? Icons.videocam : Icons.videocam_off),
            color: _camEnabled ? Colors.white : Colors.red,
            onPressed: () async {
              await widget.room.localParticipant?.setCameraEnabled(
                !_camEnabled,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.call_end),
            color: Colors.red,
            onPressed: widget.onHangUp,
          ),
        ],
      ),
    );
  }
}

// ──── Android PiP fallback content ─────────────────────────────────────

class _AndroidPipContent extends StatelessWidget {
  const _AndroidPipContent();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: Icon(Icons.videocam, color: Colors.white, size: 32),
      ),
    );
  }
}
