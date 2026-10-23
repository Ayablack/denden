import 'package:denden/capture/capture_service.dart';
import 'package:denden/capture/pc_sem_discord.dart';
import 'package:denden/capture/quality_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class FakeTrack extends Fake implements MediaStreamTrack {
  @override
  bool enabled = true;
  bool stopped = false;
  @override
  String? get id => 'a';
  @override
  Future<void> stop() async => stopped = true;
}

class FakeStream extends Fake implements MediaStream {
  final audio = FakeTrack();
  @override
  List<MediaStreamTrack> getTracks() => [audio];
  @override
  List<MediaStreamTrack> getAudioTracks() => [audio];
  @override
  Future<void> dispose() async {}
}

const screen = CaptureSource(id: '0', name: 'Tela', isWindow: false);

void main() {
  late List<Map<String, Object?>> asked;
  late FakeStream stream;
  late Set<int> running;

  PcWithoutDiscordCapture make() => PcWithoutDiscordCapture(
    capture: CaptureService(
      sourceLister: () async => const [screen],
      getDisplayMedia: (c) async {
        asked.add(c);
        return stream = FakeStream();
      },
    ),
    listProcesses: () async => [
      (name: 'explorer.exe', pid: 1, parentPid: 0),
      (name: 'Discord.exe', pid: 6948, parentPid: 1),
      (name: 'Discord.exe', pid: 4196, parentPid: 6948),
    ],
    runningDiscordPids: () async => running,
    watchEvery: const Duration(milliseconds: 10),
  );

  setUp(() {
    asked = [];
    running = {6948, 4196};
  });

  test('pede o som do PC sem a árvore do Discord principal', () async {
    final c = make();
    await c.start(screen, QualityProfile.high);
    expect(asked.single['audio'], {'excludeProcessId': 6948});
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(c.audioActive, isTrue);
    await c.stop();
  });

  test('Discord reaberto com outro PID: silencia e avisa', () async {
    final c = make();
    final errors = [];
    c.errors.listen(errors.add);
    await c.start(screen, QualityProfile.high);
    running = {9001};
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(stream.audio.enabled, isFalse);
    expect(c.audioActive, isFalse);
    expect(errors.single, isA<CaptureError>());
    expect((errors.single as CaptureError).code, 'discord_fora');
    await c.stop();
  });

  test('uma janela não serve de tela', () {
    const window = CaptureSource(id: '9', name: 'Jogo', isWindow: true);
    expect(
      () => make().start(window, QualityProfile.high),
      throwsArgumentError,
    );
  });
}
