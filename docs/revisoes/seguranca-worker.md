# Revisão de segurança do Worker (`backend/worker/src`)

Data: 26/10/2026. Base: `main` em `073d7a6`.

Revisão só de leitura: nenhum código foi alterado. Os números de linha são do `main` nesse commit.

## Resumo

Não achei nada grave, como uma chave vazando ou uma chave de amigo virando administrador. Os segredos do Realtime não aparecem em erros nem em logs. As rotas `/admin/*` exigem a chave de administrador, e uma chave de amigo não serve no lugar dela.

O ponto fraco está em outro lugar. **Qualquer amigo com chave válida consegue atrapalhar o grupo inteiro**: ele vê os dados do painel de administração, se passa por outro espectador e consegue travar as transmissões do mês. Para um grupo de 5 amigos de confiança, o risco é pequeno. Mesmo assim, uma chave vazada ou um amigo que saiu do grupo bastariam para isso.

Também falta limitar o tamanho dos pedidos, e pedidos com chave falsa ainda gastam a cota gratuita.

| # | Achado | Gravidade |
|---|--------|-----------|
| 1 | Amigo vê o painel de administração em `/consumo` | Média |
| 2 | Espectador não fica ligado à chave de quem entrou | Média |
| 3 | Relatório de bytes sem teto trava o mês inteiro | Média |
| 4 | Chave falsa chega ao Durable Object e gera credenciais TURN | Média |
| 5 | Corpo dos pedidos sem limite de tamanho | Média (depende do SFU) |
| 6 | `GET /salas/:codigo` não confere a chave nem limita tentativas | Baixa |
| 7 | Hash do administrador comparado com `!==` | Baixa |
| 8 | Limite de tentativas só na memória e só em `entrar` | Baixa |
| 9 | Revogar uma chave não derruba quem já está numa sala | Baixa |
| 10 | `revogar` aceita `__proto__` e afins como identificador | Informativo |
| 11 | Rotas de administração não conferem o método HTTP | Informativo |
| 12 | O Durable Object executa qualquer método pelo nome | Informativo |

Gravidades: **Alta** permite tomar o controle ou vazar segredos; **Média** permite a um amigo, ou a quem tiver uma chave vazada, atrapalhar o grupo; **Baixa** tem impacto pequeno ou exige condições difíceis; **Informativo** é uma melhoria de defesa, sem risco atual.

---

## O que está certo

- **Segredos fora das respostas e dos logs.** Não existe nenhum `console.log` em `src/`. `RealtimeError` monta a mensagem só com status, código e descrição da resposta, sem a URL (que contém o App ID) e sem o token (`realtime.ts:5-15`). Mesmo essa mensagem não chega ao cliente: `Group.provider` troca por "O servidor de mídia não respondeu." (`group.ts:184-193`), e qualquer outro erro vira "Erro interno do DenDen." (`index.ts:141-144`).
- **Chave de amigo não abre `/admin/*`.** A chave de administrador vem num cabeçalho próprio (`X-DenDen-Admin`) e é conferida contra `ADMIN_KEY_HASH` antes de qualquer rota de administração (`index.ts:55-59`). As chaves de amigo nunca são consultadas nesse caminho.
- **Falha fechada.** Se `ADMIN_KEY_HASH` não estiver configurado, a comparação nunca dá certo e tudo em `/admin` responde 403.
- **Chaves fortes, guardadas só como hash.** As chaves têm 32 bytes aleatórios (`keys.ts:13-19`, `scripts/gerar-chave-admin.mjs`), então adivinhar uma é inviável. Por isso não faz falta limitar tentativas de chave nem usar um hash lento.
- **Encerrar a sala e relatar como transmissor** exigem a chave de quem criou a sala (`group.ts:329-332`, `group.ts:373-375`).

---

## Achados

### 1. Amigo vê o painel de administração em `/consumo` — Média

**Onde:** `index.ts:92`, `group.ts:463-467`, `group.ts:483-518`.

`usage()` devolve o mesmo `panel()` da administração. Com isso, qualquer chave de amigo vê:

