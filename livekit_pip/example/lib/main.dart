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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ConnectPage(),
    );
  }
}

// ──── Connect Page ───────────────────────────────────────────────────────

class ConnectPage extends StatefulWidget {
  const ConnectPage({super.key});

  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  final _urlController = TextEditingController(
    text: 'wss://your-project.livekit.cloud',
  );
  final _tokenController = TextEditingController();
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
      if (!mounted) {
        await room.disconnect();
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CallPage(room: room),
        ),
      );
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connect failed: $e')),
        );
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
              'lk token create --join --room my-room --identity user1',
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

// ──── Call Page ──────────────────────────────────────────────────────────

class CallPage extends StatefulWidget {
  const CallPage({required this.room, super.key});

  final Room room;

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  late LiveKitPip _pip;

  bool? _supported;
  PipState _pipState = PipState.inactive;
  bool _initialized = false;
  StreamSubscription<PipState>? _stateSub;

  @override
  void initState() {
    super.initState();
    _pip = LiveKitPip();
    unawaited(_checkSupport());
  }

  Future<void> _checkSupport() async {
    final supported = await _pip.isSupported();
    if (mounted) setState(() => _supported = supported);
  }

  Future<void> _initializePip() async {
    try {
      await _pip.initialize(
        room: widget.room,
        config: LiveKitPipConfiguration(
          android: AndroidPipConfiguration(
            pipWidgetBuilder: (ctx, room) => _AndroidPipContent(room: room),
          ),
          ios: const IosPipConfiguration(),
        ),
      );
      _stateSub = _pip.stateStream.listen((state) {
        if (mounted) setState(() => _pipState = state);
      });
      if (mounted) setState(() => _initialized = true);
    } on Exception catch (e) {
      _showError('$e');
    }
  }

  Future<void> _enterPip() async {
    try {
      await _pip.enterPiP();
    } on Exception catch (e) {
      _showError('$e');
    }
  }

  Future<void> _exitPip() async {
    try {
      await _pip.exitPiP();
    } on Exception catch (e) {
      _showError('$e');
    }
  }

  Future<void> _disposePip() async {
    await _stateSub?.cancel();
    _stateSub = null;
    await _pip.dispose();
    if (mounted) {
      setState(() {
        _initialized = false;
        _pipState = PipState.inactive;
        _pip = LiveKitPip(); // fresh instance — disposed one cannot be reused
      });
    }
  }

  Future<void> _hangUp() async {
    await _disposePip();
    await widget.room.disconnect();
    if (mounted) Navigator.of(context).pop();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    unawaited(_disposePip());
    unawaited(widget.room.disconnect());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('livekit_pip — Call'),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_end, color: Colors.red),
            tooltip: 'Hang up',
            onPressed: _hangUp,
          ),
        ],
      ),
      body: Stack(
        children: [
          // iOS: hosts AVSampleBufferDisplayLayer. Android: zero-size no-op.
          LiveKitPipView(room: widget.room),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StatusCard(
                    supported: _supported,
                    pipState: _pipState,
                    room: widget.room,
                  ),
                  const SizedBox(height: 24),
                  if (!_initialized) ...[
                    FilledButton.icon(
                      onPressed: _supported == true ? _initializePip : null,
                      icon: const Icon(Icons.picture_in_picture),
                      label: const Text('Initialize PiP'),
                    ),
                  ] else ...[
                    FilledButton.icon(
                      onPressed:
                          _pipState == PipState.inactive ? _enterPip : null,
                      icon: const Icon(Icons.picture_in_picture_alt),
                      label: const Text('Enter PiP'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _pipState == PipState.active ? _exitPip : null,
                      icon: const Icon(Icons.fullscreen),
                      label: const Text('Exit PiP'),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _disposePip,
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('Dispose PiP'),
                    ),
                  ],
                  const Spacer(),
                  _ParticipantList(room: widget.room),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──── Status card ────────────────────────────────────────────────────────

class _StatusCard extends StatefulWidget {
  const _StatusCard({
    required this.supported,
    required this.pipState,
    required this.room,
  });

  final bool? supported;
  final PipState pipState;
  final Room room;

  @override
  State<_StatusCard> createState() => _StatusCardState();
}

class _StatusCardState extends State<_StatusCard> {
  late final EventsListener<RoomEvent> _listener;

  @override
  void initState() {
    super.initState();
    _listener = widget.room.createListener()
      ..on<RoomConnectedEvent>((_) => setState(() {}))
      ..on<RoomDisconnectedEvent>((_) => setState(() {}))
      ..on<ParticipantConnectedEvent>((_) => setState(() {}))
      ..on<ParticipantDisconnectedEvent>((_) => setState(() {}));
  }

  @override
  void dispose() {
    unawaited(_listener.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final participantCount =
        widget.room.remoteParticipants.length + 1; // +1 for local

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Row('PiP supported', widget.supported == null
                ? 'checking…'
                : (widget.supported! ? 'yes' : 'no')),
            _Row('PiP state', widget.pipState.name),
            _Row('Participants', '$participantCount'),
            _Row(
              'Room',
              widget.room.name ?? 'connected',
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

// ──── Participant list ───────────────────────────────────────────────────

class _ParticipantList extends StatefulWidget {
  const _ParticipantList({required this.room});

  final Room room;

  @override
  State<_ParticipantList> createState() => _ParticipantListState();
}

class _ParticipantListState extends State<_ParticipantList> {
  late final EventsListener<RoomEvent> _listener;

  @override
  void initState() {
    super.initState();
    _listener = widget.room.createListener()
      ..on<ParticipantConnectedEvent>((_) => setState(() {}))
      ..on<ParticipantDisconnectedEvent>((_) => setState(() {}))
      ..on<TrackSubscribedEvent>((_) => setState(() {}))
      ..on<TrackUnsubscribedEvent>((_) => setState(() {}));
  }

  @override
  void dispose() {
    unawaited(_listener.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remote = widget.room.remoteParticipants.values.toList();
    if (remote.isEmpty) {
      return const Text(
        'Waiting for other participants…',
        textAlign: TextAlign.center,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Participants (${remote.length + 1})',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 8),
        for (final p in remote)
          ListTile(
            dense: true,
            leading: const Icon(Icons.person_outline),
            title: Text(p.name.isNotEmpty ? p.name : p.identity),
            subtitle: Text(
              p.isCameraEnabled() ? 'camera on' : 'camera off',
            ),
            contentPadding: EdgeInsets.zero,
          ),
      ],
    );
  }
}

// ──── Android PiP content ───────────────────────────────────────────────

class _AndroidPipContent extends StatelessWidget {
  const _AndroidPipContent({required this.room});

  final Room room;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam, color: Colors.white, size: 32),
            const SizedBox(height: 8),
            Text(
              room.name ?? 'Call',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
