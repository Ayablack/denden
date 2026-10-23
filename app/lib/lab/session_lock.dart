import 'dart:async';

/// Fila de uma operação por vez: iniciar e encerrar sessões WebRTC nunca se
/// sobrepõem, e uma sessão nova só começa depois que a anterior terminou de
/// liberar conexões, trilhas, renderizadores e capturas.
class SessionLock {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() op) {
    final result = _tail.then((_) => op());
    // A próxima espera esta terminar, com sucesso ou erro.
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }
}
