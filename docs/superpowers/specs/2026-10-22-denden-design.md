# DenDen — Documento de design

> App: **DenDen** · Repositório: `denden` · Data: 2026-10-22 · Situação: **aprovado pelo dono do projeto em 2026-10-22**. A implementação só começa depois da aprovação do plano. Nada é contratado ou cadastrado (nem cartão) sem aprovação explícita.

## 1. Intenção

Um grupo de ~5 amigos passa o dia numa chamada de voz do Discord. Um transmite a tela e os outros assistem: jogos, filmes, séries, animes. Às vezes chega alguém só para assistir antes de entrar no jogo.

Desde 17/08/2026 o Discord desativou vídeo e transmissão de tela no Brasil por ordem da ANPD (ECA Digital). A voz continua funcionando. O DenDen substitui **só a transmissão de tela com áudio**; a conversa continua no Discord.

Referência de experiência: o Go Live do Discord. Imagem nítida, áudio sincronizado, baixa latência e estabilidade em jogos rápidos.

### 1.1 Nome e identidade

- **Nome:** DenDen, inspirado nos Den Den Mushi de One Piece (comunicação à distância).
- **Identidade visual:** caracol estilizado com ondas de transmissão. Própria, moderna e discreta. **Não usa imagens oficiais do anime** nem copia o desenho dos Den Den Mushi.

## 2. Objetivos, não objetivos e anti-objetivos

**Objetivos**
- App Windows (Flutter) para transmitir tela + áudio do sistema e para assistir.
- Mídia passa por um **servidor de mídia externo** (SFU). Nenhum PC de participante atua como servidor ou retransmissor.
- Quem transmite envia **uma única cópia** do fluxo.
- Até **5 espectadores** simultâneos (habitual: 3).
- Salas privadas com código simples; entrar sem estar jogando.
- Painel de consumo e custo, alertas de orçamento e bloqueio por limite.
- Trocar o provedor de mídia no futuro sem reescrever o app.

**Não objetivos**
- Chat de voz ou texto (fica no Discord).
- Android, iOS, macOS, Linux, web.
- Loja de aplicativos, cadastro público, contas de usuário abertas.
- Gravação, replay, várias transmissões simultâneas na mesma sala.
- Burlar DRM: serviços como Netflix podem aparecer com tela preta na captura. O DenDen não contorna isso.

**Anti-objetivos** (seria um fracasso mesmo funcionando)
- Gerar qualquer cobrança sem aprovação explícita do grupo.
- Os amigos ouvirem a própria voz do Discord de volta na transmissão (eco).
- Segredos do provedor (chaves de API) dentro do app ou do repositório.
- Atrapalhar o jogo de quem transmite (queda perceptível de FPS).
- Criar dependência entre o DenDen e o AppMusica.

## 3. Restrições

- **Orçamento atual: R$ 0.** Só cotas gratuitas, testes locais e infraestrutura temporária gratuita.
- **Sem cartão de crédito** cadastrado em nenhum provedor nesta etapa. Se um teste exigir cartão, o trabalho para antes (ver seção 7, Fase B).
- Orçamento futuro de referência: R$ 50/mês (R$ 10 × 5). É referência, **não autorização**. Se não couber, avaliar alternativas antes de recomendar contratação.
- Contratação paga só com aprovação explícita do grupo, depois da validação funcional e com custos **medidos**.
- Repositório separado `denden` (`C:\Projetos\denden`). Do AppMusica, só **cópias** do que for reaproveitado (`flutter_webrtc`, lógica de conexão WebRTC, salas com código); o AppMusica continua funcionando de forma independente, sem dependência entre os dois.
- Todos os participantes usam Windows.

## 4. Arquitetura