- o código de **todas** as salas ao vivo;
- o `id` de cada espectador (`viewers[].id`);
- o histórico das últimas 50 salas;
- a configuração de limites.

Sozinho, isso só expõe informação. Junto com o achado 2, permite atrapalhar a sala dos outros. Também faz dos códigos de sala um "segredo" que todo amigo já conhece.

**Correção sugerida:** criar um painel resumido para amigos, com mês, percentual, nível, avisos e aviso de faturamento, e sem `rooms`, `history` nem `viewers`. Manter o painel completo só em `/admin/consumo`.

### 2. Espectador não fica ligado à chave de quem entrou — Média

**Onde:** tipo `Viewer` em `group.ts:65-70`; `answer` em `group.ts:299-313`; `report` como espectador em `group.ts:338-348`.

O `Viewer` não guarda o hash da chave de quem entrou. `answer` e `report` só confirmam que a chave é válida e que o `viewerId` existe. Então qualquer amigo que saiba o código e o `viewerId` de outro (o achado 1 entrega os dois) consegue:

- mandar uma resposta SDP qualquer para a sessão do outro no SFU (`renegotiate`) e derrubar a imagem dele;
- relatar bytes em nome dele e mexer no consumo do mês (ver o achado 3).

**Correção sugerida:** guardar `keyHash` no `Viewer` ao entrar (`group.ts:294`) e, em `answer` e `report`, recusar com 403 quando o hash da chave for diferente, como já se faz com `publisherHash`.

### 3. Relatório de bytes sem teto trava o mês inteiro — Média

**Onde:** validação em `index.ts:133`; soma em `group.ts:342-347`; nível em `usage.ts:55-61`.

A única regra para `bytes` é `typeof b.bytes === "number" && b.bytes >= 0`. Um relatório com `bytes: 1e300` faz `reportedEgressBytes` explodir. O consumo efetivo usa o **maior** valor (`usage.ts:45-47`), então o mês passa direto para `ceiling`: a sala atual é encerrada e novas transmissões ficam bloqueadas até o mês virar.

Não existe rota de administração para zerar o consumo relatado. Hoje, a única saída seria subir muito `budgetGb` em `/admin/config`, o que também desliga a proteção de verdade.

Além disso, quando o contador cumulativo diminui, tudo conta de novo (`group.ts:342-343`). Alternar entre um valor alto e um baixo soma o valor alto a cada relatório.

**Correção sugerida:**
- recusar `bytes` que não seja inteiro seguro (`Number.isSafeInteger`);
- recusar um aumento maior do que o possível no intervalo, por exemplo `PROFILE_BPS[perfil] / 8 × segundos desde o último relatório × 2` de folga;
- depois de um "zerar", contar no máximo o valor possível no intervalo;
- criar uma rota de administração para corrigir o consumo relatado de um mês.

### 4. Chave falsa chega ao Durable Object e gera credenciais TURN — Média

**Onde:** `index.ts:90`; `index.ts:94-96`; `index.ts:108-110`; `index.ts:117`.

O Worker só confere se o cabeçalho `X-DenDen-Key` **não está vazio**. A validação de verdade acontece dentro do Durable Object. Com isso:

- qualquer pessoa na internet, com `X-DenDen-Key: x`, faz cada pedido chegar ao Durable Object (leitura do estado e hash);
- em `/ice`, `POST /salas` e `POST /salas/:codigo/entrar`, o `await iceServers(...)` roda **antes** de `run(...)`, porque é argumento da chamada. Ou seja, uma credencial TURN é gerada na API do Cloudflare antes de a chave ser conferida. A credencial não volta para quem pediu, mas a chamada já foi feita.

No plano Free, isso não gera cobrança: passado o limite diário, o Cloudflare só recusa os pedidos. O risco real é alguém esgotar a cota gratuita de pedidos e deixar o grupo sem DenDen até o dia seguinte, ou provocar limite de taxa na API de TURN.

