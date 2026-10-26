import 'dart:convert';

import 'package:http/http.dart' as http;

/// Erro vindo do Worker, com código estável e mensagem em português.
/// A chave nunca entra aqui.
class WorkerError implements Exception {
  const WorkerError(this.status, this.code, this.message);

  final int status;
  final String code;
  final String message;

  @override
  String toString() => '$runtimeType($status, $code): $message';
}

class InvalidKey extends WorkerError {
  const InvalidKey(super.status, super.code, super.message);
}

class BudgetBlocked extends WorkerError {
  const BudgetBlocked(super.status, super.code, super.message);
}

class RoomFull extends WorkerError {
  const RoomFull(super.status, super.code, super.message);
}

class RoomNotFound extends WorkerError {
  const RoomNotFound(super.status, super.code, super.message);
}

class TooManyAttempts extends WorkerError {
  const TooManyAttempts(super.status, super.code, super.message);
}

class EmergencyStop extends WorkerError {
  const EmergencyStop(super.status, super.code, super.message);
}

/// Worker fora do ar, sem rede ou cota gratuita do Worker estourada
/// (erro 1027): nenhuma sessão nova é criada.
class WorkerUnavailable extends WorkerError {
  const WorkerUnavailable(String message) : super(0, 'indisponivel', message);
}

class LocalTrack {
  const LocalTrack({required this.mid, required this.trackName});
  final String mid;
  final String trackName;
  Map<String, String> toJson() => {'mid': mid, 'trackName': trackName};
}

typedef IceServers = List<Map<String, dynamic>>;

class CreatedRoom {
  const CreatedRoom(this.code, this.sessionId, this.answerSdp, this.iceServers);
  final String code;
  final String sessionId;
  final String answerSdp;
  final IceServers iceServers;
}

class JoinedRoom {
  const JoinedRoom(
    this.viewerId,
    this.sessionId,
    this.offerSdp,
    this.iceServers,
  );
  final String viewerId;
  final String sessionId;
  final String offerSdp;
  final IceServers iceServers;
}

class ReportReply {
  const ReportReply(
    this.level,
    this.profile,
    this.warnings,
    this.endsAtMs, {
    this.sessionEndsAtMs,
  });
  final String level;
  final String profile;
  final List<int> warnings;
  final int? endsAtMs;

  /// Fim pela duração máxima da transmissão (o app avisa 5 min antes).
  final int? sessionEndsAtMs;
}

const _alphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';

/// Mesma regra do Worker: aceita minúsculas, espaço e hífen.
String? normalizeRoomCode(String input) {
  final c = input.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
  if (c.length != 6 || c.split('').any((ch) => !_alphabet.contains(ch))) {
    return null;
  }
  return c;
}

String formatRoomCode(String code) =>
    '${code.substring(0, 3)}-${code.substring(3)}';

/// Cliente HTTP do Worker do DenDen. Uma função por rota.
class WorkerApi {
  WorkerApi(this.base, {http.Client? client})
    : _client = client ?? http.Client();

