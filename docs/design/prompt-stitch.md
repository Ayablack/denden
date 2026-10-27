# Prompt para o Google Stitch: DenDen fiel ao app real

Cole o bloco abaixo no Stitch como **correção** do projeto atual. Ele lista o que o app tem de verdade hoje e o que não deve aparecer.

```text
Revise the DenDen design so it matches the real app exactly. The current screens invent features that do not exist. Keep the visual identity (dark navy, cyan accent, snail-shell + waves logo), but rebuild the screens from the inventory below. Do not add any feature that is not in this list.

## What DenDen is
A private Windows app to share ONE screen (video + PC audio) with up to 5 friends. Voice chat happens in Discord, NOT in DenDen. A friend joins by typing a 6-character room code (shown as K7P-92Q). Each person has a personal key given by the admin. There are no accounts, no logins, no friend lists, no presence, no chat, no reactions, no channels, no microphone.

## Remove from the current design
- Friends list, "Amigos online", avatars, presence, "Canais", "Salas" list, "Nova Sala" sidebar.
- Chat, reactions, "Conversar com espectadores", voice channel, microphone toggle or meter.
- Telemetry bar (FPS, perda de pacotes, render lag, edge server name), codec names (AV1, HEVC), "criptografia ponta a ponta", "baixa latência" switches, "denden.live" links.
- Any invite link: sharing is only the room code, copied to the clipboard.
- 1440p / 144 Hz options: the real qualities are only the three below.

## Real screens (all text in Brazilian Portuguese, exactly as written)

1. Início
   - Two big buttons side by side: "Transmitir" (primary) and "Assistir" (secondary).
   - Top bar actions (text buttons): "Consumo", "Administração" (only for the admin), "Configurações".
   - Footer: "Versão 1.0.4". When a newer version exists: "Versão 1.0.5 disponível" + button "Atualizar"; while downloading, a progress bar and "Baixando… o DenDen vai fechar e abrir de novo."

2. Transmitir — preparar
   - "Tela": dropdown of monitors (e.g. "Tela 1", "Tela 2").
   - "Áudio de": dropdown with "PC inteiro, menos o Discord" (default), one entry per open window ("Janela: <nome do app>"), and "Sem áudio".
   - "Qualidade": "Alta (1080p60)", "Média (720p60)", "Economia (720p30)".
   - Primary button "Transmitir".

3. Transmitindo (ao vivo)
   - Big room code "K7P-92Q" with "Copiar" and the hint "Passe este código no Discord:".
   - Status: "Conectando…", "Transmitindo", "Reconectando…" or "Transmissão encerrada".
   - "Consumo desta transmissão: 1,36 GB" and "Consumo do mês: 3,49 GB".
   - Live change without ending: "Tela" dropdown, "Qualidade" dropdown, button "Aplicar".
   - Warnings banner (only when they happen): budget warnings at 50/75/90/100%, "O orçamento do mês acabou: qualidade em Economia", "A transmissão termina em 5 min pela duração máxima", capture problems ("A janela do jogo fechou").
   - Destructive button "Parar", which asks "Parar a transmissão?" with "Continuar transmitindo" and "Parar e sair". No viewer names: at most a viewer count.

4. Assistir
   - Before: one field "Código da sala" and button "Assistir"; errors in plain text ("Sala não encontrada", "Sala cheia", "Servidor fora do ar" with "Tentar de novo").
   - Watching: the video fills the window, a thin top bar with "← Voltar", status and "Sair". Nothing else over the video.

5. Consumo
   - "Mês 2026-10 (UTC)", progress bar against the budget (900 GB) with markers 50%, 75%, 90%, 100%.
   - Four labeled numbers, always with their label: "Estimado", "Confirmado pelo Cloudflare", "Custo estimado" (US$ and ≈ R$), "Faturado".
   - "Transmissões ao vivo" and "Histórico" (code, minutes, status, GB).
   - Fixed notice: "O bloqueio do DenDen não é um limite garantido de faturamento do Cloudflare."

6. Administração (admin only)
   - "Chaves dos amigos": name field + "Criar chave" (the key is shown once, with copy); list with "Revogar".
   - "Limites": orçamento (GB), avisos (%), teto (%), duração máxima (h), "Salvar".
   - "Emergência": one red switch that stops every transmission.

7. Configurações
   - "Endereço do servidor", "Sua chave", "Chave de administrador (opcional)", button "Salvar"; back arrow "Voltar".

8. States: first-run (only Configurações, no back arrow), loading, empty history, server offline, invalid key, budget blocked, emergency on.

## Design system constraints
- Build for Flutter Material 3 on Windows: standard components (FilledButton, OutlinedButton, TextField, Dropdown, Switch, LinearProgressIndicator, Card), no custom shaders, no glass blur.
- Provide BOTH a dark theme (main) and a light theme with the same tokens.
- Window from 960×600 up to full HD; layouts must not depend on a sidebar.
- One font family available offline (bundle it), e.g. Inter or Noto Sans.
- Deliver: color tokens (light + dark), type scale, spacing scale, component states, and the app icon as 256/48/32/16 px PNG plus a monochrome version.
```
