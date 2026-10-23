import 'package:flutter/material.dart';

import 'capture/capture_service.dart';
import 'lab/lab_page.dart';
import 'lab/soak.dart';

void main() {
  final soak = SoakConfig.fromEnvironment();
  if (soak != null) {
    runApp(SoakApp(config: soak));
    return;
  }
  runApp(const DenDenApp());
}

class DenDenApp extends StatelessWidget {
  const DenDenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DenDen',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      // Fase A: o app é só o laboratório.
      home: LabPage(capture: CaptureService()),
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
