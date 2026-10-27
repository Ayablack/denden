import 'package:flutter/material.dart';

import '../sistema/reducao_volume.dart';

/// Na tela inicial: se o Windows ainda abaixa o som dos outros programas
/// durante "chamadas", o DenDen desliga isso sozinho e avisa que só vale
/// depois de reiniciar o PC (medido em 2026-10-27: antes de reiniciar, a
/// opção nova não tem efeito). Em qualquer erro, não mostra nada.
class AvisoReducaoVolume extends StatefulWidget {
  const AvisoReducaoVolume({
    super.key,
    this.ducking = const WindowsVolumeDucking(),
  });

  final VolumeDucking ducking;

  @override
  State<AvisoReducaoVolume> createState() => _AvisoReducaoVolumeState();
}

class _AvisoReducaoVolumeState extends State<AvisoReducaoVolume> {
  bool _mostrar = false;

  @override
  void initState() {
    super.initState();
    _aplicar();
  }

  Future<void> _aplicar() async {
    try {
      if (await widget.ducking.isOff()) return;
      await widget.ducking.setOff(true);
      if (mounted) setState(() => _mostrar = true);
    } catch (_) {
      // Sem permissão no registro: o DenDen funciona, só com o som abaixando.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_mostrar) return const SizedBox.shrink();
    return MaterialBanner(
      content: const Text(
        'O DenDen desligou a opção do Windows que abaixa o som do jogo e do '
        'Discord durante a transmissão. Reinicie o PC uma vez para valer.',
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() => _mostrar = false),
          child: const Text('Entendi'),
        ),
      ],
    );
  }
}
