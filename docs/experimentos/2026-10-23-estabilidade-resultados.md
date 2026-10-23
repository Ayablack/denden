# Estabilidade — Correções e validação (2026-10-23)

> Branch `fix/estabilidade`. Local, R$ 0. Investigação completa em [2026-10-23-investigacao-quedas.md](2026-10-23-investigacao-quedas.md). Logs em [logs-2026-10-23/](logs-2026-10-23/).

## Resumo

- **App rodando normalmente:** nenhuma queda em **100 ciclos** (50 release + 50 debug) nem numa **sessão contínua de 30 min** em release. Todos com áudio real de outro programa passando.
- **Dentro do `flutter test`:** a queda nativa **continua** (34/40 nas 10 rodadas com uma sessão por processo). **A causa não está resolvida**, só contida: ela aparece apenas sob a ferramenta de testes.
- **Proteção do áudio:** funcionando no teste real. Com a janela fechada no meio, o áudio para em 0,4 s com aviso. Iniciar com a janela já fechada é recusado sem capturar nada. Nunca caiu no áudio do computador inteiro.

## Correções feitas

### 1. Ciclo de vida das sessões (`lib/lab/loopback_session.dart`, `lib/lab/session_lock.dart`)

- **Uma operação por vez** (`SessionLock`): iniciar e encerrar nunca se sobrepõem; a sessão nova espera a anterior liberar tudo.
- **Ordem de encerramento:**
  1. desligar os retornos de chamada (`onIceCandidate`, `onTrack`, `onConnectionState`);
  2. tirar as trilhas do envio (`removeTrack`);
  3. soltar o vídeo do renderizador;
  4. fechar as duas conexões;
  5. liberar (`dispose`) as conexões e depois o renderizador.

  A captura é parada por quem a abriu, depois disso.
- Candidatos de rede atrasados não chegam mais a uma conexão em encerramento.
- Testes: `test/lab/session_lock_test.dart` (3), vistos falhando antes e passando depois.

**Efeito na queda sob o `flutter test`:** **não resolveu.** O teste que caía 3/3 passou **3/10** depois da correção (5× `0xC0000005`, 2× `0xC0000409`). Seguindo o combinado, não houve outras tentativas: adotada a estratégia de **uma sessão por processo** nos testes de integração (`integration_test/helpers/rodar_integracao.sh`) e a estabilidade real medida pelo modo de estresse.

### 2. Proteção do áudio (`lib/capture/capture_service.dart`, `lib/capture/hybrid_capture.dart`)

- **Antes de iniciar:** confere na lista atual de fontes que a janela existe. Se não existe: erro `janela_inexistente` ("A janela "…" não existe mais. Abra o jogo e escolha a janela de novo."), **sem abrir nenhuma captura**. Vale para a captura híbrida e para a captura de janela antiga.
- **Durante a transmissão (híbrida):** vigia a janela a cada 2 s. Se ela some:
  - para **toda** a captura da janela, vídeo e áudio. O `OnStop` do plugin derruba o loopback, então nada cai no áudio geral;
  - **mantém o vídeo da tela**;
  - avisa com `janela_fechou` ("A janela "…" fechou. O áudio foi interrompido para não capturar o som do computador inteiro.").
- Testes: 3 em `test/capture/capture_service_test.dart` e 3 novos em `test/capture/hybrid_capture_test.dart`. Falharam antes (não compilavam sem a implementação) e passam depois.
- **Limitação:** o aviso é emitido (`HybridCapture.errors`) e registrado, mas **ainda não aparece numa tela do app**. A tela de transmissão é da Fase B (Task 12).

## Validação

### App rodando normalmente (`.exe` sem a ferramenta de testes)

| Teste | Resultado |
|---|---|
| 50 ciclos híbrido, release (5 s cada) | **50/50**, saída 0, áudio em todos (energia 1,7e-3 a 3,4e-2) |
| 50 ciclos híbrido, debug | **50/50**, saída 0, áudio em todos (2,3e-3 a 3,2e-2) |
| Sessão contínua de 30 min, release | **sem queda**, saída 0, 351 medições |
| Fechar a janela no meio (release) | aviso em **0,36 s**; energia **parada** pelos 27 s seguintes com o "Falso Discord" tocando; vídeo seguiu |
| Iniciar com a janela já fechada | recusado (`janela_inexistente`), nada capturado |

