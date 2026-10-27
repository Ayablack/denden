import 'package:flutter_test/flutter_test.dart';
import 'package:denden/sistema/reducao_volume.dart';

void main() {
  group('duckingFromRegQuery', () {
    test('valor 0', () {
      final regQueryOutput =
          r'HKEY_CURRENT_USER\Software\Microsoft\Multimedia\Audio    UserDuckingPreference    REG_DWORD    0x0';
      expect(duckingFromRegQuery(regQueryOutput), 0);
    });

    test('valor 1', () {
      final regQueryOutput =
          r'HKEY_CURRENT_USER\Software\Microsoft\Multimedia\Audio    UserDuckingPreference    REG_DWORD    0x1';
      expect(duckingFromRegQuery(regQueryOutput), 1);
    });

    test('valor 2', () {
      final regQueryOutput =
          r'HKEY_CURRENT_USER\Software\Microsoft\Multimedia\Audio    UserDuckingPreference    REG_DWORD    0x2';
      expect(duckingFromRegQuery(regQueryOutput), 2);
    });

    test('valor 3', () {
      final regQueryOutput =
          r'HKEY_CURRENT_USER\Software\Microsoft\Multimedia\Audio    UserDuckingPreference    REG_DWORD    0x3';
      expect(duckingFromRegQuery(regQueryOutput), 3);
    });

    test('valor ausente retorna o padrão (1)', () {
      final regQueryOutput =
          r'HKEY_CURRENT_USER\Software\Microsoft\Multimedia\Audio';
      expect(duckingFromRegQuery(regQueryOutput), 1);
    });

    test('texto vazio retorna o padrão (1)', () {
      expect(duckingFromRegQuery(''), 1);
    });
  });
}
