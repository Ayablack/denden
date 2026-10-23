# Abre o "Falso Discord" fora da árvore de processos do DenDen. Filhos do
# DenDen são excluídos do áudio da tela inteira e não serviriam de controle.
Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
  "$PSScriptRoot\janela_teste.ps1", '-Titulo', '"DenDen Falso Discord Externo"',
  '-Wav', 'C:\Windows\Media\Alarm01.wav', '-X', '720', '-Y', '50'
