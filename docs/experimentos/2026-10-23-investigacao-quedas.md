# Investigação das quedas (2026-10-23)

> Branch `fix/estabilidade`. Até aqui **nada foi corrigido**: só instrumentação (modo de estresse `DENDEN_SOAK`, `rodar_estresse.ps1`, `vigiar_saida.ps1`).

## Evidência

### Fora da ferramenta de testes (o `.exe` rodando sozinho)

| Versão | Modo | Ciclos × tempo | Resultado | Áudio passando? |
|---|---|---|---|---|
| Release | tela sem áudio | 10 × 5 s | 10/10, saída 0 | — |
| Release | **híbrido**, áudio de outro programa | 10 × 5 s | 10/10, saída 0 | sim (energia 0,002–0,011) |
| Release | **tela com áudio**, áudio de outro programa | 10 × 5 s | 10/10, saída 0 | sim (0,002–0,011) |
| Debug | tela sem áudio | 10 × 5 s | 10/10, saída 0 | — |
| Debug | híbrido | 10 × 5 s | 10/10, saída 0 | sim |
| Debug | tela com áudio | 10 × 5 s | 10/10, saída 0 | sim |
| Release | tela com áudio | 6 × 25 s | 6/6, saída 0 | sim |
| Debug | tela com áudio | 6 × 25 s | 6/6, saída 0 | sim |

**Total: 64 de 64 ciclos sem queda.** Inclui o caso "tela inteira + áudio real de outro programa", que caía 3 de 3 vezes dentro do `flutter test`.

### Dentro da ferramenta (`flutter test`, `loopback_windows_test.dart`)

Um vigia pegou o `denden.exe` assim que ele abriu e registrou o código de saída:

| Execução | Resultado do teste | Código de saída do app | Quando |
|---|---|---|---|
| 1 | did not complete | **0xC0000005** (violação de acesso) | ~30 s, entre o 1º e o 2º teste |
| 2 | passou | 0xFFFFFFFF (ferramenta fechou o app no fim) | — |
| 3 | passou | 0xFFFFFFFF | — |
| 4 | did not complete | **0xC0000005** | ~30 s, entre o 1º e o 2º teste |

**Conclusão parcial:** a queda é **nativa e real** (violação de acesso no processo do app). Mas só apareceu dentro do `flutter test`: 2 de 4 execuções contra 0 de 64 ciclos fora dele.

## Causa provável (hipóteses, ainda sem a pilha de chamadas)

1. **Liberar o renderizador de vídeo enquanto chegam quadros.** O WebRTC entrega quadros ao renderizador numa thread própria. Se a textura é removida do motor do Flutter no meio disso, sobra um ponteiro inválido. No `flutter test` o motor é controlado pela ferramenta, que muda o ritmo dos quadros e o que é desmontado entre um teste e outro.
2. **Corrida no `OnStop` do plugin.** O `OnStop` de qualquer captura destrói o capturador de áudio (`loopback_capturer_.reset()`) numa thread diferente da que cria o próximo.
3. **`FeederThread` chamando `CaptureFrame` depois de a trilha de áudio ser liberada.** O `Stop()` espera as threads terminarem, então é menos provável.

Nos dois casos de queda o primeiro teste terminou e o segundo estava começando. Isso aponta para **parar uma sessão e iniciar outra no mesmo processo**, com o ritmo da ferramenta.

## Problema confirmado à parte (não é queda)

- **Janela fechada:** pelo código do plugin (`loopback_capturer_factory.cc`), se a janela não existe mais, o áudio volta para o **sistema todo** e pega o Discord. Isso precisa de proteção no DenDen, seja qual for a causa das quedas.
