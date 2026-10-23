# Experimento — Captura híbrida (2026-10-23)

> Branch `exp/captura-hibrida`. Local, sem servidor, R$ 0. Laço local no PC do dono (6 núcleos), versão **debug**, perfil Alta (1080p60).

## Pergunta

Dá para pegar o **vídeo da tela inteira** (captura DirectX, rápida) e o **áudio só da janela do jogo** (sem a voz do Discord), em duas capturas separadas?

## Como funciona

- `app/lib/capture/hybrid_capture.dart`: `getDisplayMedia` da tela **sem áudio** + `getDisplayMedia` da janela **com áudio a 1 fps**. O stream enviado leva só o vídeo da tela e o áudio da janela.
- **Achado no código do plugin:** o loopback de áudio é um só e para no `OnStop` de **qualquer** captura de vídeo (`flutter_screen_capture.cc`). Por isso o vídeo da janela não é parado: fica vivo, desligado e fora do stream.
- Teste real: `app/integration_test/hybrid_capture_windows_test.dart`, com janelas de teste próprias (`helpers/janela_teste.ps1`): "Jogo" (anima e toca som), "Jogo Mudo" e "Falso Discord" (toca som o tempo todo). Cada cenário roda em seu próprio processo (`helpers/rodar_cenarios.sh`).
- Áudio medido por `totalAudioEnergy` recebido em 10 s. CPU medida pelo tempo de processador do DenDen.

## Resultados

| Cenário | Vídeo enviado | Energia do áudio | CPU DenDen (1 núcleo = 100%) | CPU sistema |
|---|---|---|---|---|
| S1 janela do jogo (método atual) | **0 fps** com a janela de teste | 5,3e-3 | 24–26% | 54–65% |
| CSV do dono, janela real (Fase A) | 1928×1043 a **11–17 fps** | — | — | — |
| **S2 híbrido + jogo com som** | 1920×1080 a **39 fps** | **5,1e-3** (chegou) | 165% | 93% |
| **S2C híbrido mirando o "Discord" externo** | 1920×1080 a **48 fps** | **6,7e-3** (é capturável) | 161% | 77% |
| **S3C híbrido + jogo mudo, "Discord" externo tocando** | 1920×1080 a 16 fps (PC saturado) | **1,6e-8 (silêncio)** | 128% | 100% |
| S3/S3B mesmo teste, "Discord" filho do DenDen | 1920×1080 a 33–50 fps | 1,3e-8 | 139–147% | 91–100% |
| S4/S4B controle tela inteira, "Discord" filho do DenDen | 1920×1080 a 48–49 fps | 1,0e-7 (não entra: filhos são excluídos) | 154–155% | 97–100% |
| S4C controle tela inteira, "Discord" externo | — | — | **caiu 3 de 3 vezes** | — |
| S5 híbrido com janela já fechada | 1920×1080 a 52 fps | 1,2e-8 | 167% | 87% |
| S6 iniciar/parar 5 vezes no mesmo processo | — | — | **caiu no 3º ciclo** | — |

Latência de processamento (codificar + buffer + decodificar, sem captura, tela e rede): **41–74 ms** em carga normal, **187 ms** com o PC saturado (S3C). Ponta a ponta **não foi medida**.

## Critérios

| # | Critério do dono | Resultado |
|---|---|---|
| 1 | FPS bem melhor que 11–17 | ✅ **33–52 fps** em 1080p com carga normal, cerca de 3× mais. ⚠️ Caiu para 16 fps com o PC a 100%. |
| 2 | Áudio do jogo chega e fica sincronizado | ✅ chega. ⚠️ **Sincronia não medida**: vídeo e áudio vão no mesmo stream (o WebRTC sincroniza), mas falta a prova. |
| 3 | Voz do Discord não entra | ✅ **Comprovado com um processo de fora:** com o "Discord" tocando, 1,6e-8 mirando o jogo contra 6,7e-3 mirando o próprio "Discord", umas 400 mil vezes menos. Falta repetir com o Discord real e alguém falando. |
| 4 | FPS, resolução, CPU e latência medidos | ✅ tabela acima. A latência é só de processamento. |
| 5 | Recursos liberados, inclusive com erro | ✅ nos testes unitários (7 casos: falha da 2ª captura, janela sem áudio, parar 2 vezes). ❌ **No real: instável.** |

## Problemas encontrados

1. **Quedas do app nativo.** O app cai e a ferramenta perde a conexão:
   - S1 2/3, S2 2/3, S3 1/2, S3C 1/2, S2C 2/3, S4B 1/2, **S4C 3/3**, S6 no 3º ciclo. No total, cerca de 12 quedas em 22 execuções.
   - Sem registro de falha no Windows.
   - Vale **para qualquer captura**, não só a híbrida. A tela inteira com áudio de verdade de outro processo (S4C) caiu sempre.
   - **Contraponto:** na versão **release**, o dono fez pelo menos 4 iniciar/parar em 7 minutos sem queda relatada. Pode ser algo da versão debug ou do executor de testes, mas **não está provado**.
2. **CPU alta:** 1,3 a 1,7 núcleo só para o DenDen (codificação VP8 por software, sem placa de vídeo). No laço local o mesmo PC também decodifica. Codificar 1 quadro leva 14–25 ms, acima dos 16,7 ms que 60 fps permitem.
3. **Captura de janela (GDI):** 0 fps com a janela de teste e 11–17 fps com a janela real do dono.
4. **Janela fechada antes de começar (S5):** pelo código, o plugin volta para o áudio do **sistema todo** quando a janela não existe mais, o que traria o Discord. A medição saiu em silêncio, mas o "Discord" desse cenário era filho do DenDen, então não prova nada. **Recomendação:** conferir que a janela ainda existe logo antes de iniciar.
5. **Árvore de processos:** na tela inteira, o plugin exclui o DenDen e **todos os filhos dele**. Qualquer programa aberto pelo DenDen fica mudo.

## Veredito

**Viável para o que foi perguntado.** O fps é cerca de 3× melhor que o da janela, o áudio do jogo chega e a voz do "Discord" fica de fora, medido com um processo externo. **Fica preservada como candidata** para a próxima etapa, no branch `exp/captura-hibrida`.

**Não está pronta para uso real** por causa do problema 1 (quedas). Isso precisa ser resolvido antes da Fase B, porque transmitir, parar e transmitir de novo é o uso normal.

## Próximos passos sugeridos (não feitos)

1. **Teste de estabilidade na versão release, fora do executor de testes:** um modo do laboratório que faz N ciclos de iniciar/parar sozinho e grava um log. Separa "bug do app" de "bug da ferramenta". ~1 h.
2. Se cair também em release: testar outra versão do `flutter_webrtc` ou o `medea_flutter_webrtc`. É uma mudança maior: só com a sua aprovação.
3. Confirmar com o Discord real e alguém falando (2 min, manual).
4. Medir a sincronia com um vídeo de teste.
