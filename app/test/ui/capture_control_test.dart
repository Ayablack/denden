import 'package:flutter_test/flutter_test.dart';
import 'package:denden/ui/capture_control.dart';
import 'package:denden/capture/capture_service.dart';
import 'package:denden/rooms/worker_api.dart';

void main() {
  group('messageFor', () {
    test('WorkerError retorna a mensagem tratada', () {
      final erro = WorkerError(500, 'erro_worker', 'Erro no servidor Worker');
      expect(messageFor(erro), 'Erro no servidor Worker');
    });

    test('CaptureError retorna a mensagem tratada', () {
      final erro = CaptureError('erro_captura', 'Falha na captura');
      expect(messageFor(erro), 'Falha na captura');
    });

    test('erro desconhecido não expõe detalhes e retorna mensagem genérica', () {
      final erro = Exception('Erro interno do sistema');
      expect(messageFor(erro), 'Algo deu errado. Tente de novo.');
    });
  });
}
