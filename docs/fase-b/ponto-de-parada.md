# Fase B — Ponto de parada do cartão

> Quem faz: **o dono do projeto**. O agente não cria contas nem mexe no painel.
> Regra: **não cadastrar cartão, não aceitar plano pago, não ativar nada que cobre.** Se algum passo pedir isso, pare e anote.

Tempo estimado: **10 a 15 minutos.**

## O que já se sabe (2026-10-22)

- A página do produto diz que dá para "começar a construir de graça, sem cartão de crédito" ([TURN/SFU](https://www.cloudflare.com/products/turn-sfu/)).
- A documentação manda criar o app em **Realtime → Serverless SFU** no painel ([Get started](https://developers.cloudflare.com/realtime/sfu/get-started/)), mas não diz se essa tela pede cartão.
- O [FAQ do TURN](https://developers.cloudflare.com/realtime/turn/faq/) fala em planos self-serve pagos com cartão. Ainda não está claro se isso vale para a franquia grátis.

## Passo a passo

1. Entre em https://dash.cloudflare.com com a sua conta. Se não tiver conta, crie uma **gratuita**. Se o cadastro pedir cartão, pare e vá para "Resultado: exige cartão".
2. No menu da esquerda, abra **Realtime** (pode aparecer como "Calls" ou "Realtime / SFU").
3. Abra **Serverless SFU** e procure o botão para criar um app (ex.: "Create application").
4. **Antes de confirmar**, leia a tela:
   - Pede cartão, forma de pagamento ou upgrade de plano? → **Não confirme.** Tire um print e pare.
   - Não pede nada? → Crie o app com o nome `denden-teste`. Vão aparecer o **App ID** e o **App Secret**.
5. **Não copie o App Secret para lugar nenhum**: nem chat, nem arquivo, nem print. Ele só entra no Worker na Fase B, com `wrangler secret put`. Se já viu, tudo bem: dá para gerar outro depois.
6. Volte em **Realtime** e abra **TURN**. Veja se dá para criar uma chave TURN sem cartão. Só olhe; não precisa criar agora.
7. Abra **Billing** (Cobrança) e veja se aparece alguma forma de pagamento cadastrada ou algum plano pago. Anote.

## Resultado (preencher)

| Pergunta | Resposta |
|---|---|
| Data | |
| Conta já existia? | |
| Criar o app SFU pediu cartão? | |
| Criar chave TURN pediu cartão? | |
| Há forma de pagamento cadastrada em Billing? | |
| Algum aviso sobre o que acontece ao passar de 1.000 GB? | |

## Depois

- **Ativou sem cartão:** a Fase B pode começar (Tasks 7 a 14), **depois da sua autorização**.
- **Exige cartão:** o plano para aqui. Levo ao grupo as alternativas:
  - (a) aprovar o cartão, com as 4 proteções da seção 5.6 do design prontas **antes** de ativar;
  - (b) LiveKit em infraestrutura gratuita que não peça cartão, se existir;
  - (c) adiar a Fase B.
