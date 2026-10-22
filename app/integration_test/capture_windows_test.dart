import 'package:denden/capture/capture_service.dart';
import 'package:denden/capture/quality_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('captura a tela com vídeo e informa o áudio', (tester) async {
    final capture = CaptureService();
    final sources = await capture.listSources().timeout(
      const Duration(seconds: 15),
    );
    expect(sources, isNotEmpty);
    final screen = sources.firstWhere(
      (s) => !s.isWindow,
      orElse: () => sources.first,
    );

    final stream = await capture
        .start(screen, QualityProfile.high)
        .timeout(const Duration(seconds: 15));
    await Future<void>.delayed(const Duration(seconds: 3));

    expect(stream.getVideoTracks(), hasLength(1));
    // O áudio é julgado no protocolo manual (A1–A3); aqui só se registra.
    // ignore: avoid_print
    print(
      'fontes: ${sources.length} '
      '(janelas: ${sources.where((s) => s.isWindow).length}); '
      'trilhas de áudio na tela: ${stream.getAudioTracks().length}',
    );
    await capture.stop();
  }, timeout: const Timeout(Duration(minutes: 2)));
}
