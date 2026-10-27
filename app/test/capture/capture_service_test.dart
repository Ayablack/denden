import 'package:denden/capture/capture_service.dart';
import 'package:denden/capture/quality_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class _FakeTrack extends Fake implements MediaStreamTrack {
  _FakeTrack(this.id);
  @override
  final String id;
  bool stopped = false;
  @override
  Future<void> stop() async => stopped = true;
}

class _FakeStream extends Fake implements MediaStream {
  _FakeStream([List<MediaStreamTrack>? tracks]) : _tracks = tracks ?? const [];
  final List<MediaStreamTrack> _tracks;
  bool disposed = false;
  @override
  List<MediaStreamTrack> getTracks() => _tracks;
  @override
  List<MediaStreamTrack> getVideoTracks() => _tracks;
  @override
  Future<void> dispose() async => disposed = true;
}

const screen = CaptureSource(id: '0', name: 'Tela 1', isWindow: false);
const screen2 = CaptureSource(id: '1', name: 'Tela 2', isWindow: false);
const game = CaptureSource(id: '42', name: 'Jogo', isWindow: true);

void main() {
  late List<Map<String, Object?>> calls;
  late List<CaptureSource> sourcesNow;
  late List<_FakeStream> createdStreams;

  CaptureService make() => CaptureService(
    sourceLister: () async => sourcesNow,
    getDisplayMedia: (c) async {
      calls.add(c);
      final s = _FakeStream([_FakeTrack('v-${calls.length}')]);
      createdStreams.add(s);
      return s;
    },
  );

  setUp(() {
    calls = [];
    sourcesNow = [screen, screen2, game];
    createdStreams = [];
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

  test(
    'startVideoTrack captura nova tela com o fps do perfil sem parar a anterior',
    () async {
      final service = make();
      await service.start(screen, QualityProfile.high);
      expect(createdStreams.first.disposed, isFalse);

      final track = await service.startVideoTrack(
        screen2,
        QualityProfile.economy,
      );
      expect(track.id, 'v-2');
      expect(calls.last['audio'], isFalse);
      expect(
        ((calls.last['video'] as Map)['deviceId'] as Map)['exact'],
        '1',
      );
      expect(
        ((calls.last['video'] as Map)['mandatory'] as Map)['frameRate'],
        30.0,
      );
      expect(createdStreams.first.disposed, isFalse);

      await service.stop();
      expect(createdStreams.every((s) => s.disposed), isTrue);
    },
  );
}