```
 Transmissor (Windows)            Cloudflare                      Espectadores (Windows, até 5)
 ┌────────────────────┐  1 fluxo  ┌──────────────────┐  1 fluxo   ┌────────────────────┐
 │ App Flutter        ├──────────►│ Realtime SFU     ├───────────►│ App Flutter        │
 │ captura + codifica │  WebRTC   │ (borda mais      │  por       │ decodifica e toca  │
 └─────────┬──────────┘           │  próxima)        │  pessoa    └─────────┬──────────┘
           │ HTTPS                └──────────────────┘                      │ HTTPS
           │                      ┌──────────────────┐                      │
           └─────────────────────►│ Worker + Durable │◄─────────────────────┘
                                  │ Object (salas,   │
                                  │ consumo, limites)│
                                  └──────────────────┘
```

### 4.1 Componentes

| Componente | Responsabilidade |
|---|---|
| **App Windows** (Flutter, `flutter_webrtc` ≥ 1.6.2) | Captura tela/janela e áudio, codifica, publica no SFU; ou recebe e toca. Mostra painel de consumo e alertas. |
| **Camada `MediaProvider`** (dentro do app) | Interface pequena: `publicar(trilhas)`, `assistir(sala)`, `encerrar()`, `estatísticas()`. Única parte que conhece o provedor. |
| **Worker** (TypeScript, Cloudflare Workers) | Única peça com a chave do Realtime. Cria e fecha sessões no SFU, valida códigos e chaves do grupo, aplica limites. |
| **Durable Object** (backend SQLite) | Estado de cada sala (código, trilhas, espectadores), contadores de consumo do mês, orçamento e limites do grupo, histórico de sessões. |
| **Cloudflare Realtime SFU** | Recebe o fluxo do transmissor e repassa a cada espectador. |
| **Cloudflare TURN** | Só para quem estiver atrás de rede restritiva. Mesma franquia do SFU. |

### 4.2 Fluxo de uma transmissão

1. Transmissor clica **Transmitir**, escolhe tela ou janela e a origem do áudio.
2. App chama o Worker (`POST /salas`) com a chave do grupo. O Worker confere o orçamento: acima do limite, recusa.
3. Worker cria a sessão no SFU e devolve o código da sala.
4. App cria a conexão WebRTC com o SFU e publica vídeo + áudio **na mesma conexão e no mesmo stream** (sincronização labial pelo próprio WebRTC).
5. Transmissor cola o código no Discord.
6. Espectador digita o código. Worker valida (código + chave do grupo + limite de 5) e pede ao SFU as trilhas para esse espectador.
7. Espectador recebe e toca. A cada 10 s, cada app envia ao Worker seus números de consumo.
8. Transmissor fecha o app ou clica **Parar**: Worker fecha as trilhas no SFU, marca a sala como encerrada e grava a sessão no histórico. Espectadores veem "transmissão encerrada".
9. Se o transmissor some sem avisar (queda), o Worker encerra a sala quando parar de receber relatórios por 30 s. O SFU também descarta trilha sem pacotes por 30 s.

### 4.3 Captura no Windows

