import 'dart:async';

import 'package:denden/lab/session_lock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uma operação só começa depois que a anterior terminou', () async {
    final lock = SessionLock();
    final events = <String>[];
    final release = Completer<void>();
    final first = lock.run(() async {
      events.add('parar: começo');
      await release.future;
      events.add('parar: fim');
    });
    final second = lock.run(() async => events.add('iniciar'));
    await Future<void>.delayed(Duration.zero);
    expect(events, ['parar: começo']);
    release.complete();
    await Future.wait([first, second]);
    expect(events, ['parar: começo', 'parar: fim', 'iniciar']);
  });

  test('erro numa operação não trava as próximas', () async {
    final lock = SessionLock();
    await expectLater(
      lock.run(() async => throw StateError('x')),
      throwsStateError,
    );
    expect(await lock.run(() async => 42), 42);
  });

  test('devolve o resultado da operação', () async {
    expect(await SessionLock().run(() async => 'ok'), 'ok');
  });
}
