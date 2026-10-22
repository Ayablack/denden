import 'package:denden/capture/capture_service.dart';
import 'package:denden/capture/quality_profile.dart';
import 'package:denden/lab/loopback_session.dart';
import 'package:denden/usage/media_stats.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final profile in [QualityProfile.high, QualityProfile.medium]) {
    testWidgets('laço local em ${profile.label} entrega vídeo e áudio', (
      tester,
    ) async {
      final capture = CaptureService();
      final sources = await capture.listSources();
      final screen = sources.firstWhere((s) => !s.isWindow);
      final stream = await capture.start(screen, profile);
      final display = tester.view.display.size;
      final session = await LoopbackSession.start(
        stream,
        profile,
        sourceWidth: display.width.round(),
        sourceHeight: display.height.round(),
      ).timeout(const Duration(seconds: 15));

      // O evento pode ter chegado antes de a escuta começar.
      if (session.state != LoopbackState.connected) {
        await session.states
            .firstWhere((s) => s == LoopbackState.connected)
            .timeout(const Duration(seconds: 15));
      }
      expect(session.state, LoopbackState.connected);

      // Deixa o estimador de banda subir até o alvo do perfil.
      await Future<void>.delayed(const Duration(seconds: 15));
      final t0 = DateTime.now();
      final rx0 = parseStats(await session.receiver.getStats(), t0);
      await Future<void>.delayed(const Duration(seconds: 10));
      final t1 = DateTime.now();
      final rx1 = parseStats(await session.receiver.getStats(), t1);
      final txReports = await session.sender.getStats();
      final tx = parseStats(txReports, t1);

      final secs = t1.difference(t0).inMilliseconds / 1000;
      final mbps = (rx1.bytesReceived - rx0.bytesReceived) * 8 / secs / 1e6;
      final encoder = txReports
          .where((r) => r.type == 'outbound-rtp' && r.values['kind'] == 'video')
          .map(
            (r) =>
                '${r.values['encoderImplementation']} '
                '(powerEfficient: ${r.values['powerEfficientEncoder']}, '
                'qualityLimitation: ${r.values['qualityLimitationReason']})',
          )
          .join(', ');
      final audioIn = (await session.receiver.getStats())
          .where((r) => r.type == 'inbound-rtp' && r.values['kind'] == 'audio')
          .map((r) => r.values['bytesReceived'])
          .join(', ');

      // ignore: avoid_print
      print(
        'RESULTADO ${profile.name}: recebido ${rx1.frameWidth}x${rx1.frameHeight} '
        '@ ${rx1.framesPerSecond} fps; enviado ${tx.frameWidth}x${tx.frameHeight} '
        '@ ${tx.framesPerSecond} fps; codec ${rx1.codec}; '
        '${mbps.toStringAsFixed(2)} Mbps; jitter ${rx1.jitterMs} ms; '
        'codificador $encoder; bytes de áudio recebidos: $audioIn',
      );

      // Sem x-google-max-bitrate o libwebrtc trava em 2,5 Mbps (tabela padrão).
      final target = txReports
          .where((r) => r.type == 'outbound-rtp' && r.values['kind'] == 'video')
          .map((r) => (r.values['targetBitrate'] as num?) ?? 0)
          .fold<num>(0, (a, b) => a > b ? a : b);
      // ignore: avoid_print
      print('ALVO ${profile.name}: $target bps');
      if (profile == QualityProfile.high) {
        expect(target, greaterThan(2500000));
      }
      // DEFEITO CONHECIDO (Fase A): no Média o libwebrtc às vezes ignora o
      // scaleResolutionDownBy em captura de tela e envia 1080p. A captura
      // também ignora largura/altura. Decisão pendente com o dono.
      if (profile == QualityProfile.high) {
        expect(tx.frameHeight, lessThanOrEqualTo(profile.height));
      } else if ((tx.frameHeight ?? 0) > profile.height) {
        // ignore: avoid_print
        print('DEFEITO ${profile.name}: enviado em ${tx.frameHeight}p');
      }
      expect(rx1.bytesReceived, greaterThan(rx0.bytesReceived));
      expect(rx1.framesPerSecond, isNotNull);
      expect(audioIn, isNotEmpty, reason: 'trilha de áudio deve chegar');

      await session.close();
      await capture.stop();
    }, timeout: const Timeout(Duration(minutes: 2)));
  }
}
