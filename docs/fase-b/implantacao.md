# Fase B — Implantação gratuita e primeiro teste real

> Quem faz: **o dono do projeto**. Todo passo que mexe na conta Cloudflare é seu. Os comandos já estão prontos.
> Regra: **R$ 0**. Se qualquer tela pedir cartão, plano pago ou "upgrade": **pare** e me avise (veja [ponto-de-parada.md](ponto-de-parada.md)).

Tempo estimado: **~45 min**, sendo 30 de configuração e 15 do teste com um amigo.

Use o PowerShell, dentro de `C:\Projetos\denden\backend\worker`.

## 1. Ponto de parada do cartão (10 min)

Siga [ponto-de-parada.md](ponto-de-parada.md). Só continue se o app do **Realtime → Serverless SFU** for criado **sem cartão**. Anote o **App ID**. O **App Secret** você vai colar direto no comando do passo 4, sem salvar em lugar nenhum.

## 2. Entrar no Cloudflare pelo terminal (2 min)

```bash
npx wrangler login
```

Abre o navegador: confirme com a sua conta Cloudflare. Isso dá permissão ao `wrangler` (a ferramenta oficial) só na sua máquina.

## 3. Gerar a chave de administrador (1 min)

```bash
npm run gerar-chave-admin
```

- A **chave** aparece na tela: guarde no seu gerenciador de senhas. Ela não sai do seu PC.
- O **hash** vai para o próximo passo.

## 4. Colocar os segredos no Worker (3 min)

Cada comando pede o valor; cole e aperte Enter. O valor não aparece na tela nem fica em arquivo.

```bash
npx wrangler secret put REALTIME_APP_ID
```

```bash
npx wrangler secret put REALTIME_APP_TOKEN
```

```bash
npx wrangler secret put ADMIN_KEY_HASH
```

- `REALTIME_APP_ID`: o App ID do passo 1.
- `REALTIME_APP_TOKEN`: o App Secret do passo 1.
- `ADMIN_KEY_HASH`: o **hash** do passo 3 (não a chave).

TURN é opcional e fica para depois. Sem TURN, quem estiver numa rede muito fechada pode não conseguir conectar.

## 5. Publicar o Worker (2 min)

> **Já publicou antes?** Toda mudança no Worker só vale depois de publicar de novo com o mesmo comando abaixo. O estado salvo (chaves, consumo do mês) continua.

```bash
npx wrangler deploy
```

No fim aparece o endereço, algo como `https://denden-worker.<seu-nome>.workers.dev`. Anote.

- **Se pedir para escolher plano pago ou cadastrar cartão:** pare e me avise.
- O Worker usa só recursos do plano **Free**: Workers, um Durable Object com SQLite e o Realtime.

## 6. Configurar o DenDen no seu PC e criar as chaves (5 min)

1. Crie a **sua** chave pessoal pelo terminal (a chave de administrador não serve para transmitir):

   ```powershell
   $env:DENDEN_ADMIN = Read-Host "Chave de administrador"
   ```

   ```bash
   npm run criar-chave -- https://denden-worker.SEU-NOME.workers.dev "Seu nome"
   ```

2. Abra `C:\Projetos\denden\app\build\windows\x64\runner\Release\denden.exe`.
3. Na tela **Configurar**, preencha:
   - **Endereço do servidor:** o endereço do passo 5;
   - **Sua chave:** a chave do item 1;
   - **Chave de administrador:** a do passo 3.
4. Clique **Salvar**. O DenDen testa a chave no Worker antes de salvar.
5. No menu, abra **Administração**:
   - **Chaves dos amigos:** digite o nome e clique **Criar chave**. A chave aparece **uma vez**: copie e mande por mensagem privada só para a pessoa.
   - **Limites:** confira orçamento **900 GB**, avisos **50, 75, 90, 100**, teto **105%**. Salve se mudar algo.
   - **Emergência:** o botão vermelho desliga todas as transmissões na hora.
6. Opcional, no painel do Cloudflare: crie um **alerta de cobrança por e-mail** (Notificações → Billing). Ele é independente do DenDen. Lembre: o bloqueio do DenDen **não** é um limite garantido de faturamento do Cloudflare.

## 7. Levar o DenDen para o PC do amigo (5 min)

1. No seu PC:

   ```bash
   cd C:\Projetos\denden\app; flutter build windows --release
   ```

2. Compacte a pasta `C:\Projetos\denden\app\build\windows\x64\runner\Release` (a pasta inteira, não só o `.exe`).
3. Mande o zip ao amigo. Ele descompacta e abre o `denden.exe`.

O Windows pode mostrar um aviso de "aplicativo não reconhecido", porque o app não é assinado. Isso é esperado num app privado.

## 8. Primeiro teste real (15 min)

1. Os dois abrem o DenDen e, na primeira vez, colam o **endereço do Worker** e a **própria chave**.
2. **Você:** abre o jogo (em janela ou janela sem bordas), clica **Transmitir**, confere que "Áudio de" mostra o jogo e clica **Transmitir**.
3. Mande o código que aparecer (ex.: `K7P-92Q`) no Discord.
4. **Amigo:** clica **Assistir**, digita o código e clica **Assistir**.
5. Fiquem 10 minutos conversando pelo Discord.

**Anote:**

| Pergunta | Resposta |
|---|---|
| O amigo viu a tela? Em quanto tempo? | |
| O som do jogo chegou? | |
| A voz de vocês apareceu duplicada para ele? | |
| Atraso aproximado (ex.: bater palmas no jogo/vídeo) | |
| Travou ou caiu em algum momento? | |
| FPS do seu jogo com e sem transmissão | |
| Consumo mostrado no painel depois de 10 min (GB) | |

Se der erro, a tela mostra uma mensagem. Copie a mensagem exata.
