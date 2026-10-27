import 'dart:async';

import 'package:denden/atualizacao/atualizacao.dart';
import 'package:denden/ui/aviso_atualizacao.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(Widget w) => MaterialApp(home: Scaffold(body: w));

const nova = NovaVersao('1.0.3', 'https://x/z.zip', 10);

void main() {
  testWidgets('sem versão nova: só mostra a versão instalada', (t) async {
    await t.pumpWidget(
      app(AvisoAtualizacao(versao: '1.0.2', conferir: () async => null)),
    );
    await t.pump();
    expect(find.text('Versão 1.0.2'), findsOneWidget);
    expect(find.text('Atualizar'), findsNothing);
  });

  testWidgets('com versão nova: botão Atualizar mostra o progresso', (t) async {
    final fim = Completer<void>();
    void Function(double)? avisar;
    await t.pumpWidget(
      app(
        AvisoAtualizacao(
          versao: '1.0.2',
          conferir: () async => nova,
          instalar: (n, p) {
            avisar = p;
            return fim.future;
          },
        ),
      ),
    );
    await t.pump();
    expect(find.text('Versão 1.0.3 disponível'), findsOneWidget);
    await t.tap(find.text('Atualizar'));
    await t.pump();
    avisar!(0.5);
    await t.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Atualizar'), findsNothing);
    fim.complete();
  });

  testWidgets('falha no download: mensagem simples e botão de novo', (t) async {
    await t.pumpWidget(
      app(
        AvisoAtualizacao(
          versao: '1.0.2',
          conferir: () async => nova,
          instalar: (n, p) async => throw Exception('rede'),
        ),
      ),
    );
    await t.pump();
    await t.tap(find.text('Atualizar'));
    await t.pump();
    await t.pump();
    expect(
      find.text('Não deu para atualizar. Tente de novo mais tarde.'),
      findsOneWidget,
    );
    expect(find.text('Atualizar'), findsOneWidget);
  });
}
