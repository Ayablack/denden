import 'package:flutter/material.dart';

void main() => runApp(const DenDenApp());

class DenDenApp extends StatelessWidget {
  const DenDenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DenDen',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const Scaffold(
        body: Center(child: Text('DenDen — Fase A (validação local)')),
      ),
    );
  }
}
