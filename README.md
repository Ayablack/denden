# DenDen

> **Projeto experimental, em Fase A (validação local).** Ainda não existe aplicativo utilizável.

Transmissão privada de tela e áudio entre amigos, no Windows. A conversa de voz continua no Discord; o DenDen só transmite a imagem e o som. Até 5 espectadores, normalmente 3.

Detalhes: [documento de design](docs/superpowers/specs/2026-10-22-denden-design.md) e [plano](docs/superpowers/plans/2026-10-22-denden.md).

## Status

| Fase | O que é | Situação |
|---|---|---|
| A | Captura, qualidade e FPS em laço local (sem servidor) | **Em andamento** |
| B | Transmissão real pelo Cloudflare Realtime SFU (cotas grátis) | Não iniciada; depende do ponto de parada do cartão |
| C | Relatório de custos medidos para o grupo | Não iniciada |

Orçamento atual: **R$ 0**. Nenhum serviço pago é contratado sem aprovação do grupo.

## Como rodar

Requisitos: Flutter 3.47.2 (stable) e Visual Studio com "Desenvolvimento para desktop com C++".

```bash
cd app
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```
