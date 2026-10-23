import 'package:denden/capture/capture_service.dart';
import 'package:denden/capture/hybrid_capture.dart';
import 'package:denden/capture/quality_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class FakeTrack extends Fake implements MediaStreamTrack {
  FakeTrack(this.kind, this.id);

  @override
  final String kind;
  @override
  final String id;
  bool stopped = false;
  bool _enabled = true;

  @override
  bool get enabled => _enabled;
  @override
  set enabled(bool v) => _enabled = v;

  @override
  Future<void> stop() async => stopped = true;
}

class FakeStream extends Fake implements MediaStream {
  FakeStream(this.id, [List<FakeTrack>? tracks]) : tracks = tracks ?? [];

  @override
  final String id;
  final List<FakeTrack> tracks;
  bool disposed = false;

  @override
  List<MediaStreamTrack> getTracks() => List.of(tracks);
  @override
  List<MediaStreamTrack> getVideoTracks() =>
      tracks.where((t) => t.kind == 'video').toList();
  @override
  List<MediaStreamTrack> getAudioTracks() =>
      tracks.where((t) => t.kind == 'audio').toList();
  @override
  Future<void> addTrack(
    MediaStreamTrack track, {
    bool addToNative = true,
  }) async => tracks.add(track as FakeTrack);
  @override
  Future<void> dispose() async => disposed = true;
}

const screen = CaptureSource(id: '0', name: 'Tela 1', isWindow: false);
const game = CaptureSource(id: '42', name: 'Jogo', isWindow: true);

void main() {
  late List<Map<String, Object?>> calls;
  late FakeStream screenStream;
  late FakeStream windowStream;
  late FakeStream combined;
  Object? windowError;
  late bool windowHasAudio;

  HybridCapture make() => HybridCapture(
    getDisplayMedia: (c) async {
      calls.add(c);
      final id = ((c['video'] as Map)['deviceId'] as Map)['exact'];
      if (id == '0') return screenStream;
      if (windowError != null) throw windowError!;
      if (!windowHasAudio) {
        windowStream.tracks.removeWhere((t) => t.kind == 'audio');
      }
      return windowStream;
    },
    createStream: (_) async => combined,
  );

  setUp(() {
    calls = [];
    screenStream = FakeStream('s', [FakeTrack('video', 'sv')]);
    windowStream = FakeStream('w', [
      FakeTrack('video', 'wv'),
      FakeTrack('audio', 'wa'),
    ]);
    combined = FakeStream('c');
    windowError = null;
    windowHasAudio = true;
  });

  test('pede a tela sem áudio e a janela com áudio a 1 fps', () async {
    await make().start(
      screen: screen,
      audioWindow: game,
      profile: QualityProfile.high,
    );
    expect(calls, hasLength(2));
    expect(calls[0]['audio'], false);
    expect(((calls[0]['video'] as Map)['mandatory'] as Map)['frameRate'], 60.0);
    expect(calls[1]['audio'], true);
    expect(((calls[1]['video'] as Map)['deviceId'] as Map)['exact'], '42');
    expect(((calls[1]['video'] as Map)['mandatory'] as Map)['frameRate'], 1.0);
  });

  test('stream final: vídeo da tela e áudio da janela, nada mais', () async {
    final s = await make().start(
      screen: screen,
      audioWindow: game,
      profile: QualityProfile.high,
    );
    expect(s.getTracks().map((t) => t.id), ['sv', 'wa']);
  });

  test(
    'vídeo da janela fica vivo e desligado (parar derrubaria o áudio)',
    () async {
      await make().start(
        screen: screen,
        audioWindow: game,
        profile: QualityProfile.high,
      );
      final wv = windowStream.tracks.firstWhere((t) => t.id == 'wv');
      expect(wv.stopped, isFalse);
      expect(wv.enabled, isFalse);
    },
  );

  test(
    'se a captura da janela falha, a tela é liberada e o erro sobe',
    () async {
      windowError = Exception('janela sumiu');
      await expectLater(
        make().start(
          screen: screen,
          audioWindow: game,
          profile: QualityProfile.high,
        ),
        throwsA(isA<Exception>()),
      );
      expect(screenStream.tracks.single.stopped, isTrue);
      expect(screenStream.disposed, isTrue);
    },
  );

  test('janela sem trilha de áudio: libera tudo e avisa', () async {
    windowHasAudio = false;
    await expectLater(
      make().start(
        screen: screen,
        audioWindow: game,
        profile: QualityProfile.high,
      ),
      throwsA(
        isA<HybridCaptureError>().having((e) => e.code, 'code', 'sem_audio'),
      ),
    );
    expect(screenStream.tracks.every((t) => t.stopped), isTrue);
    expect(windowStream.tracks.every((t) => t.stopped), isTrue);
    expect(screenStream.disposed && windowStream.disposed, isTrue);
  });

  test('stop libera as duas capturas e pode ser chamado duas vezes', () async {
    final h = make();
    await h.start(
      screen: screen,
      audioWindow: game,
      profile: QualityProfile.high,
    );
    await h.stop();
    await h.stop();
    expect(
      [...screenStream.tracks, ...windowStream.tracks].every((t) => t.stopped),
      isTrue,
    );
    expect(
      screenStream.disposed && windowStream.disposed && combined.disposed,
      isTrue,
    );
  });

  test('fontes trocadas são recusadas antes de capturar', () async {
    await expectLater(
      make().start(
        screen: game,
        audioWindow: game,
        profile: QualityProfile.high,
      ),
      throwsArgumentError,
    );
    await expectLater(
      make().start(
        screen: screen,
        audioWindow: screen,
        profile: QualityProfile.high,
      ),
      throwsArgumentError,
    );
    expect(calls, isEmpty);
  });
}
