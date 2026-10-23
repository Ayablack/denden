import 'package:denden/capture/capture_service.dart';
import 'package:denden/capture/discord.dart';
import 'package:denden/capture/quality_profile.dart';
import 'package:flutter_test/flutter_test.dart';

ProcessEntry p(String name, int pid, int parent) =>
    (name: name, pid: pid, parentPid: parent);

void main() {
  group('discordRoot', () {
    test('acha o processo principal entre os filhos', () {
      // Árvore real medida no PC do dono (2026-10-23).
      final procs = [
        p('explorer.exe', 20976, 1),
        p('Discord.exe', 6948, 20976),
        p('Discord.exe', 18584, 6948),
        p('Discord.exe', 4196, 6948),
        p('DiscordSystemHelper.exe', 24000, 3976),
        p('chrome.exe', 500, 20976),
      ];
      expect(discordRoot(procs), 6948);
    });

    test('Discord fechado: nada a excluir', () {
      expect(discordRoot([p('chrome.exe', 500, 1)]), isNull);
    });

    test('PTB e Canary contam; dois abertos é erro', () {
      expect(discordRoot([p('DiscordPTB.exe', 9, 1)]), 9);
      expect(
        () =>
            discordRoot([p('Discord.exe', 8, 1), p('DiscordCanary.exe', 9, 1)]),
        throwsA(isA<DiscordError>()),
      );
    });
  });

  test('lê o CSV do Get-CimInstance, pulando o cabeçalho', () {
    const csv =
        '"Name","ProcessId","ParentProcessId"\r\n'
        '"System","4","0"\r\n'
        '"Discord.exe","6948","20976"\r\n';
    expect(processesFromCim(csv), [
      p('System', 4, 0),
      p('Discord.exe', 6948, 20976),
    ]);
  });

  test('lê os PIDs do Discord no tasklist', () {
    const csv =
        '"System","4","Services","0","8.136 K"\r\n'
        '"Discord.exe","6948","Console","2","152.264 K"\r\n'
        '"Discord.exe","18584","Console","2","34.172 K"\r\n'
        '"DiscordSystemHelper.exe","24000","Console","2","12.856 K"\r\n';
    expect(discordPidsFromTasklist(csv), {6948, 18584});
  });

  group('discordLeaks', () {
    test('Discord excluído e ainda aberto: tudo certo', () {
      expect(discordLeaks(excludedRoot: 6948, running: {6948, 4196}), isFalse);
    });

    test('Discord fechado: tudo certo', () {
      expect(discordLeaks(excludedRoot: 6948, running: {}), isFalse);
      expect(discordLeaks(excludedRoot: null, running: {}), isFalse);
    });

    test('abriu depois do início: vaza', () {
      expect(discordLeaks(excludedRoot: null, running: {77}), isTrue);
    });

    test('fechou e abriu de novo (outro PID): vaza', () {
      expect(discordLeaks(excludedRoot: 6948, running: {9001}), isTrue);
    });
  });

  test('a restrição de áudio leva o PID a excluir', () {
    const screen = CaptureSource(id: '0', name: 'Tela', isWindow: false);
    final c = displayMediaConstraints(
      screen,
      QualityProfile.high,
      audio: true,
      excludeProcessId: 6948,
    );
    expect(c['audio'], {'excludeProcessId': 6948});
    expect(
      displayMediaConstraints(
        screen,
        QualityProfile.high,
        audio: true,
      )['audio'],
      isTrue,
    );
  });
}
