#!/bin/bash
# Experimento da captura híbrida: roda cada cenário em seu próprio processo
# (uma queda não apaga as medidas dos outros). Repete até 3 vezes se cair,
# exceto S6, que conta quedas. Uso, de dentro de app/:
#   CENARIOS="S2 S3C S2C" bash integration_test/helpers/rodar_cenarios.sh
# S2C, S3C e S4C precisam da janela "DenDen Falso Discord Externo" aberta
# FORA do DenDen (veja abrir_discord_externo.ps1).
H="$(cd "$(dirname "$0")" && pwd)"
M="$(cygpath -u "$LOCALAPPDATA")/Temp/denden-marcas.txt"
[ -n "$MANTER" ] || rm -f "$M"
for c in ${CENARIOS:-S1 S2 S3 S4 S5 S6}; do
  max=3; [ "$c" = S6 ] && max=1
  for i in $(seq 1 $max); do
    log="$(cygpath -u "$LOCALAPPDATA")/Temp/denden-cen-$c-$i.log"
    flutter test integration_test/hybrid_capture_windows_test.dart -d windows --dart-define=CENARIO=$c > "$log" 2>&1
    powershell -NoProfile -ExecutionPolicy Bypass -File "$H/limpar_janelas.ps1"
    if grep -q "$c: fim" "$M" 2>/dev/null && ! grep -q "did not complete" "$log"; then
      echo "$c: terminou (tentativa $i)"; break
    fi
    echo "$c: caiu na tentativa $i"
  done
done
grep -E "MEDIDA|S6 ciclo" "$M"
