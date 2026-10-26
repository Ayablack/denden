# DenDen

> **Projeto pessoal, em desenvolvimento.** A primeira versão está construída e testada localmente; o **primeiro teste real entre dois computadores ainda não foi feito**.

Transmissão privada de tela e áudio entre amigos, no **Windows**. A conversa de voz continua no Discord; o DenDen só transmite a imagem e o som do jogo (ou de um filme, série, anime). Até **5 espectadores**, normalmente 3.

O nome vem dos Den Den Mushi de One Piece, os caracóis usados para comunicação à distância. O projeto não usa imagens oficiais do anime.

## O que ele faz hoje

- **Transmitir:**
  - vídeo da **tela inteira**, por captura rápida, até 1080p60 quando o PC aguenta;
  - **som do PC inteiro menos o Discord** (padrão), ou só o som de uma janela, ou sem áudio. A voz do Discord não entra, e ninguém ouve voz duplicada. Se outro Discord abrir no meio, o som é silenciado com aviso;
  - no modo janela, se a janela do jogo fecha, o áudio para e aparece um aviso. O vídeo continua;
  - opção de impedir que o Windows abaixe em 80% o volume dos outros programas enquanto o DenDen transmite.
- **Salas privadas:** código de 6 caracteres (ex.: `K7P-92Q`), chave pessoal por amigo, até 5 espectadores, bloqueio após 5 códigos errados.
- **Assistir:** digitar o código e ver a tela do amigo em tamanho cheio, com o som do jogo.
- **Consumo e custos:**
  - painel com o tráfego por transmissão, por espectador e do mês;
  - números sempre rotulados: **estimado**, **confirmado pelo Cloudflare**, **custo estimado** e **faturado**;
  - avisos em 50/75/90/100% do orçamento.
- **Proteção do orçamento, feita no servidor (não na tela):**
  - a 100% recusa novas transmissões e passa as atuais para a qualidade Economia;
  - a 105% encerra a sessão depois de 60 s de aviso;
  - **botão de emergência** que desliga tudo;
  - o bloqueio do DenDen **não** é um limite garantido de faturamento do Cloudflare.
- **Administração** (chave separada): criar e revogar chaves dos amigos, ajustar limites e registrar os valores confirmados e faturados.
- **Laboratório:** transmite para o próprio PC, sem servidor, para medir fps, codec, bitrate e áudio, e exportar CSV para o Excel.

## Como funciona

```
 Quem transmite (Windows)          Cloudflare                        Quem assiste (Windows)
 ┌──────────────────────┐ 1 fluxo  ┌─────────────────────┐ 1 fluxo   ┌──────────────────────┐
 │ App Flutter          ├─────────►│ Realtime SFU        ├──────────►│ App Flutter          │
 │ tela + áudio do jogo │  WebRTC  │ (repassa o vídeo)   │ por pessoa│ vídeo + som          │
 └──────────┬───────────┘          └─────────────────────┘           └──────────┬───────────┘
            │ HTTPS                ┌─────────────────────┐            HTTPS     │
            └─────────────────────►│ Worker + Durable    │◄─────────────────────┘
                                   │ Object: salas,      │
                                   │ chaves, consumo,    │
                                   │ limites             │
                                   └─────────────────────┘
```

- Nenhum PC dos amigos funciona como servidor. Quem transmite manda **uma** cópia; o SFU distribui.
- A chave do Cloudflare fica **só** no Worker (`wrangler secret put`), nunca no app nem no repositório.

## Estrutura

| Pasta | O que tem |
|---|---|
| `app/` | App Windows em Flutter (captura, WebRTC, telas, laboratório, modo de estresse) |
| `backend/worker/` | Cloudflare Worker em TypeScript (rotas, salas, consumo, limites, administração) |
| `docs/superpowers/` | [Design](docs/superpowers/specs/2026-10-22-denden-design.md) e [plano](docs/superpowers/plans/2026-10-22-denden.md) |
| `docs/fase-a/`, `docs/experimentos/` | Medições, investigações e logs |
| `docs/fase-b/` | [Ponto de parada do cartão](docs/fase-b/ponto-de-parada.md) e [roteiro de implantação](docs/fase-b/implantacao.md) |

## Status

| Fase | O que é | Situação |
|---|---|---|
| A | Captura, qualidade e estabilidade em laço local | **Concluída** (testes manuais com jogo pulados; ver [resultados](docs/fase-a/resultados.md)) |
| B | Transmissão real pelo Cloudflare Realtime SFU, painel e administração | **Código pronto**; falta implantar e testar entre dois PCs |
| C | Relatório de custos medidos | Não iniciada |

Orçamento: **R$ 0**. Só cotas gratuitas; nada pago sem aprovação.

### Medido até agora (laço local, PC de 6 núcleos)

- Captura híbrida em 1080p: **mediana de 51,5 fps** numa sessão de 30 min, sem queda.
- CPU do DenDen: ~1,8 núcleo, porque o vídeo é codificado no processador (VP8, sem placa de vídeo).
- Sincronia estimada vídeo − áudio: mediana de −3 ms.
- 100 ciclos de iniciar/parar sem queda, em debug e release.

### Limitações conhecidas

- **Testado pelo SFU real do Cloudflare**, mas ainda sem medição completa entre dois PCs: jogo de verdade (impacto no fps), Discord real com alguém falando, sincronia medida com câmera.
- **Som do PC menos o Discord:** o Windows exclui só um programa; um Discord no navegador ou outro app de voz entraria.
- **Sem codificação por placa de vídeo** no `flutter_webrtc` para Windows: o vídeo pesa na CPU.
- **Cópia própria do `flutter_webrtc`** (`app/packages/flutter_webrtc`) com três correções; ao atualizar o plugin, reaplicar as mudanças descritas em [DENDEN.md](app/packages/flutter_webrtc/DENDEN.md).
- **Queda nativa sob o `flutter test`** em ~15% das execuções com WebRTC. Não acontece com o app rodando normalmente ([investigação](docs/experimentos/2026-10-23-investigacao-quedas.md)). Os testes de integração rodam uma sessão por processo; a estabilidade real é medida pelo modo de estresse.
- Sem TURN configurado, redes muito restritas podem não conectar.

## Como rodar

Requisitos: Windows, Flutter 3.47.2 (stable), Visual Studio com "Desenvolvimento para desktop com C++" e Node.js 24 (para o Worker).

**App:**

```bash
cd app
flutter pub get
flutter test
flutter run -d windows
```

**Worker (testes locais, sem conta):**

```bash
cd backend/worker
npm install
npm test
```

**Modo de estresse** (ciclos de iniciar/transmitir/parar, sem a ferramenta de testes):

```powershell
.\app\integration_test\helpers\rodar_estresse.ps1 -Build Release -Modo tela -Ciclos 10 -Saida $env:TEMP
```

**Implantar** (conta Cloudflare gratuita): siga o [roteiro](docs/fase-b/implantacao.md), começando pelo [ponto de parada do cartão](docs/fase-b/ponto-de-parada.md).

## Testes

- App: 118 testes (`flutter test`).
- Worker: 48 testes (`npm test`), com um SFU falso nas chamadas de saída.
