import 'package:denden/ui/usage_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> usage({
  double effectiveGb = 400,
  double? confirmedGb,
  double? billedBrl,
  double projectionGb = 600,
}) => {
  'month': '2026-10',
  'reportedEgressBytes': 380e9,
  'serverEgressBytes': effectiveGb * 1e9,
  'effectiveEgressBytes': effectiveGb * 1e9,
  'confirmedGb': confirmedGb,
  'billedBrl': billedBrl,
  'estimatedCostUsd': 0,
  'estimatedCostBrl': 0,
  'percentOfBudget': effectiveGb / 900 * 100,
  'warnings': [
    {'percent': 50, 'reached': effectiveGb >= 450},
    {'percent': 75, 'reached': false},
    {'percent': 90, 'reached': false},
    {'percent': 100, 'reached': false},
  ],
  'level': 'normal',
  'projectionBytes': projectionGb * 1e9,
  'config': {
    'budgetGb': 900,
    'warnPercents': [50, 75, 90, 100],
    'ceilingPercent': 105,
    'usdPerGb': 0.05,
    'freeGb': 1000,
    'brlPerUsd': 5.5,
  },
  'emergency': false,
  'rooms': [
    {
      'code': 'K7P92Q',
      'startedAt': 0,
      'publisherSentBytes': 3e9,
      'egressBytes': 5.4e9,
      'viewers': [
        {'id': 'v1', 'receivedBytes': 2.7e9},
        {'id': 'v2', 'receivedBytes': 2.7e9},
      ],
    },
  ],
  'history': [
    {
      'code': 'ABC234',
      'startedAt': 0,
      'endedAt': 3600000,
      'reason': 'parado',
      'egressBytes': 8.1e9,
    },
  ],
  'notice': 'O bloqueio do DenDen não é um limite garantido de faturamento do Cloudflare.',
};

Future<void> open(WidgetTester tester, Map<String, dynamic> data) async {
  await tester.pumpWidget(
    MaterialApp(home: UsagePage(load: () async => data, autoRefresh: false)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('os quatro tipos de número, cada um com seu rótulo', (
    tester,
  ) async {
    await open(tester, usage());
    expect(find.text('Estimado'), findsOneWidget);
    expect(find.text('Confirmado pelo Cloudflare'), findsOneWidget);
    expect(find.text('Custo estimado'), findsOneWidget);
    expect(find.text('Faturado'), findsOneWidget);
    // Sem valor informado pelo provedor: travessão, não zero.
    expect(find.text('—'), findsNWidgets(2));
    expect(find.text('400,00 GB'), findsOneWidget);
  });

  testWidgets('valores informados aparecem no lugar do travessão', (
    tester,
  ) async {
    await open(tester, usage(confirmedGb: 410, billedBrl: 0));
    expect(find.text('410,00 GB'), findsOneWidget);
    expect(find.text(r'R$ 0,00'), findsWidgets);
    expect(find.text('—'), findsNothing);
  });

  testWidgets('aviso fixo de que o bloqueio não é teto de fatura', (
    tester,
  ) async {
    await open(tester, usage());
    expect(find.textContaining('não é um limite garantido'), findsOneWidget);
  });

  testWidgets('indicadores 50/75/90/100% mostram o que já foi atingido', (
    tester,
  ) async {
    await open(tester, usage(effectiveGb: 500));
    expect(find.text('50% atingido'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('projeção acima do orçamento sugere Média ou Economia', (
    tester,
  ) async {
    await open(tester, usage(projectionGb: 1200));
    expect(find.textContaining('acima do orçamento'), findsOneWidget);
    expect(find.textContaining('Média'), findsOneWidget);
    expect(find.textContaining('Economia'), findsOneWidget);
  });

  testWidgets('por transmissão e por espectador, e o histórico', (
    tester,
  ) async {
    await open(tester, usage());
    expect(find.textContaining('K7P-92Q'), findsOneWidget);
    expect(find.textContaining('5,40 GB'), findsOneWidget);
    expect(find.textContaining('2,70 GB'), findsNWidgets(2));
    expect(find.textContaining('ABC-234'), findsOneWidget);
    expect(find.textContaining('8,10 GB'), findsOneWidget);
  });
}
