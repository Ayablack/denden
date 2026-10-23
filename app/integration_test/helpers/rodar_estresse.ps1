# Roda o modo de estresse do DenDen direto no .exe (sem flutter test) e
# registra o código de saída completo e a saída nativa de cada execução.
param(
  [Parameter(Mandatory = $true)][ValidateSet('Release', 'Debug')][string]$Build,
  [Parameter(Mandatory = $true)][string]$Modo,
  [int]$Ciclos = 10,
  [int]$Seg = 5,
  [string]$Janela = '',
  [int]$PrazoSeg = 300,
  [Parameter(Mandatory = $true)][string]$Saida
)

$exe = "C:\Projetos\denden\app\build\windows\x64\runner\$Build\denden.exe"
$nome = "$Build-$Modo-" + (Get-Date -Format 'HHmmss')
$log = Join-Path $Saida "$nome.log"
$out = Join-Path $Saida "$nome.stdout.txt"
$err = Join-Path $Saida "$nome.stderr.txt"

$cfg = "modo=$Modo;ciclos=$Ciclos;seg=$Seg;log=$log"
if ($Janela -ne '') { $cfg += ";janela=$Janela" }
$env:DENDEN_SOAK = $cfg
$p = Start-Process -FilePath $exe -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
# Sem guardar o handle já, o PowerShell perde o ExitCode.
$null = $p.Handle
$env:DENDEN_SOAK = $null

if (-not $p.WaitForExit($PrazoSeg * 1000)) {
  Stop-Process -Id $p.Id -Force
  $codigo = 'PRAZO'
} else {
  $codigo = '0x{0:X8}' -f $p.ExitCode
}
$ultima = if (Test-Path $log) { Get-Content $log -Tail 1 } else { '(sem log)' }
$ok = if (Test-Path $log) { (Select-String -Path $log -Pattern ': ok$').Count } else { 0 }
"$nome | saída $codigo | ciclos ok $ok/$Ciclos | última: $ultima"