  final Uri base;
  final http.Client _client;

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    String? key,
    String? adminKey,
    Map<String, Object?>? body,
  }) async {
    final req = http.Request(method, base.resolve(path))
      ..headers['Content-Type'] = 'application/json';
    if (key != null) req.headers['X-DenDen-Key'] = key;
    if (adminKey != null) req.headers['X-DenDen-Admin'] = adminKey;
    if (body != null) req.body = jsonEncode(body);
    final http.Response res;
    try {
      res = await http.Response.fromStream(
        await _client.send(req).timeout(const Duration(seconds: 15)),
      );
    } catch (_) {
      throw const WorkerUnavailable(
        'Não foi possível falar com o servidor do DenDen. Confira a internet.',
      );
    }
    final text = utf8.decode(res.bodyBytes);
    if (text.contains('error code: 1027')) {
      throw const WorkerUnavailable(
        'O servidor do DenDen atingiu o limite gratuito de hoje.',
      );
    }
    Map<String, dynamic> json;
    try {
      json = text.isEmpty ? {} : jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      throw WorkerUnavailable(
        'Resposta inesperada do servidor (${res.statusCode}).',
      );
    }
    if (res.statusCode == 200) return json;
    final code = json['error'] as String? ?? 'erro';
    final msg = json['message'] as String? ?? 'Erro ${res.statusCode}.';
    throw switch (code) {
      'chave_invalida' => InvalidKey(res.statusCode, code, msg),
      'orcamento' => BudgetBlocked(res.statusCode, code, msg),
      'sala_cheia' => RoomFull(res.statusCode, code, msg),
      'sala_inexistente' => RoomNotFound(res.statusCode, code, msg),
      'bloqueado' => TooManyAttempts(res.statusCode, code, msg),
      'emergencia' => EmergencyStop(res.statusCode, code, msg),
      _ => WorkerError(res.statusCode, code, msg),
    };
  }

  String _code(String raw) =>
      normalizeRoomCode(raw) ??
      (throw const RoomNotFound(404, 'sala_inexistente', 'Código inválido.'));

  static IceServers _ice(Object? v) => [
    for (final s in (v as List? ?? const []))
      Map<String, dynamic>.from(s as Map),
  ];

  Future<IceServers> iceServers(String key) async =>
      _ice((await _send('GET', '/ice', key: key))['iceServers']);

  Future<CreatedRoom> createRoom(
    String key,
    String profile,
    String offerSdp,
    List<LocalTrack> tracks,
  ) async {
    final j = await _send(
      'POST',
      '/salas',
      key: key,
      body: {
        'profile': profile,
        'offerSdp': offerSdp,
        'tracks': [for (final t in tracks) t.toJson()],
      },
    );
    return CreatedRoom(
      j['code'] as String,
      j['sessionId'] as String,
      j['answerSdp'] as String,
      _ice(j['iceServers']),
    );
  }

  Future<JoinedRoom> joinRoom(String key, String code) async {
    final j = await _send(
      'POST',
      '/salas/${_code(code)}/entrar',
      key: key,
      body: {},
    );
    return JoinedRoom(
      j['viewerId'] as String,
      j['sessionId'] as String,
      j['offerSdp'] as String,
      _ice(j['iceServers']),
    );
  }

  Future<void> answer(
    String key,
    String code,
    String viewerId,
    String answerSdp,
  ) => _send(
    'POST',
    '/salas/${_code(code)}/resposta',
    key: key,
    body: {'viewerId': viewerId, 'answerSdp': answerSdp},
  );

  Future<ReportReply> report(
    String key,
    String code,
    String who,
    int bytes,
  ) async {
    final j = await _send(
      'POST',
      '/salas/${_code(code)}/relatorio',
      key: key,
      body: {'who': who, 'bytes': bytes},
    );
    return ReportReply(
      j['level'] as String,
      j['profile'] as String,
      [
        for (final w in (j['warnings'] as List? ?? const []))
          (w as num).toInt(),
      ],
      (j['endsAtMs'] as num?)?.toInt(),
      sessionEndsAtMs: (j['sessionEndsAtMs'] as num?)?.toInt(),
    );
  }

  Future<void> endRoom(String key, String code) =>
      _send('POST', '/salas/${_code(code)}/encerrar', key: key, body: {});

  Future<String> roomState(String key, String code) async =>
      (await _send('GET', '/salas/${_code(code)}', key: key))['state']
          as String;

  Future<Map<String, dynamic>> usage(String key) =>
      _send('GET', '/consumo', key: key);

  Future<Map<String, dynamic>> adminGet(String adminKey, String path) =>
      _send('GET', '/admin/$path', adminKey: adminKey);

  Future<Map<String, dynamic>> admin(
    String adminKey,
    String path, [
    Map<String, Object?> body = const {},
  ]) => _send('POST', '/admin/$path', adminKey: adminKey, body: body);
}
