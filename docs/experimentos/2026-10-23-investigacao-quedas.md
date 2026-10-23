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

## Pilha de chamadas (WinDbg 1.2610 / cdb, despejo completo do ProcDump)

- **Reprodução antes do depurador:** 3 de 3 execuções do `loopback_windows_test.dart` caíram (`0xC0000005`).
- **ProcDump** (Sysinternals, assinado pela Microsoft, 1,3 MB, sem instalar): despejo reduzido (`-mp`) ilegível para o cdb ("partially initialized target"); despejo **completo** (`-ma`, 784 MB) legível.
- **Exceção:** `C0000005 ACCESS_VIOLATION`, leitura em `[rsi+10h]` com `rsi = 0x0000006200000000` (ponteiro inválido: objeto liberado ou corrompido).
- **Quando:** 31 s de vida do processo, **5 s depois de começar o 2º teste** (2ª sessão no mesmo processo).
- **Thread que caiu:** `#46 "worker_thread"`, thread de trabalho do WebRTC. As 10 chamadas estão em `libwebrtc.dll`, desde a criação da thread.
- **Símbolos:**
  - `libwebrtc.dll`: **sem símbolos** (o pacote não traz `.pdb`). Os nomes `libwebrtc::LibWebRTCLogging::removeLogSink+0x724c85` são só a exportação mais próxima, **não** a função real. Endereços sem nome.
  - `flutter_webrtc_plugin.dll` e `denden.exe` (debug): **com símbolos** e linha de código.
- **As outras threads naquele instante:**
  - Principal (`#0`): parada em `GetMessageW`, sem nenhuma chamada do DenDen em andamento.
  - `ApplicationLoopbackCapturer::CaptureThread` e `FeederThread`: vivas e **esperando** (`WaitForSingleObject`); nenhuma estava empurrando áudio.
  - `OnStop`: **não aparece** em nenhuma pilha.

## Testes que descartaram hipóteses

| Hipótese | Teste | Resultado |
|---|---|---|
| OnStop atrasado derruba o loopback novo | pausa de 2 s depois de cada parada (no `flutter test`) | continuou caindo → descartada |
| Perfil Média (reduz resolução) é o gatilho | 20 ciclos no Média fora da ferramenta, debug e release | 20/20 ok → descartada |
| `FeederThread` empurrando áudio na hora da queda | pilha | estava esperando → improvável |
| Queda só no debug | 84 ciclos fora da ferramenta em debug e release | 0 quedas nos dois |

## Causa provável (hipóteses, ainda sem a pilha de chamadas)

0. **Atualização depois da pilha:** a queda acontece numa thread interna do WebRTC (`worker_thread`), com um objeto já inválido, logo depois de **uma sessão ser encerrada e outra começar no mesmo processo**. A forma de encerrar e criar (ordem de liberação, operações simultâneas) é a suspeita principal. Só aparece sob o ritmo do `flutter test`: 0 de 84 ciclos fora dele.
1. **Liberar o renderizador de vídeo enquanto chegam quadros.** O WebRTC entrega quadros ao renderizador numa thread própria. Se a textura é removida do motor do Flutter no meio disso, sobra um ponteiro inválido. No `flutter test` o motor é controlado pela ferramenta, que muda o ritmo dos quadros e o que é desmontado entre um teste e outro.
2. **Corrida no `OnStop` do plugin.** O `OnStop` de qualquer captura destrói o capturador de áudio (`loopback_capturer_.reset()`) numa thread diferente da que cria o próximo.
3. **`FeederThread` chamando `CaptureFrame` depois de a trilha de áudio ser liberada.** O `Stop()` espera as threads terminarem, então é menos provável.

Nos dois casos de queda o primeiro teste terminou e o segundo estava começando. Isso aponta para **parar uma sessão e iniciar outra no mesmo processo**, com o ritmo da ferramenta.

## Atualização (correções e validação)

Ver [2026-10-23-estabilidade-resultados.md](2026-10-23-estabilidade-resultados.md): a correção 1 não resolveu a queda sob o `flutter test` (3/10); app normal sem quedas em 100 ciclos + 30 min.

## Problema confirmado à parte (não é queda)

- **Janela fechada:** pelo código do plugin (`loopback_capturer_factory.cc`), se a janela não existe mais, o áudio volta para o **sistema todo** e pega o Discord. Isso precisa de proteção no DenDen, seja qual for a causa das quedas.
