# flutter_webrtc — cópia do DenDen

Cópia do [flutter_webrtc](https://github.com/cloudwebrtc/flutter-webrtc) **1.6.2+hotfix.4** (licença MIT, ver `LICENSE`), só com o necessário para o Windows: `lib`, `common/cpp`, `windows` e o `third_party` que baixa o libwebrtc na primeira compilação (~30 MB, fora do Git).

Para atualizar o plugin: copiar a versão nova por cima e reaplicar as mudanças abaixo (todas marcadas com `DenDen` no código).

## Mudanças

### 1. Os parâmetros de envio não eram aplicados (`common/cpp/src/flutter_peerconnection.cc`)

`updateRtpParameters` alterava as **cópias** devolvidas por `encodings()` e nunca chamava `set_encodings()`. O `set_parameters` respondia "ok" e nada mudava: `scaleResolutionDownBy`, `maxBitrate` e `maxFramerate` eram ignorados.

Medido em 2026-10-23 (monitor 2560×1440, perfil Alta, pelo SFU do Cloudflare):

| | Antes | Depois |
|---|---|---|
| Resolução enviada | 2560×1440 | 1920×1080 |
| Codificar um quadro | 11,1 ms | 6,9 ms |
| Parâmetros lidos de volta | escala 1.0, teto 0, fps 0 | escala 1.33, teto 6 Mbps, fps 60 |

### 2. Som do PC sem um processo (`windows/application_loopback_capturer.*`, `windows/loopback_capturer_factory.cc`, `common/cpp/include/loopback_capturer.h`, `common/cpp/src/flutter_screen_capture.cc`)

`getDisplayMedia` da **tela** aceita `audio: {'excludeProcessId': pid}`: captura o som do PC todo **menos a árvore desse processo** (`PROCESS_LOOPBACK_MODE_EXCLUDE_TARGET_PROCESS_TREE`). O DenDen usa isso para tirar o Discord (`lib/capture/pc_sem_discord.dart`). Sem o parâmetro, o comportamento é o original (exclui só o próprio app).

Medido em 2026-10-23 com um processo tocando um tom contínuo: energia do som enviado **0** com o processo excluído, contra **2,1e-3** sem excluir.

Limite do Windows: só **uma** árvore por captura.

### 3. Vídeo do SFU em branco (`common/cpp/src/flutter_video_renderer.cc`)

O renderizador procurava o stream remoto numa lista que só o `OnAddStream` preenche. Com o SFU do Cloudflare ele não era achado: quem assistia **ouvia o som, mas a imagem ficava em branco**. Agora, se o stream não é achado e veio o `trackId`, o vídeo é ligado direto pela trilha remota (guardada no `OnTrack`). O app passa o `trackId` em `Viewing._onTrack` (`lib/media/cloudflare_media.dart`).

Medido em 2026-10-23: antes, área do vídeo em branco com 41 fps sendo decodificados; depois, a imagem aparece.
