import 'dart:io';

/// O libwebrtc abre o áudio como "chamada", e o Windows então abaixa o som
/// dos outros programas (jogo, Discord) em 80% enquanto o DenDen transmite
/// ou assiste. Não dá para evitar pelo código: o que resolve é a opção do
/// Windows em Som → Comunicações → "Não fazer nada". Isto lê e muda essa
/// opção (só do usuário atual, sem precisar de administrador).
const _key = r'HKCU\Software\Microsoft\Multimedia\Audio';
const _value = 'UserDuckingPreference';

/// Valores do Windows: 0 silenciar, 1 reduzir 80% (padrão, quando não
/// existe), 2 reduzir 50%, 3 não fazer nada.
const _doNothing = 3;
const _windowsDefault = 1;

/// Lê o valor na saída do `reg query`. Sem o valor, vale o padrão.
int duckingFromRegQuery(String output) {
  final m = RegExp('$_value\\s+REG_DWORD\\s+0x([0-9a-fA-F]+)')
      .firstMatch(output);
  return m == null ? _windowsDefault : int.parse(m[1]!, radix: 16);
}

/// O que a tela de configurações usa (os testes usam uma versão falsa).
abstract class VolumeDucking {
  /// `true` se o Windows já está em "Não fazer nada".
  Future<bool> isOff();

  /// Liga ("Não fazer nada") ou volta ao padrão do Windows.
  Future<void> setOff(bool off);
}

class WindowsVolumeDucking implements VolumeDucking {
  const WindowsVolumeDucking();

  @override
  Future<bool> isOff() async {
    final r = await Process.run('reg', ['query', _key, '/v', _value]);
    return duckingFromRegQuery(r.stdout as String) == _doNothing;
  }

  @override
  Future<void> setOff(bool off) async {
    final r = await Process.run('reg', [
      'add',
      _key,
      '/v',
      _value,
      '/t',
      'REG_DWORD',
      '/d',
      '${off ? _doNothing : _windowsDefault}',
      '/f',
    ]);
    if (r.exitCode != 0) {
      throw const FileSystemException('Não deu para mudar a opção do Windows.');
    }
  }
}