**Correção sugerida:**
- gerar o ICE só depois de `run` dar certo (chamar `run` primeiro e, se `ok`, acrescentar `iceServers`);
- recusar logo no Worker chaves com formato errado (a chave tem 43 caracteres base64url: `/^[A-Za-z0-9_-]{43}$/`), sem chamar o Durable Object;
- opcional: uma regra de limite de taxa (Rate Limiting) do Cloudflare para o Worker, se houver uma opção gratuita na conta.

### 5. Corpo dos pedidos sem limite de tamanho — Média (depende do SFU)

**Onde:** `body()` em `index.ts:25-32`; `isTracks` em `index.ts:34-37`; trilhas gravadas em `group.ts:248`; estado inteiro numa chave só em `group.ts:148-150`.

`req.json()` lê o corpo todo, sem limite. O Cloudflare aceita corpos de até 100 MB no plano Free, e o Worker tem 128 MB de memória. Um corpo enorme derruba o pedido com erro 500. Isso é ruim, mas não passa daí.

O risco maior está em `tracks`. `isTracks` só confere `mid` e `trackName`: aceita lista de qualquer tamanho, textos de qualquer tamanho e campos extras. Esses objetos vão para o SFU e, se ele aceitar, são gravados **inteiros** na sala. Todo o estado do grupo fica numa única chave (`"state"`). Se ela passar do limite de tamanho de um valor no armazenamento do Durable Object, **todas** as gravações falham, inclusive a do `tick`, que é quem limparia as salas antigas. O grupo ficaria travado até alguém mexer no armazenamento.

Isso depende de o SFU aceitar trilhas grandes ou com campos extras, o que não testei. Mesma situação para `name` em `addKey`, que é gravado sem limite, mas só o administrador chega lá.

**Correção sugerida:**
- em `body()`, recusar com 413 quando `Content-Length` passar de, por exemplo, 64 KB. Ler com `req.text()` e conferir o tamanho também, porque o cabeçalho pode faltar;
- em `isTracks`, limitar a quantidade (por exemplo, até 4 trilhas) e o tamanho de `mid` e `trackName` (por exemplo, 64 caracteres);
- gravar só `{ mid, trackName }`, sem os campos extras (`group.ts:248`);
- limitar `offerSdp`/`answerSdp` (por exemplo, 32 KB) e `name` (por exemplo, 40 caracteres).

### 6. `GET /salas/:codigo` não confere a chave nem limita tentativas — Baixa

**Onde:** `index.ts:112`; `group.ts:380-389`.

`roomState` não recebe a chave: basta um cabeçalho não vazio. Também não passa pelo limite de tentativas. Assim, qualquer pessoa sem chave pode perguntar se um código existe e quantos espectadores a sala tem.

Na prática, adivinhar é difícil. São 31⁶ ≈ 887 milhões de códigos (`codes.ts:2-9`), e com poucas salas ao vivo seriam centenas de milhões de pedidos, muito acima dos ~100 mil por dia do plano Free. Mesmo acertando, para entrar é preciso uma chave válida.

O viés de `b % 31` (`codes.ts:7`) é desprezível.

**Correção sugerida:** passar a chave para `roomState` e chamar `keyHash` como nas outras rotas. Opcionalmente, registrar as falhas no mesmo `BadCodeLimiter`.

### 7. Hash do administrador comparado com `!==` — Baixa

**Onde:** `index.ts:57`; `group.ts:161-164` (`isAdmin`, que hoje não é usado em lugar nenhum).

A comparação não é em tempo constante. Como ela compara o **hash** SHA-256 da chave enviada, e não a chave, medir o tempo revela no máximo os primeiros caracteres de hashes que o atacante não consegue escolher. Isso não ajuda a descobrir a chave. Não há o que explorar na prática, mas é fácil deixar no padrão.

As chaves de amigo são procuradas pelo hash num objeto (`group.ts:152-159`). Essa busca não compara segredos caractere por caractere, então está ok.

`keys.ts` não tem uma função de comparação em tempo constante.