**Medidas da sessão de 30 min** (vídeo da tela + áudio de uma janela, perfil Alta, laço local):

| Medida | Mín | Mediana | Máx |
|---|---|---|---|
| FPS enviado | 36,7 | **51,5** | 53,7 |
| Resolução | 1080p em 341 de 351 amostras (720p: 9, 360p: 1, no aquecimento) | | |
| Motivo de limitação | `none` 341, `cpu` 8, `bandwidth` 2 | | |
| Tempo para codificar 1 quadro | 2,3 ms | 12,7 ms | 18,9 ms |
| CPU do DenDen (100% = 1 núcleo) | 161% | **182%** | 209% |
| Diferença de reprodução vídeo − áudio (estimada) | −175 ms | **−3 ms** | +44 ms |
| Energia do áudio a cada 5 s | 9,3e-4 | — | 3,5e-3 (nunca zero) |

- **Sincronia:** 350 de 351 amostras dentro de ±80 ms e 340 dentro de ±40 ms. É uma **estimativa** pelo `estimatedPlayoutTimestamp` do WebRTC, não uma medição com câmera.
- **FPS:** a captura de janela antiga dava 11–17 fps (CSV do dono). A híbrida deu mediana de 51,5 fps em 1080p.
- **CPU:** ~30% do processador inteiro (6 núcleos). No laço local o mesmo PC também decodifica. A janela de teste é leve: **com um jogo de verdade não foi medido**.

### Dentro da ferramenta de testes (`flutter test`)

| Teste | Resultado |
|---|---|
| Laço local com 2 sessões, **antes** da correção 1 | 0/3 (quedas `0xC0000005`) |
| O mesmo, **depois** da correção 1, 10 seguidas | **3/10** (5× `0xC0000005`, 2× `0xC0000409`) |
| 10 rodadas, **uma sessão por processo** (40 execuções) | **34/40** |
| — só captura (sem conexão WebRTC) | 10/10 |
| — laço em Alta | 8/10 |
| — laço em Média | 9/10 |
| — tela do laboratório | 7/10 |

As quedas sob a ferramenta acontecem só em testes **com conexão WebRTC**, às vezes já nos primeiros segundos da 1ª sessão.

## Causa da queda: o que se sabe e o que não

- **Sabe-se:**
  - violação de acesso na `worker_thread` do `libwebrtc.dll`, com um ponteiro inválido;
  - nenhuma chamada do DenDen ou do plugin em andamento na hora (pilha via WinDbg);
  - só sob o `flutter test`, e só com conexão WebRTC.
- **Não se sabe:** qual objeto é. O `libwebrtc.dll` não tem símbolos. Também não se sabe por que a ferramenta expõe o problema e o uso normal não. A suspeita é o ritmo diferente de quadros e threads sob o executor de testes.
- **Não está provado** que o uso normal nunca vai cair. Está provado que **não caiu** em 100 ciclos + 30 min.

## Limitações restantes

1. Queda nativa sob o `flutter test` (15% das execuções com WebRTC), sem causa conhecida.
2. O aviso de "janela fechou" ainda não aparece na interface (Fase B, Task 12).
3. CPU alta (~1,8 núcleo): codificação VP8 por software.
4. Não testado ainda: Discord real com alguém falando, jogo real, sincronia medida com câmera.

## Recomendação

**A versão local está estável o bastante para seguir com as avaliações separadas que o dono pediu**: CPU com jogo real, sincronia medida e Discord real. A queda sob a ferramenta fica como **risco conhecido**: o modo de estresse continua sendo o teste oficial de estabilidade, e os testes de integração rodam uma sessão por processo, com a falha registrada. Se ela aparecer no uso normal, o próximo passo é testar outra versão do `flutter_webrtc` (mudança maior, só com aprovação).
