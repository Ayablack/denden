import 'package:denden/capture/quality_profile.dart';
import 'package:denden/media/cloudflare_media.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('trilhas locais: nome pelo tipo e mid da negociação', () {
    final t = localTracksFromMids([('0', 'video'), ('1', 'audio')]);
    expect(t.map((x) => (x.mid, x.trackName)), [
      ('0', 'video'),
      ('1', 'audio'),
    ]);
  });

  test('tipos repetidos ganham sufixo para o nome ser único na sessão', () {
    final t = localTracksFromMids([('0', 'audio'), ('1', 'audio')]);
    expect(t.map((x) => x.trackName), ['audio', 'audio-2']);
  });

  test('sem mid depois da oferta é erro claro', () {
    expect(() => localTracksFromMids([(null, 'video')]), throwsStateError);
  });

  test('perfil no fio é o mesmo nome do Worker', () {
    for (final p in QualityProfile.values) {
      expect(profileFromWire(p.name), p);
    }
    expect(profileFromWire('desconhecido'), isNull);
  });
}
