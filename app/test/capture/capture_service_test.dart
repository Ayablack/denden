import 'package:denden/capture/capture_service.dart';
import 'package:denden/capture/quality_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class _FakeStream extends Fake implements MediaStream {
  @override
  List<MediaStreamTrack> getTracks() => const [];
  @override
  Future<void> dispose() async {}
}

const screen = CaptureSource(id: '0', name: 'Tela 1', isWindow: false);
const game = CaptureSource(id: '42', name: 'Jogo', isWindow: true);

void main() {
  late List<Map<String, Object?>> calls;
  late List<CaptureSource> sourcesNow;

  CaptureService make() => CaptureService(
    sourceLister: () async => sourcesNow,
    getDisplayMedia: (c) async {
      calls.add(c);
      return _FakeStream();
    },
  );

  setUp(() {
    calls = [];
    sourcesNow = [screen, game];
  });

  test('janela com áudio que não existe mais: recusa sem capturar', () async {
    sourcesNow = [screen];
    await expectLater(
      make().start(game, QualityProfile.high),
      throwsA(
        isA<CaptureError>().having((e) => e.code, 'code', 'janela_inexistente'),
      ),
    );
    expect(calls, isEmpty);
  });

  test('janela que existe: captura normalmente', () async {
    await make().start(game, QualityProfile.high);
    expect(calls, hasLength(1));
  });

  test('tela inteira não depende da lista de janelas', () async {
    sourcesNow = [];
    await make().start(screen, QualityProfile.high, audio: false);
    expect(calls, hasLength(1));
  });
}
