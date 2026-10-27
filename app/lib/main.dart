import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;

import 'atualizacao/atualizacao.dart';
import 'capture/capture_service.dart';
import 'lab/diagnostico.dart';
import 'lab/lab_page.dart';
import 'lab/soak.dart';
import 'media/cloudflare_media.dart';
import 'rooms/settings_store.dart';
import 'rooms/worker_api.dart';
import 'ui/admin_page.dart';
import 'ui/aviso_atualizacao.dart';
import 'ui/broadcast_page.dart';
import 'ui/cartao_acao.dart';
import 'ui/capture_control.dart';
import 'ui/setup_page.dart';
import 'ui/tema.dart';
import 'ui/usage_page.dart';
import 'ui/watch_page.dart';

void main() {
  final diag = DiagConfig.fromEnvironment();
  if (diag != null) {
    runApp(DiagApp(config: diag));
    return;
  }
  final soak = SoakConfig.fromEnvironment();
  if (soak != null) {
    runApp(SoakApp(config: soak));
    return;
  }
  limparRestosDeAtualizacao();
  // Teste da atualização sem clicar: o mesmo caminho do botão Atualizar.
  // Sai com 3 se não houver versão nova e 2 se der erro.
  if (Platform.environment['DENDEN_ATUALIZAR'] == '1') {
    WidgetsFlutterBinding.ensureInitialized();
    conferirAtualizacao(http.Client())
        .then((n) => n == null ? exit(3) : instalarAtualizacao(n))
        .catchError((Object _) => exit(2));
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
      // Segue o modo claro ou escuro do Windows.
      theme: temaDenDen(Brightness.light),
      darkTheme: temaDenDen(Brightness.dark),
      themeMode: ThemeMode.system,
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
              onCancel: s.isComplete
                  ? () => setState(() => _editing = false)
                  : null,
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

  CloudflareMedia _media() => CloudflareMedia(
    WorkerApi(settings.workerUrl!),
    settings.key!,
    registrarQualidade: true,
  );

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Row(
        children: [
          Image.asset('assets/icone/denden_64.png', width: 24, height: 24),
          const SizedBox(width: 10),
          Text(
            'DenDen',
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => _open(
            context,
            UsagePage(
              load: () => WorkerApi(settings.workerUrl!).usage(settings.key!),
            ),
          ),
          child: const Text('Consumo'),
        ),
        if (settings.adminKey != null)
          TextButton(
            onPressed: () => _open(
              context,
              AdminPage(
                admin: WorkerAdmin(
                  WorkerApi(settings.workerUrl!),
                  settings.adminKey!,
                ),
              ),
            ),
            child: const Text('Administração'),
          ),
        TextButton(
          onPressed: () => _open(context, LabPage(capture: CaptureService())),
          child: const Text('Laboratório'),
        ),
        TextButton(
          onPressed: onEditSettings,
          child: const Text('Configurações'),
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: Column(
      children: [
        Expanded(child: _buttons(context)),
        const AvisoAtualizacao(),
      ],
    ),
  );

  Widget _buttons(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Wrap(
        spacing: 24,
        runSpacing: 24,
        alignment: WrapAlignment.center,
        children: [
          CartaoAcao(
            destaque: true,
            icone: Icons.screen_share_outlined,
            titulo: 'Transmitir',
            descricao: 'Compartilhar sua tela e o som do PC',
            onTap: () => _open(
              context,
              BroadcastPage(media: _media(), capture: RealCaptureControl()),
            ),
          ),
          CartaoAcao(
            icone: Icons.tv,
            titulo: 'Assistir',
            descricao: 'Entrar numa sala com o código',
            onTap: () => _open(context, WatchPage(media: _media())),
          ),
        ],
      ),
    ),
  );
}

/// Modo de diagnóstico (variável DENDEN_DIAG): mede a transmissão pelo
/// servidor de verdade e fecha o app.
class DiagApp extends StatefulWidget {
  const DiagApp({super.key, required this.config});

  final DiagConfig config;

  @override
  State<DiagApp> createState() => _DiagAppState();
}

class _DiagAppState extends State<DiagApp> {
  RTCVideoRenderer? _renderer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = View.of(context).display.size;
      runDiagnostic(
        widget.config,
        width: size.width.round(),
        height: size.height.round(),
        onWatching: (r) => setState(() => _renderer = r),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final renderer = _renderer;
    return MaterialApp(
      home: Scaffold(
        body: renderer == null
            ? const Center(child: Text('DenDen — diagnóstico'))
            : RTCVideoView(
                renderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
              ),
      ),
    );
  }
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
