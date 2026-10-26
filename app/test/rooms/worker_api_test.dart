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

  test('relatório traz o fim pela duração máxima', () async {
    final r = await api(200, {
      'level': 'normal',
      'profile': 'high',
      'warnings': [],
      'sessionEndsAtMs': 21600000,
    }).report('k', 'K7P92Q', 'publisher', 0);
    expect(r.sessionEndsAtMs, 21600000);
  });

  test('resposta envia viewerId e answerSdp', () async {
    await api(200, {}).answer('k', 'K7P92Q', 'viewer-1', 'ANSWER');
    expect(sent.single.url.path, '/salas/K7P92Q/resposta');
    expect(jsonDecode(sent.single.body), {
      'viewerId': 'viewer-1',
      'answerSdp': 'ANSWER',
    });
  });

  test('encerrar sala usa POST sem corpo', () async {
    await api(200, {}).endRoom('k', 'K7P92Q');
    expect(sent.single.url.path, '/salas/K7P92Q/encerrar');
    expect(sent.single.method, 'POST');
    expect(sent.single.body, '{}');
  });

  test('consumo usa GET e retorna JSON', () async {
    final r = await api(200, {'total': 100}).usage('k');
    expect(sent.single.url.path, '/consumo');
    expect(sent.single.method, 'GET');
    expect(r, {'total': 100});
  });

  test('adminGet usa GET e retorna JSON', () async {
    final r = await api(200, {'status': 'ok'}).adminGet('admin-k', 'info');
    expect(sent.single.url.path, '/admin/info');
    expect(sent.single.method, 'GET');
    expect(sent.single.headers['X-DenDen-Admin'], 'admin-k');
    expect(r, {'status': 'ok'});
  });

  test('admin usa POST, manda corpo e retorna JSON', () async {
    final r = await api(200, {'result': 'done'}).admin(
        'admin-k', 'action', {'cmd': 'stop'});
    expect(sent.single.url.path, '/admin/action');
    expect(sent.single.method, 'POST');
    expect(sent.single.headers['X-DenDen-Admin'], 'admin-k');
    expect(jsonDecode(sent.single.body), {'cmd': 'stop'});
    expect(r, {'result': 'done'});
  });

  test('erro 500 generico vira WorkerError', () async {
    final e = await caught(api(500, {'error': 'falha_interna', 'message': 'Erro grave.'}).roomState('k', 'K7P92Q'));
    expect(e, isA<WorkerError>());
    expect((e as WorkerError).status, 500);
    expect(e.code, 'falha_interna');
    expect(e.message, 'Erro grave.');
  });

  test('JSON invalido vira WorkerUnavailable com mensagem em portugues', () async {
    final e = await caught(api(200, {}, raw: 'isso não é json').roomState('k', 'K7P92Q'));
    expect(e, isA<WorkerUnavailable>());
    expect((e as WorkerError).message, 'Resposta inesperada do servidor (200).');
  });

  test('relatorio sem endsAtMs e sessionEndsAtMs funciona', () async {
    final r = await api(200, {
      'level': 'normal',
      'profile': 'high',
      'warnings': [],
    }).report('k', 'K7P92Q', 'publisher', 0);
    expect(r.endsAtMs, isNull);
    expect(r.sessionEndsAtMs, isNull);
  });

  test('mensagem do WorkerError não tem chaves e está em português', () {
    final e = const WorkerError(400, 'bad_req', 'Deu ruim.');
    final str = e.toString();
    expect(str, isNot(contains('{')));
    expect(str, isNot(contains('}')));
    expect(str, 'WorkerError(400, bad_req): Deu ruim.');
  });

  test('erro 400 com json devolve fallback no WorkerError', () async {
    final e = await caught(api(400, {'error': 'desconhecido', 'message': 'Mensagem fallback.'}).roomState('k', 'K7P92Q'));
    expect(e, isA<WorkerError>());
    expect((e as WorkerError).status, 400);
    expect(e.code, 'desconhecido');
    expect(e.message, 'Mensagem fallback.');
  });

  test('erro 500 sem json devolve fallback no WorkerError (WorkerUnavailable)', () async {
    final e = await caught(api(500, {}, raw: 'texto').roomState('k', 'K7P92Q'));
    expect(e, isA<WorkerUnavailable>());
  });
}
