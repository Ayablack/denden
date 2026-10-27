# Design do DenDen

- [prompt-stitch.md](prompt-stitch.md): o prompt usado no Google Stitch, com a lista do que o app tem e do que não deve aparecer.
- [stitch/](stitch/): o que o Stitch gerou, como referência visual.
  - `*/screen.png`: uma imagem por tela.
  - `denden_desktop_stream_engine/DESIGN.md`: cores, tipografia, cantos e componentes. É a base de `app/lib/ui/tema.dart`.
  - `denden_stream_studio/DESIGN.md`: a segunda direção visual que o Stitch propôs, guardada só para comparação.
- O ícone do app está em `app/assets/icone/denden.svg`. O `app/windows/runner/resources/app_icon.ico` foi gerado dele em 7 tamanhos, de 16 a 256 px.

As telas do Stitch são **referência**, não especificação. Onde elas mostram algo que o DenDen não faz (lista de amigos, chat, telemetria, "baixa latência"), vale o app.