**Correção sugerida:** criar em `keys.ts` uma função `sameHash(a, b)` que converte os dois hashes hex em bytes e usa `crypto.subtle.timingSafeEqual` (existe no runtime dos Workers), devolvendo `false` quando os tamanhos forem diferentes. Usar em `index.ts:57` e remover `isAdmin` (ou fazer `index.ts` usá-lo).

### 8. Limite de tentativas só na memória e só em `entrar` — Baixa

**Onde:** `group.ts:133`; `group.ts:268-278`; `codes.ts:25-56`.

O `BadCodeLimiter` (5 erros por minuto bloqueiam 1 minuto) existe e funciona em `joinRoom`, por chave + IP. Mas:

- fica só na memória do Durable Object: recomeça do zero toda vez que o objeto é descarregado;
- vale só para `entrar`. `roomState`, `resposta`, `relatorio` e `encerrar` não contam erros;
- o mapa `attempts` nunca é limpo para quem não volta, então cresce com IPs diferentes (só para quem tem chave válida).

Como a entrada já exige chave válida e os códigos já aparecem para amigos em `/consumo` (achado 1), o efeito é pequeno.

**Correção sugerida:** limpar entradas vencidas em `register` ou numa passada do `tick`; se o achado 1 for corrigido, aplicar o limite também nas rotas que recebem código. Gravar no armazenamento só se for preciso que o bloqueio sobreviva a reinícios.

### 9. Revogar uma chave não derruba quem já está numa sala — Baixa

**Onde:** `group.ts:212-216`.

`revokeKey` só marca `revoked`. Uma sala transmitida por essa chave continua no ar até o próximo relatório do transmissor, que aí falha, e a sala cai por `queda` em cerca de 30 s. Um espectador com a chave revogada, porém, continua recebendo vídeo pelo SFU até a sala acabar, porque o `tick` não confere chaves. Com o achado 2 corrigido, dá para fazer isso.

**Correção sugerida:** ao revogar, encerrar as salas com `publisherHash` igual ao hash revogado e remover os espectadores com esse `keyHash`, fechando as trilhas deles no SFU.

### 10. `revogar` aceita `__proto__` e afins como identificador — Informativo

**Onde:** `index.ts:70`; `group.ts:214`.

`s.keys[hash]` sem `Object.hasOwn`. `POST /admin/chaves/__proto__/revogar` grava `revoked = true` em `Object.prototype` dentro do Durable Object. Hoje isso não muda nenhum resultado (as chaves reais têm `revoked` próprio), e só o administrador chega lá.

**Correção sugerida:** `if (Object.hasOwn(s.keys, hash))` e, no `index.ts`, aceitar só hash com 64 caracteres hex.

### 11. Rotas de administração não conferem o método HTTP — Informativo

**Onde:** `index.ts:66-86`.

Só os dois `GET` conferem o método. `GET /admin/config`, por exemplo, chama `setConfig({})` e grava o estado. Não muda nada hoje, mas fica fácil errar no futuro.

**Correção sugerida:** exigir `POST` nas rotas que gravam e responder 405 nos outros métodos.

### 12. O Durable Object executa qualquer método pelo nome — Informativo

**Onde:** `state.ts:32-35`.

`call(op, args)` executa qualquer método de `Group`, inclusive os privados (`load`, `save`, `end`, `keyHash`). Hoje só o `index.ts` chama, com nomes fixos no código, então não há como explorar. Mas, se algum dia `op` vier do pedido, seria uma porta aberta.

**Correção sugerida:** uma lista fixa das operações permitidas (`addKey`, `listKeys`, `createRoom`, …) e recusar o resto.

---

## Ordem sugerida para corrigir

1. Achados 4 e 5: só mexem em `index.ts`, são simples e protegem a cota gratuita.
2. Achados 1, 2 e 3 juntos: decidir o que o painel do amigo mostra, ligar o espectador à chave e limitar os bytes.
3. O resto, quando der.

Cada correção deve vir com teste em `backend/worker/test/` (por exemplo: chave de outro amigo recusada em `resposta`; `bytes: 1e300` recusado; corpo de 1 MB recebe 413).
