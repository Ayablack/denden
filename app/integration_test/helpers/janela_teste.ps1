# Janela de teste para os experimentos de captura: anima a tela (para o
# vídeo ter movimento) e, se receber um .wav, toca em loop pelo próprio
# processo (para o loopback por processo ter o que capturar).
param(
  [Parameter(Mandatory = $true)][string]$Titulo,
  [string]$Wav = '',
  [int]$X = 100,
  [int]$Y = 100
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = $Titulo
$form.Width = 640
$form.Height = 420
$form.StartPosition = 'Manual'
$form.Location = New-Object System.Drawing.Point($X, $Y)

$label = New-Object System.Windows.Forms.Label
$label.Dock = 'Fill'
$label.Font = New-Object System.Drawing.Font('Consolas', 48)
$label.TextAlign = 'MiddleCenter'
$form.Controls.Add($label)

$relogio = [System.Diagnostics.Stopwatch]::StartNew()
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 15
$timer.Add_Tick({
  $ms = $relogio.ElapsedMilliseconds
  $label.Text = "$Titulo`n$ms"
  $h = ($ms / 10) % 360
  $label.BackColor = [System.Drawing.Color]::FromArgb(255, [int](127 + 127 * [Math]::Sin($h * 0.0174)), [int](127 + 127 * [Math]::Cos($h * 0.0174)), 128)
})

if ($Wav -ne '') {
  $player = New-Object System.Media.SoundPlayer $Wav
  $form.Add_Shown({ $player.PlayLooping() })
}
$form.Add_Shown({ $timer.Start() })
[System.Windows.Forms.Application]::Run($form)
