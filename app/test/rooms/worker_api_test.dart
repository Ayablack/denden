import 'dart:convert';

import 'package:denden/rooms/worker_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Future<Object?> caught(Future<Object?> f) async {
  try {
    await f;
    return null;
  } catch (e) {
    return e;
  }
}

void main() {
  late List<http.Request> sent;

  WorkerApi api(int status, Object body, {String? raw}) => WorkerApi(
    Uri.parse('https://denden.exemplo.workers.dev'),
    client: MockClient((req) async {
      sent.add(req);
      return http.Response(
        raw ?? jsonEncode(body),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  );

  setUp(() => sent = []);

  test('criar sala manda chave, perfil, oferta e trilhas', () async {
    final r =
        await api(200, {
          'code': 'K7P92Q',
          'sessionId': 'S1',
          'answerSdp': 'RESP',
          'iceServers': [
            {'urls': 'stun:stun.cloudflare.com:3478'},
          ],
        }).createRoom('chave-ana', 'high', 'OFERTA', const [
          LocalTrack(mid: '0', trackName: 'video'),
        ]);
    expect(r.code, 'K7P92Q');
    expect(r.answerSdp, 'RESP');
    expect(sent.single.url.path, '/salas');
    expect(sent.single.headers['X-DenDen-Key'], 'chave-ana');
    expect(jsonDecode(sent.single.body), {
      'profile': 'high',
      'offerSdp': 'OFERTA',
      'tracks': [
        {'mid': '0', 'trackName': 'video'},
      ],
    });
  });

  test('normaliza o código digitado antes de enviar', () async {
    await api(200, {
      'viewerId': 'V',
      'sessionId': 'S2',
      'offerSdp': 'O',
      'iceServers': [],
    }).joinRoom('k', ' k7p-92q ');
    expect(sent.single.url.path, '/salas/K7P92Q/entrar');
  });

  test('código inválido nem chega ao Worker', () async {
    await expectLater(
      api(200, {}).joinRoom('k', 'K7P-920'),
      throwsA(
        isA<WorkerError>().having((e) => e.code, 'code', 'sala_inexistente'),
      ),
    );
    expect(sent, isEmpty);
  });

  test('409 sala_cheia vira RoomFull com a mensagem do Worker', () async {
    final e = await caught(
      api(409, {
        'error': 'sala_cheia',
        'message': 'A sala já tem 5 espectadores.',
      }).joinRoom('k', 'K7P92Q'),
    );
    expect(e, isA<RoomFull>());
    expect((e as WorkerError).message, 'A sala já tem 5 espectadores.');
  });

  test('códigos conhecidos viram tipos próprios', () async {
    Future<Object?> err(int s, String code) => caught(
      api(s, {'error': code, 'message': 'm'}).roomState('k', 'K7P92Q'),
    );
    expect(await err(401, 'chave_invalida'), isA<InvalidKey>());
    expect(await err(403, 'orcamento'), isA<BudgetBlocked>());
    expect(await err(404, 'sala_inexistente'), isA<RoomNotFound>());
    expect(await err(429, 'bloqueado'), isA<TooManyAttempts>());
    expect(await err(503, 'emergencia'), isA<EmergencyStop>());
  });

  test(
    'erro 1027 do Cloudflare (cota do Worker) vira WorkerUnavailable',
    () async {
      final e = await caught(
        api(503, {}, raw: 'error code: 1027').roomState('k', 'K7P92Q'),
      );
      expect(e, isA<WorkerUnavailable>());
    },
  );

  test('falha de rede vira WorkerUnavailable', () async {
    final a = WorkerApi(
      Uri.parse('https://x'),
      client: MockClient((_) => throw http.ClientException('sem rede')),
    );
    expect(await caught(a.iceServers('k')), isA<WorkerUnavailable>());
  });

  test('a chave não aparece no texto do erro', () async {
    final e = await caught(
      api(401, {
        'error': 'chave_invalida',
        'message': 'Chave do grupo inválida.',
      }).roomState('segredo-da-ana', 'K7P92Q'),
    );
    expect(e.toString(), isNot(contains('segredo-da-ana')));
  });

  test('relatório devolve nível, perfil, avisos e fim previsto', () async {
    final r = await api(200, {
      'level': 'blocked',
      'profile': 'economy',
      'warnings': [90, 100],
      'endsAtMs': 123,
    }).report('k', 'K7P92Q', 'publisher', 1000);
    expect(r.level, 'blocked');
    expect(r.profile, 'economy');
    expect(r.warnings, [90, 100]);
    expect(r.endsAtMs, 123);
    expect(jsonDecode(sent.single.body), {'who': 'publisher', 'bytes': 1000});
  });
}
