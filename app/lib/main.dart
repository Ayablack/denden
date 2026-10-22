import 'package:flutter/material.dart';

import 'capture/capture_service.dart';
import 'lab/lab_page.dart';

void main() => runApp(const DenDenApp());

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
