# Vigia o próximo denden.exe que abrir e registra o código de saída quando
# ele terminar. Serve para saber, dentro do `flutter test`, se o app caiu
# (ex.: 0xC0000005) ou se foi encerrado pela ferramenta.
param(
  [Parameter(Mandatory = $true)][string]$Saida,
  [int]$PrazoSeg = 900
)

$fim = (Get-Date).AddSeconds($PrazoSeg)
$vistos = @{}
while ((Get-Date) -lt $fim) {
  foreach ($p in Get-Process denden -ErrorAction SilentlyContinue) {
    if (-not $vistos.ContainsKey($p.Id)) {
      $null = $p.Handle  # sem o handle o ExitCode se perde
      $vistos[$p.Id] = $p
      Add-Content $Saida "$(Get-Date -Format o) abriu pid=$($p.Id)"
    }
  }
  foreach ($id in @($vistos.Keys)) {
    $p = $vistos[$id]
    if ($p.HasExited) {
      Add-Content $Saida ("$(Get-Date -Format o) saiu pid=$id código=0x{0:X8}" -f $p.ExitCode)
      $vistos.Remove($id)
    }
  }
  Start-Sleep -Milliseconds 200
}
