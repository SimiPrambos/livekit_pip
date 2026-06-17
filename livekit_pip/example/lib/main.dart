import 'dart:async';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_pip/livekit_pip.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: HomePage());
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _pip = LiveKitPip();
  final _room = Room();

  bool? _supported;
  PipState _pipState = PipState.inactive;
  bool _initialized = false;
  StreamSubscription<PipState>? _stateSub;

  @override
  void initState() {
    super.initState();
    unawaited(_checkSupport());
  }

  Future<void> _checkSupport() async {
    final supported = await _pip.isSupported();
    if (mounted) setState(() => _supported = supported);
  }

  Future<void> _initialize() async {
    try {
      await _pip.initialize(
        room: _room,
        config: LiveKitPipConfiguration(
          android: AndroidPipConfiguration(
            pipWidgetBuilder: (ctx, room) => const Center(
              child: Text(
                'PiP',
                style: TextStyle(color: Colors.white, fontSize: 32),
              ),
            ),
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

  Future<void> _enter() async {
    try {
      await _pip.enterPiP();
    } on Exception catch (e) {
      _showError('$e');
    }
  }

  Future<void> _exit() async {
    try {
      await _pip.exitPiP();
    } on Exception catch (e) {
      _showError('$e');
    }
  }

  Future<void> _disposeController() async {
    await _stateSub?.cancel();
    await _pip.dispose();
    if (mounted) setState(() => _initialized = false);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    unawaited(_disposeController());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('livekit_pip Example')),
      body: Stack(
        children: [
          // LiveKitPipView is zero-size on Android;
          // hosts native AVSampleBufferDisplayLayer on iOS.
          LiveKitPipView(room: _room),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('PiP supported: ${_supported ?? "checking…"}'),
                const SizedBox(height: 8),
                Text('PiP state: ${_pipState.name}'),
                const SizedBox(height: 24),
                if (!_initialized) ...[
                  ElevatedButton(
                    onPressed: _supported == true ? _initialize : null,
                    child: const Text('Initialize PiP'),
                  ),
                ] else ...[
                  ElevatedButton(
                    onPressed: _enter,
                    child: const Text('Enter PiP'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _exit,
                    child: const Text('Exit PiP'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _disposeController,
                    child: const Text('Dispose'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
