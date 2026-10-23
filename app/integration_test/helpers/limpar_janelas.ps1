Get-Process powershell -ErrorAction SilentlyContinue |
  Where-Object { $_.MainWindowTitle -like 'DenDen*' -and $_.MainWindowTitle -notlike '*Externo' } |
  Stop-Process -Confirm:$false
