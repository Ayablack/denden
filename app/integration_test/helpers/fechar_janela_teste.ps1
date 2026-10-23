# Teste real: fecha a janela do jogo no meio da transmissão híbrida, com um
# "Falso Discord" tocando o tempo todo fora do DenDen. Esperado: aviso
# janela_fechou e energia de áudio parada depois (sem cair no áudio geral).
param(
  [ValidateSet('Release', 'Debug')][string]$Build = 'Release',
  [int]$FecharAosSeg = 18,
  [int]$Ciclos = 1,
  [int]$Seg = 40,
  [Parameter(Mandatory = $true)][string]$Saida
)

$h = $PSScriptRoot
function Abrir($titulo, $x) {
  Start-Process powershell -PassThru -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
    "$h\janela_teste.ps1", '-Titulo', "`"$titulo`"", '-Wav', 'C:\Windows\Media\Alarm01.wav', '-X', $x, '-Y', '60'
}
$jogo = Abrir 'DenDen Jogo Externo' 60
$discord = Abrir 'DenDen Falso Discord Externo' 720
Start-Sleep -Seconds 4

$log = Join-Path $Saida ("fechar-janela-$Build-" + (Get-Date -Format 'HHmmss') + '.log')
$env:DENDEN_SOAK = "modo=hibrido;ciclos=$Ciclos;seg=$Seg;janela=DenDen Jogo Externo;log=$log"
$exe = "C:\Projetos\denden\app\build\windows\x64\runner\$Build\denden.exe"
$p = Start-Process -FilePath $exe -PassThru
$null = $p.Handle
$env:DENDEN_SOAK = $null

Start-Sleep -Seconds $FecharAosSeg
Add-Content $log "$(Get-Date -Format o) TESTE: fechando a janela do jogo"
Stop-Process -Id $jogo.Id -Force
$null = $p.WaitForExit(120000)
Stop-Process -Id $discord.Id -Force -ErrorAction SilentlyContinue
Add-Content $log ("$(Get-Date -Format o) TESTE: saída 0x{0:X8}" -f $p.ExitCode)
Get-Content $log
