import 'package:flutter/material.dart';

import 'capture/capture_service.dart';
import 'lab/lab_page.dart';
import 'lab/soak.dart';
import 'media/cloudflare_media.dart';
import 'rooms/settings_store.dart';
import 'rooms/worker_api.dart';
import 'ui/broadcast_page.dart';
import 'ui/capture_control.dart';
import 'ui/setup_page.dart';
import 'ui/watch_page.dart';

void main() {
  final soak = SoakConfig.fromEnvironment();
  if (soak != null) {
    runApp(SoakApp(config: soak));
    return;
  }
  runApp(const DenDenApp());
}

class DenDenApp extends StatefulWidget {
  const DenDenApp({super.key});

  @override
  State<DenDenApp> createState() => _DenDenAppState();
}

class _DenDenAppState extends State<DenDenApp> {
  SettingsStore? _store;
  AppSettings? _settings;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    SettingsStore.standard().then((store) async {
      final s = await store.load();
      if (mounted) {
        setState(() {
          _store = store;
          _settings = s;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    final s = _settings;
    return MaterialApp(
      title: 'DenDen',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: store == null || s == null
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : !s.isComplete || _editing
          ? SetupPage(
              initial: s,
              check: (url, key) => WorkerApi(url).iceServers(key),
              save: store.save,
              onDone: (saved) => setState(() {
                _settings = saved;
                _editing = false;
              }),
            )
          : HomePage(
              settings: s,
              onEditSettings: () => setState(() => _editing = true),
            ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.settings,
    required this.onEditSettings,
  });

  final AppSettings settings;
  final VoidCallback onEditSettings;

  CloudflareMedia _media() =>
      CloudflareMedia(WorkerApi(settings.workerUrl!), settings.key!);

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('DenDen'),
      actions: [
        TextButton(
          onPressed: () => _open(context, LabPage(capture: CaptureService())),
          child: const Text('Laboratório'),
        ),
        TextButton(
          onPressed: onEditSettings,
          child: const Text('Configurações'),
        ),
      ],
    ),
    body: Center(
      child: Wrap(
        spacing: 24,
        children: [
          FilledButton.icon(
            onPressed: () => _open(
              context,
              BroadcastPage(media: _media(), capture: RealCaptureControl()),
            ),
            icon: const Icon(Icons.cast),
            label: const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Transmitir', style: TextStyle(fontSize: 20)),
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: () => _open(context, WatchPage(media: _media())),
            icon: const Icon(Icons.tv),
            label: const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Assistir', style: TextStyle(fontSize: 20)),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Modo de estresse (variável DENDEN_SOAK): roda os ciclos e fecha o app.
class SoakApp extends StatefulWidget {
  const SoakApp({super.key, required this.config});

  final SoakConfig config;

  @override
  State<SoakApp> createState() => _SoakAppState();
}

class _SoakAppState extends State<SoakApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = View.of(context).display.size;
      runSoak(
        widget.config,
        width: size.width.round(),
        height: size.height.round(),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const MaterialApp(
    home: Scaffold(body: Center(child: Text('DenDen — modo de estresse'))),
  );
}
