# Fase A — Protocolo de testes manuais

> Tudo roda no seu PC, sem servidor e sem conta em nenhum serviço. Custo: R$ 0.
> O laço local **não comprova** a transmissão pela internet; isso é da Fase B.

Tempo total estimado: **~1 h 30 min**.

## Antes de começar (10 min)

0. **Teste do CSV (5 min), antes de tudo:**
   1. Abra o DenDen, clique **Iniciar**, espere 10 s, clique **Parar** e depois **Exportar CSV**.
   2. Uma mensagem embaixo mostra o caminho do arquivo. No seu PC deve ser `C:\Users\usuario\Documents\denden-lab-<data>.csv`. Essa **não** é a pasta Documentos do OneDrive.
   3. Dê dois cliques no arquivo. **Aprovado se** o Excel abre com uma coluna por medida (tempo_s, estado, largura…) e números com vírgula (ex.: `5,60`).
   4. Se falhar, pare e me avise antes dos outros testes.

1. Abra um terminal na pasta `C:\Projetos\denden\app`.
2. Gere a versão de produção (mais fiel para medir CPU e FPS):
   ```bash
   flutter build windows --release
   ```
3. Abra o app: `C:\Projetos\denden\app\build\windows\x64\runner\Release\denden.exe`.
4. Ative o contador de FPS do jogo. Opções: o contador do próprio jogo, o do Steam (Configurações → Durante o jogo → Contador de FPS) ou a Xbox Game Bar (`Win + G` → Desempenho).
5. Abra o Gerenciador de Tarefas na aba Desempenho para ver CPU e GPU.

### Como o laboratório funciona

- **Fonte:** escolha a tela ou uma janela. O aviso embaixo diz qual áudio vai junto.
  - **Janela:** só o som daquele programa.
  - **Tela inteira:** o som do PC todo, **incluindo a voz do Discord**.
- **Perfil:** Alta (1080p60), Média (720p60) ou Economia (720p30).
- **Iniciar / Parar.** À direita aparece o que "chegou" do outro lado.
- **Exportar CSV:** salva as medições em `C:\Users\usuario\Documents\denden-lab-<data>.csv` (o caminho aparece na tela). O arquivo abre direto no Excel em português.
- O painel mostra resolução, fps enviado e recebido, codec, **Limitação** (`none`, `cpu` ou `bandwidth`), bitrate, jitter e **Áudio recebido** (KB e nível de 0 a 1).
- **Mostrar vídeo recebido:** desligue nos testes de FPS. Mostrar o vídeo também gasta o PC.

Durante o laço local, o som recebido também toca no seu PC. Você vai ouvir o som original e o recebido ao mesmo tempo, com um pequeno atraso. Isso é esperado.

## Testes

Anote cada resultado em [resultados.md](resultados.md).

### A1 — Áudio do navegador (5 min)
1. Toque um vídeo com som no navegador.
2. Fonte: **janela do navegador**. Perfil: Alta. Iniciar.
3. Clique em **Parar** e depois em Iniciar com a fonte **Tela inteira**.
- **Aprovado se:** nos dois casos o **nível** em "Áudio recebido" sobe (acima de 0,05) enquanto o vídeo toca e volta para perto de 0 quando você pausa.

### A2 — Áudio do jogo (5 min)
1. Abra o jogo em **modo janela ou janela sem bordas**.
2. Fonte: **janela do jogo**. Iniciar.
- **Aprovado se:** o **nível** em "Áudio recebido" sobe com o som do jogo.

### A3 — Eco do Discord (10 min)
Precisa de um amigo falando na chamada do Discord.
1. Fonte: **janela do jogo**. Iniciar. Peça para o amigo falar.
2. Parar. Fonte: **Tela inteira**. Iniciar. Peça para o amigo falar de novo.
- **Esperado pelo código:** com a janela, a voz do Discord **não** entra; com a tela inteira, entra.
- **Aprovado se:** em pelo menos um modo a voz do Discord não entra. Anote qual.
- Como perceber: com a voz entrando, você ouve o amigo duas vezes (o original e o eco atrasado).