- **Vídeo:** `getDisplayMedia` do `flutter_webrtc` (suporte a Windows desde 0.9.0).
- **Áudio do sistema:** loopback do `flutter_webrtc` 1.5.0 ("loopback capture for application and desktop audio", PR #2060). **Não validado**: uma issue anterior (#1952) relatava só microfone.
- **Eco do Discord:** capturar o áudio do PC inteiro inclui a voz dos amigos no Discord. Exigência: capturar só o áudio do jogo/navegador **ou** excluir o processo do Discord (o Windows tem loopback por processo, com modo de exclusão, desde a versão 2004).
- **Plano B, se a Fase A reprovar:** plugin nativo próprio (WASAPI de loopback por processo) gerando uma trilha de áudio personalizada, ou trocar para `medea_flutter_webrtc` (anuncia captura de áudio do sistema no Windows desde 0.16.0).

### 4.3.1 Sem voz duplicada (regra do dono, 2026-10-22)

Na transmissão com os amigos, **ninguém ouve voz duas vezes**. A voz continua só no Discord.

1. **Quem transmite não toca a própria transmissão.** A prévia no PC do transmissor é só vídeo, sem som. (No laboratório da Fase A o mesmo PC transmitia e assistia; por isso o dono se ouvia duas vezes.)
2. **Captura padrão: janela.** O app abre sugerindo a janela do jogo ou do navegador; o áudio sai só daquele programa.
3. **Tela inteira sai sem áudio por padrão.** Para ligar o áudio na tela inteira, o transmissor marca uma opção com o aviso "a voz do Discord vai junto e seus amigos vão ouvir duas vezes". *(Decisão minha: entre bloquear e avisar, escolhi desligar por padrão e permitir com aviso.)*
4. Se um dia o plugin permitir excluir um processo específico (o Discord) do loopback, a tela inteira pode ganhar áudio sem a voz.

### 4.4 Qualidade

| Perfil | Resolução | Taxa | Bitrate alvo | GB/h por espectador |
|---|---|---|---|---|
| Alta | 1080p | 60 fps | ~6 Mbps | ~2,7 |
| Média | 720p | 60 fps | ~3,5 Mbps | ~1,6 |
| Economia | 720p | 30 fps | ~2 Mbps | ~0,9 |

- Em telas paradas o WebRTC pode quase parar de enviar quadros. O app mantém um mínimo de quadros, porque o SFU descarta trilhas sem pacotes por 30 s.
- Codec: preferir H.264 se houver codificação por hardware no `flutter_webrtc` Windows; senão VP8. **A confirmar na Fase A.**
- Metas: latência ponta a ponta < 1 s; dessincronia áudio/vídeo imperceptível (< ~80 ms).

### 4.5 Segurança e acesso

- **Chave do grupo:** cada amigo recebe uma chave pessoal, digitada uma vez no app e guardada localmente. O Worker guarda só o hash. Dá para revogar a chave de uma pessoa sem afetar as outras.
- **Código da sala:** curto, gerado na hora, vale só enquanto a sala existir. 5 erros seguidos bloqueiam por um tempo (mesma regra do AppMusica).
- **Administrador:** só o dono do projeto altera orçamento, limites e chaves. Isso acontece numa tela de administração dentro do app, liberada por uma **chave de administrador** separada das chaves do grupo. O Worker confere essa chave em rotas próprias (`/admin/...`).
- Chave do Realtime e do TURN só como segredo do Worker (`wrangler secret put`). Nada de segredo no repositório; `.gitignore` bloqueia `.dev.vars`, `.wrangler/`, `.env*`.
- Espectadores não veem o IP uns dos outros (tudo passa pelo SFU).
- Logs saneados (sem IP, caminhos ou e-mails).

## 5. Consumo, custos e limites

### 5.1 Quatro tipos de número, sempre rotulados

| Tipo | Fonte | Rótulo no app |
|---|---|---|
| Tráfego estimado | `getStats` do WebRTC: `bytesSent` no transmissor, `bytesReceived` em cada espectador; somados no Durable Object | "Estimado" |
| Consumo confirmado | Uso oficial do provedor | "Confirmado pelo Cloudflare" |
| Custo estimado | Tráfego estimado × tarifa configurada, descontada a franquia | "Custo estimado" |
| Custo faturado | Fatura real | "Faturado" |

**Achado:** não encontrei API oficial com consumo do Realtime por sessão. A documentação diz só que o uso aparece como um item na fatura, e avisa que os dados da GraphQL Analytics não servem como medida de uso. Na primeira versão, "confirmado" e "faturado" são digitados pelo administrador a partir do painel/fatura do Cloudflare. Se surgir uma API, ela entra no lugar.

**Duas estimativas, vale a maior:** (a) soma do que os espectadores relatam; (b) cálculo do próprio Worker: bitrate configurado × espectadores conectados × tempo. Assim um app que pare de relatar não esconde consumo.

### 5.2 Painel

Acessível durante e depois da transmissão. Atualiza a cada 10 s, fora da thread de vídeo.
- Enviado pelo transmissor ao SFU (MB/GB). Lembrete: entrada no Cloudflare não é cobrada.
- Distribuído aos espectadores (total) e por espectador.
- Duração da sessão atual e histórico de sessões.
- Custo estimado da sessão e acumulado do mês; franquia usada (x de 1.000 GB).
- Orçamento do mês: barra com os avisos configurados.

### 5.3 Alertas e limites

- Avisos configuráveis; padrão em **50%, 75%, 90% e 100%** do orçamento.
- **Projeção:** se o ritmo do mês indicar que o orçamento será ultrapassado, alerta com a estimativa e as opções: baixar para Média ou Economia, reduzir espectadores.
- Enquanto o orçamento for R$ 0, o "orçamento" é a **franquia gratuita** (padrão: 900 GB, com folga de 10% sobre os 1.000 GB).

**Bloqueio no Worker (não depende do app):**

| Nível | Novas transmissões | Sessão ativa |
|---|---|---|
| < 90% | liberadas | normal |
| 90–100% | liberadas com aviso | aviso; sugere baixar perfil |
| ≥ 100% | **recusadas** | força perfil Economia e avisa todos |
| ≥ teto (padrão 105%) | recusadas | Worker **encerra a sessão** (fecha as trilhas no SFU) após 60 s de aviso |

### 5.3.1 Painel do Worker não é teto de fatura

O bloqueio do Worker controla só o que passa pelo DenDen. Ele **não é** um limite automático e garantido de faturamento do Cloudflare. O app e o painel mostram esse aviso junto do orçamento.

### 5.4 Quanto cabe de graça (perfil Alta)

| Cenário | Tráfego/h | Horas/mês na franquia |
|---|---|---|
| 3 espectadores | ~8,1 GB | ~123 h (~4 h/dia) |
| 5 espectadores | ~13,5 GB | ~74 h |
| 3 espectadores, perfil Média | ~4,7 GB | ~212 h |

Uso de "dia inteiro" (8 h+) **não cabe** na franquia nem nos R$ 50 de referência (~180 GB extras a US$ 0,05/GB, câmbio a confirmar). Por isso a alternativa LiveKit é avaliada (seção 6).

### 5.5 Custos separados por serviço

| Serviço | Grátis | Uso previsto | Se estourar o grátis |
|---|---|---|---|
| Realtime SFU + TURN (mídia) | 1.000 GB/mês de saída, compartilhados | o grosso do consumo | US$ 0,05/GB. Exigência de cartão **não confirmada**: verificada no ponto de parada antes da Fase B (seção 7). |
| Workers | 100 mil req/dia; 10 ms de CPU por requisição | ~15 mil req em 8 h com 5 espectadores (relatório a cada 10 s) | erro 1027; requisições falham |
| Durable Objects (SQLite) | 100 mil req/dia; 100 mil linhas gravadas/dia; 5 GB | contadores acumulados em memória, gravados a cada 1 min | operações falham com erro, sem cobrança |

Estourar o grátis de Workers/DO **falha fechado**: sem Worker não se cria sessão no SFU, então não há tráfego novo.

### 5.6 Proteções obrigatórias se o grupo aprovar cartão no futuro

Só valem se o grupo aprovar o cartão. Todas são implementadas e testadas **antes** de ativar o serviço:

1. Bloqueio de novas transmissões ao atingir **900 GB** de tráfego contabilizado no mês.
2. **Alertas de cobrança no painel do Cloudflare**, por e-mail, independentes do app.
3. **Botão de emergência** na tela de administração (rota `/admin/emergencia` no Worker): encerra todas as sessões no SFU e recusa novas até ser desligado.
4. Monitoramento de consumo e custo no painel do app, com o aviso da seção 5.3.1.

## 6. Provedores de mídia comparados

| Critério | Cloudflare Realtime SFU | LiveKit no Oracle Always Free (São Paulo) | LiveKit local no PC |
|---|---|---|---|
| Uso | Produção (primeira versão) | Só se a Fase B reprovar o Cloudflare | Descartado (a Fase A usa laço local sem SFU) |
| Custo | 1.000 GB grátis, depois US$ 0,05/GB | 10 TB/mês de saída grátis na Oracle | R$ 0 |
| Manutenção | Nenhuma | Você mantém o servidor (atualizações, quedas, portas UDP) | — |
| Latência BR | Borda da Cloudflare mais próxima | Servidor em São Paulo | Rede local |
| SDK Flutter | Não há; app fala com a API via Worker usando `flutter_webrtc` | `livekit_client` (áudio de tela no Windows não confirmado) | idem |
| Riscos | Sem teto automático de gasto; sem API de uso por sessão | Oracle cortou a cota ARM para 2 OCPU / 12 GB (aplicado em 18/08/2026); capacidade às vezes indisponível; cadastro pede cartão para verificação (*meu entendimento, a confirmar*) | Viola a regra "PC não é servidor" se usado fora de teste |

Malha ponto a ponto foi descartada: viola o requisito de servidor externo e exigiria ~30 Mbps de upload com 5 espectadores.

**Decisão:** a primeira versão constrói **só o Cloudflare Realtime SFU**. O LiveKit só entra se os testes reais da Fase B mostrarem que o Cloudflare não atende ao uso esperado dentro da franquia gratuita. A camada `MediaProvider` isola o provedor para essa troca não reescrever o app.

## 7. Fases e critérios

**Fase A — R$ 0, local (PC do dono)**
1. Áudio do sistema capturado; som de jogo e de navegador chegam. **Discord não volta como eco.**
2. 1080p60 com jogo rápido aberto: medir CPU, GPU, FPS do jogo com e sem transmissão, codec obtido. **Aprovado** se o FPS do jogo cair no máximo 10%. Se reprovar, o perfil padrão passa a ser Média (720p60); codificador nativo próprio fica fora do escopo até o grupo decidir.
3. Transmitir e assistir em laço local: duas conexões `flutter_webrtc` no mesmo PC (ou dois PCs na mesma rede), sem SFU e sem conta em provedor. Valida captura, codificação, decodificação e reprodução.
4. Latência e sincronia medidas (ex.: cronômetro na tela + bipe).

> A Fase A **não comprova** que a transmissão pelo servidor externo funciona. Ela valida só captura, codificação e reprodução. A validação pelo SFU acontece na Fase B.

**Ponto de parada antes da Fase B:** verificar no painel do Cloudflare, **sem cadastrar nada**, se o Realtime SFU pode ser ativado sem cartão.
- **Ativa sem cartão:** seguir para a Fase B.
- **Exige cartão:** parar. Não cadastrar cartão nem ativar nenhum serviço que possa cobrar. Registrar o impedimento no documento de resultados e apresentar ao grupo as alternativas abaixo. Aguardar a decisão, sem tentar contornar a regra.
  - (a) Grupo aprova o cartão, com as proteções da seção 5.6 implementadas **antes** da ativação.
  - (b) LiveKit em infraestrutura gratuita **que não peça cartão**, se existir alguma na data (a Oracle provavelmente pede).
  - (c) Adiar a Fase B e manter só os testes locais.

**Fase B — R$ 0, cotas grátis, rede real, Cloudflare**
5. Teste com 3 espectadores em casas diferentes; depois com 5.
6. Estabilidade: sessão de pelo menos 1 h sem queda.
7. Painel e alertas funcionando; bloqueio a 100% testado com orçamento artificialmente baixo.
8. Comparar estimativa do app com o uso que o painel do Cloudflare mostrar.

**Fase C — Relatório para o grupo**
9. Custos com base no uso **medido**, projeção mensal, excedentes possíveis.
10. Qualquer contratação paga só com aprovação explícita do grupo.

## 8. Estrutura do repositório

```
denden/
  app/                Flutter (Windows)
    lib/capture/      tela e áudio
    lib/media/        MediaProvider + implementação Cloudflare
    lib/rooms/        criar/entrar em sala via Worker
    lib/usage/        estatísticas, painel, alertas
  backend/worker/     Worker + Durable Object (TypeScript, wrangler)
  docs/
```

**Copiado do AppMusica (cópia, sem dependência):**
- `lib/metrics/sanitize.dart` — saneamento de logs.
- Lógica de estados de conexão de `lib/jam/transport/webrtc_peer_link.dart` (conectando / conectado / desconectado / fechado), adaptada a trilhas de mídia.
- Regra de código de sala e bloqueio após 5 erros de `lib/jam/signaling/lan/lan_signaling_server.dart`, reescrita em TypeScript no Worker.

## 9. Decisões

**Do dono do projeto**
- App novo, só Windows, repositório separado, sem dependência do AppMusica.
- Voz continua no Discord; DenDen só transmite.
- Servidor de mídia externo; nenhum PC é servidor.
- Até 5 espectadores (habitual 3); Cloudflare Realtime SFU como candidato inicial, comparando alternativas gratuitas.
- Orçamento R$ 0 agora; R$ 50 só como referência; nada pago sem aprovação do grupo.
- Painel, alertas (50/75/90/100% configuráveis) e bloqueio por limite, protegendo também sessões ativas.
- Só Cloudflare na primeira versão; LiveKit só se a Fase B mostrar que o Cloudflare não atende de graça.
- Sem cartão nesta etapa. Se a Fase B exigir cartão, parar e levar alternativas ao grupo.
- Se o cartão for aprovado no futuro: as quatro proteções da seção 5.6 antes de ativar.
- Nome DenDen, repositório `denden`, identidade própria (caracol estilizado + ondas), sem imagens oficiais do anime.
- 1080p60 aprovado com queda de FPS do jogo de no máximo 10%; se falhar, avaliar 720p60 como padrão.
- Tela de administração com chave de administrador separada.

**Minhas (podem ser revistas)**
- Chave pessoal por amigo + código de sala; só o administrador mexe em orçamento.
- Proteção de sessão ativa: Economia a 100%, encerramento a 105% após 60 s de aviso.
- Relatórios a cada 10 s; DO grava a cada 1 min.
- Orçamento padrão de 900 GB enquanto for R$ 0.
- Perfis Alta/Média/Economia e bitrates da seção 4.4.
- "Confirmado" e "faturado" digitados à mão na primeira versão.
- Fase A testa em laço local (sem SFU), para não precisar de conta em provedor nem construir um segundo provedor.

## 10. Deixado para quem construir

- Detalhes da API entre app e Worker (rotas, formatos), respeitando o fluxo da seção 4.2.
- Layout das telas.
- Escolha final do codec, conforme a Fase A.
- Plano B de áudio, se a Fase A reprovar.

## Fontes

- Discord: vídeo indisponível no Brasil — https://support.discord.com/hc/en-us/articles/42704051358359
- Discord: How It All Goes Live — https://discord.com/blog/how-it-all-goes-live-an-overview-of-discords-streaming-technology
- Cloudflare Realtime SFU: preços — https://developers.cloudflare.com/realtime/sfu/pricing ; limites — https://developers.cloudflare.com/realtime/sfu/limits/ ; simulcast — https://developers.cloudflare.com/realtime/sfu/simulcast
- Cloudflare Durable Objects: preços — https://developers.cloudflare.com/durable-objects/platform/pricing/
- Cloudflare Workers: limites — https://developers.cloudflare.com/workers/platform/limits/
- Cloudflare GraphQL Analytics — https://developers.cloudflare.com/analytics/graphql-api/
- flutter_webrtc changelog — https://pub.dev/packages/flutter_webrtc/changelog ; issue #1952 — https://github.com/flutter-webrtc/flutter-webrtc/issues/1952
- medea_flutter_webrtc changelog — https://pub.dev/packages/medea_flutter_webrtc/changelog
- LiveKit: áudio de tela — https://community.livekit.io/t/is-audio-screen-capture-through-screen-sharing-possible/1269
- Oracle: preços de rede — https://www.oracle.com/cloud/networking/virtual-cloud-network/pricing/ ; corte do Always Free — https://infoq.com/news/2026/07/oracle-cloud-free-tier-limits/
