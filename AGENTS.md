# Instruções para agentes (Jules, Claude e outros)

DenDen: app Flutter **só para Windows** de transmissão privada de tela e áudio entre amigos (até 5 espectadores). A voz fica no Discord. A mídia passa pelo **Cloudflare Realtime SFU**. Um **Cloudflare Worker** com Durable Object (`backend/worker`) cuida de salas, chaves, consumo e limites.

Projeto pessoal, de custo zero: o consumo precisa ficar dentro da franquia gratuita do Cloudflare.

## Idioma
- Código, comentários, mensagens de commit, PRs e textos da interface: **português do Brasil**.
- Textos para o usuário em linguagem simples, sem jargão técnico e sem expor detalhes internos ou chaves.

## Estrutura
- `app/`: app Flutter Windows.
  - `lib/capture/`: captura de tela e áudio (PC menos o Discord, janela ou sem áudio).
  - `lib/media/`: conexão WebRTC com o SFU.
  - `lib/rooms/`: API do Worker e configurações salvas.
  - `lib/ui/`: telas.
  - `lib/usage/`: formatação e estatísticas de consumo.
  - `lib/lab/`: laboratório e testes de estresse.
  - `packages/flutter_webrtc/`: **cópia local com correções próprias. Não atualize nem substitua.**
- `backend/worker/`: Worker em TypeScript.
  - `src/group.ts`: Durable Object (salas, limites, checagem no SFU, duração máxima).
  - `src/usage.ts`: contas puras de consumo e níveis de limite.
  - `src/realtime.ts`: cliente da API do Realtime.
  - `src/index.ts`: rotas HTTP.
  - `test/`: testes com `@cloudflare/vitest-plugin`.
- `docs/`: design (`docs/superpowers/specs/`), resultados das fases e guia de implantação.

## Como testar

### Worker (roda em Linux)
```bash
cd backend/worker
npm ci
npm test        # vitest; todos precisam passar
npm run check   # tsc --noEmit
```

### App
```bash
cd app
flutter pub get
flutter analyze
flutter test
```

Limitações do app num ambiente Linux:
- **Não** compila para Windows.
- Testes que dependem de captura, `flutter_webrtc` nativo ou `integration_test/` **não** rodam. Isso é esperado.
- Rode só testes de lógica pura e de widgets. Se algum depender de plugin nativo, diga no PR em vez de "consertar".

## Regras
1. **Nunca** commite segredos: chaves, tokens, App ID/Secret do Realtime ou hash de administrador. Os segredos vivem só no `wrangler secret` do dono.
2. **Não rode** `wrangler deploy`, `wrangler secret`, `wrangler login` nem nada que acesse a conta Cloudflare.
3. **Não mude** os limites padrão sem pedido explícito. Os padrões ficam em `DEFAULT_BUDGET`, em `usage.ts`:
   - orçamento de 900 GB;
   - avisos em 50/75/90/100%;
   - teto de 105%;
   - duração máxima de 6 h.
4. Não mexa em `app/packages/flutter_webrtc/` nem em código de captura nativa sem pedido explícito.
5. Mudanças pequenas e focadas: uma tarefa por PR. Não reformate arquivos inteiros nem renomeie coisas fora do escopo.
6. Siga o estilo do código ao redor, inclusive a quantidade de comentários e os nomes em português.
7. Teste junto com o código: lógica nova ou corrigida ganha teste. Rode a suíte antes de abrir o PR e diga no PR o que rodou e o resultado.
8. Não adicione dependências novas sem justificar no PR.
9. Abra PR contra `main`. Nunca faça push direto no `main`.
10. Em caso de dúvida sobre comportamento, pare e pergunte no PR em vez de adivinhar.