### A4 — FPS do jogo em Alta (15 min)
1. Feche o DenDen. Jogue **2 min na mesma cena** e anote o FPS médio.
2. Abra o DenDen. Fonte: **janela do jogo**. Perfil: **Alta**. **Desmarque "Mostrar vídeo recebido".** Iniciar.
3. Jogue os **mesmos 2 min na mesma cena**. Anote o FPS médio, a CPU e o que o painel mostra (resolução **Enviado**, fps enviado, Limitação).
4. Exportar CSV.
- **Resolução precisa bater:** em Alta, "Enviado" deve ser 1920×1080 (ou o tamanho da janela do jogo, se for menor). Se aparecer menor que isso **com Limitação `none`**, o teste não vale: me avise.
- **Leitura pessimista:** no laço local o mesmo PC também decodifica o vídeo recebido. Um transmissor de verdade gasta um pouco menos. Se o A4 passar aqui, passa na vida real.
- **Conta:** queda = (FPS sem − FPS com) ÷ FPS sem × 100.
- **Aprovado se:** queda ≤ **10%**.

### A5 — FPS do jogo em Média (15 min, só se A4 reprovar)
Repita o A4 com o perfil **Média**.
- **Atenção, defeito conhecido:** o perfil Média às vezes continua enviando 1080p (veja o painel "Enviado"). Anote a resolução que aparecer.
- **Aprovado se:** queda ≤ 10%.

### A6 — Codec e CPU (junto com A4)
- Anote o codec e o codificador do painel (esperado: `video/VP8 (libvpx)`) e a CPU no Gerenciador de Tarefas. Sem critério: é só registro.

### A7 — Latência (5 min)
1. Fonte: **Tela inteira**. Perfil: Alta. Iniciar.
2. O cronômetro grande à esquerda também aparece dentro do vídeo recebido, à direita.
3. Tire **3 fotos** com o celular mostrando os dois cronômetros ao mesmo tempo.
- **Conta:** latência = cronômetro da esquerda − cronômetro dentro do vídeo.
- **Aprovado se:** a média for < **1 s**.

### A8 — Sincronia de áudio e vídeo (10 min)
1. No YouTube, procure "audio video sync test" e abra um vídeo com bipe e flash ao mesmo tempo.
2. Opcional, para ouvir só o som recebido: em Configurações → Sistema → Som → **Mixer de volume**, mude a **saída do navegador** para outro dispositivo (por exemplo, o alto-falante do monitor desligado).
3. Fonte: **janela do navegador**. Iniciar.
4. Olhe o vídeo recebido no DenDen e ouça o bipe.
- **Aprovado se:** o bipe e o flash do vídeo **recebido** parecem simultâneos (atraso imperceptível, < ~80 ms). Se tiver dúvida, filme em câmera lenta.

### A9 — Estabilidade (30 min)
1. Fonte: **janela do jogo**. Perfil: o que passou no A4/A5. Iniciar.
2. Jogue normalmente por **30 min**.
3. Exportar CSV.
- **Aprovado se:** o app não fecha sozinho, o vídeo não trava e o estado fica `connected` o tempo todo.

### A10 — Tela parada (5 min)
1. Fonte: janela do navegador com um vídeo **pausado** por 2 min.
2. Observe "Recebido: fps" e o Estado.
3. Exportar CSV no fim.
- **Aprovado se:** no CSV, a coluna `fps_recebido` nunca fica em 0 por mais de 5 s seguidos (mais de 2 linhas seguidas com 0), e o vídeo volta a se mexer assim que você der play.
- Isso decide se o DenDen precisa forçar quadros mínimos em tela parada, porque o servidor da Fase B descarta vídeo parado por 30 s.

## Depois dos testes

1. Preencha [resultados.md](resultados.md).
2. Junte os CSVs exportados na pasta `C:\Projetos\denden\docs\fase-a\csv\`.
3. Me avise. Eu leio os números e recomendo o perfil padrão.
