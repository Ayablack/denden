#!/bin/bash
# Testes de integração com UMA sessão WebRTC por processo.
#
# Motivo: sob o `flutter test`, iniciar uma 2ª sessão no mesmo processo
# derruba o app (0xC0000005 / 0xC0000409 na worker_thread do libwebrtc),
# mesmo com a ordem de encerramento corrigida (3/10). Fora da ferramenta a
# mesma sequência não cai (ver docs/experimentos/2026-10-23-*). A estabilidade
# real com várias sessões é medida pelo modo de estresse (rodar_estresse.ps1).
#
# Uso, de dentro de app/:  RODADAS=10 bash integration_test/helpers/rodar_integracao.sh
cd "$(dirname "$0")/../.." || exit 1
R=${RODADAS:-1}
L="$(cygpath -u "$LOCALAPPDATA")/Temp/denden-integracao"
mkdir -p "$L"
casos=(
  "integration_test/capture_windows_test.dart|"
  "integration_test/loopback_windows_test.dart|Alta"
  "integration_test/loopback_windows_test.dart|Média"
  "integration_test/lab_page_windows_test.dart|"
)
ok=0; total=0
for r in $(seq 1 "$R"); do
  for c in "${casos[@]}"; do
    f="${c%%|*}"; n="${c#*|}"; total=$((total+1))
    log="$L/r$r-$(basename "$f" .dart)-${n:-tudo}.log"
    if [ -n "$n" ]; then
      flutter test "$f" -d windows --plain-name "$n" > "$log" 2>&1
    else
      flutter test "$f" -d windows > "$log" 2>&1
    fi
    if grep -q "All tests passed" "$log"; then ok=$((ok+1)); s=passou; else s=FALHOU; fi
    echo "rodada $r: $(basename "$f") ${n:-} -> $s"
  done
done
echo "total: $ok/$total passaram"
