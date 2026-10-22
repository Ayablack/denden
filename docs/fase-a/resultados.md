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

## Manuais

**Decisão do dono (2026-10-22):** só o A0 (CSV no Excel) foi feito: **aprovado**, abre em colunas com vírgula decimal. Os demais (A1–A10) foram **pulados**: no laço local o mesmo PC transmite e assiste, então o dono se ouvia duas vezes e não dava para avaliar. O dono considerou satisfatórios os testes automáticos e preferiu ajustar quando o app estiver funcionando de verdade.

**CSVs do dono (pasta `csv/`, 2026-10-22 16:09–16:16, versão release):**
- **Janela capturada (1928×1043) em Alta: 11–17 fps**, mesmo com Limitação `none`. A captura de janela do plugin usa GDI (lenta); a de tela usa DirectX e deu 31–49 fps nos testes automáticos. **Conflito:** a janela é o modo recomendado contra eco, mas é lenta demais para jogo.
- **Início borrado:** ~25 s em 480×270 a 960×540 (`bandwidth`) até o estimador de banda subir.
- No fim do CSV mais longo apareceu Limitação `cpu`.
- Áudio enviado: ~4 KB/s (bytes sobem o tempo todo); nível quase sempre perto de 0 (fonte pouco barulhenta ou escala baixa; não conclusivo).
- Jitter de até 80 ms.

**O que continua sem medição (risco aberto para a Fase B):**
- Queda de FPS do jogo com transmissão (critério ≤ 10%). Medir no B2.
- Eco do Discord na prática (o código diz: janela isola, tela inteira não).
- Latência, sincronia e estabilidade de 30 min.
- Perfil Média com 720p real.


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

- **Perfil padrão: provisório Alta (1080p60).** Não aprovado: falta medir a queda de FPS. Se o B2 mostrar queda > 10%, revisar.
- **Modo de captura recomendado contra eco:** janela do jogo ou do navegador (o áudio sai só daquele programa).
- **Plano B de áudio necessário?** Não por enquanto: a captura de áudio funcionou nos testes automáticos.
- **Nova regra do dono:** ninguém pode ouvir voz duplicada durante a transmissão. Ver seção 4.3.1 do design.
