# Fase A — Resultados

> Resultados **automáticos** (medidos pelos testes no PC do dono, sem jogo aberto) e **manuais** (protocolo em [protocolo.md](protocolo.md)) ficam separados. O laço local não comprova a transmissão pelo servidor (Fase B).

## Automáticos (2026-10-22, PC do dono, versão debug)

Testes: `integration_test/capture_windows_test.dart`, `loopback_windows_test.dart`, `lab_page_windows_test.dart`. Unitários: 29/29.

| Medição | Resultado |
|---|---|
| Fontes encontradas | 1 tela + 8 a 9 janelas |
| Trilha de áudio na captura da tela | 1 (loopback do sistema funcionando) |
| Áudio chegou no lado receptor | Sim (≈ 44 KB em 10 s) |
| Codecs oferecidos | VP8, VP9, H264, AV1, H265 |
| Codificador usado | `libvpx` (VP8, **software**) |
| Codificação por hardware | **Não disponível.** H264 = `OpenH264` (software); H265 por hardware (WMF) anunciado, mas não aceito |
| Teto de bitrate sem correção | 2,5 Mbps (tabela padrão do libwebrtc) |
| Teto com `x-google-max-bitrate` | 5,4–5,75 Mbps de alvo no Alta |
| Alta (1080p60), tela com pouco movimento | 1920×1080 a 31–49 fps, 2,4–3,6 Mbps |
| Alta, 60 s com tela mudando (diagnóstico) | caiu para 6–20 fps, motivo `cpu` |
| Média (720p60) | **Defeito:** às vezes envia 1080p (escala ignorada) |
| Jitter | 1–20 ms |

**Leitura:** a captura de tela e de áudio funciona. O gargalo de 1080p60 é o **processador**, porque não há codificação por hardware nesta versão do `flutter_webrtc`. O teste com jogo (A4) decide se a queda de FPS cabe nos 10%.

## Manuais (preencher)

| # | Teste | Resultado | Aprovado? | Observações |
|---|---|---|---|---|
| A0 | CSV abre no Excel pt-BR (colunas e vírgula decimal) | | | Caminho: |
| A1 | Áudio do navegador (janela / tela) | | | |
| A2 | Áudio do jogo (janela) | | | |
| A3 | Eco do Discord: janela | | | |
| A3 | Eco do Discord: tela inteira | | | |
| A4 | FPS sem DenDen / com Alta | ___ / ___ fps (queda ___%) | | Resolução e fps enviados: |
| A5 | FPS com Média (se A4 reprovar) | ___ fps (queda ___%) | | Resolução enviada: |
| A6 | Codec, codificador, CPU | | — | |
| A7 | Latência (3 fotos) | ___ / ___ / ___ ms | | |
| A8 | Sincronia | | | |
| A9 | 30 min de jogo | | | CSV: |
| A10 | Tela parada 2 min | | | |

Jogo usado: ______ · Resolução do monitor: ______ · Processador / placa de vídeo: ______

## Decisões (preencher depois dos manuais)

- Perfil padrão: ______
- Modo de captura recomendado contra eco: ______
- Plano B de áudio necessário? ______
