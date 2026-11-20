# Claude Code toast daemon (started on demand by notify.sh from WSL)
# Watches a Windows-side queue dir; WSL writes small req-*.req files there.
$ErrorActionPreference = 'Stop'
$Queue       = if ($env:CLAUDE_TOAST_DIR) { $env:CLAUDE_TOAST_DIR } else { 'D:\Temp\claude-toast' }
$Hb          = Join-Path $Queue 'heartbeat'
$PidFile     = Join-Path $Queue 'daemon.pid'
$Log         = Join-Path $Queue 'toastd.log'
$IdleMinutes = 720
$AppId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
$Tag   = 'claude-code'
$Group = 'claude'

function Write-Log([string]$m) {
  try { Add-Content -LiteralPath $Log -Value ((Get-Date).ToString('HH:mm:ss.fff') + ' ' + $m) -Encoding UTF8 } catch {}
}

$mutex = New-Object System.Threading.Mutex($false, 'Local\ClaudeToastDaemon')
if (-not $mutex.WaitOne(0)) { exit 0 }

New-Item -ItemType Directory -Force -Path $Queue | Out-Null
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime] | Out-Null
$notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId)

Set-Content -LiteralPath $PidFile -Value $PID -Encoding ASCII
if (-not (Test-Path $Hb)) { New-Item -ItemType File -Path $Hb | Out-Null }
[IO.File]::SetLastWriteTime($Hb, [datetime]::Now)

function Show-Toast([string]$title, [string]$body) {
  $x = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
  $texts = $x.GetElementsByTagName('text')
  $null = $texts.Item(0).AppendChild($x.CreateTextNode($title))
  $null = $texts.Item(1).AppendChild($x.CreateTextNode($body))
  $n = [Windows.UI.Notifications.ToastNotification]::new($x)
  $n.Tag = $Tag
  $n.Group = $Group
  $notifier.Show($n)
}

function Hide-Toast {
  try { [Windows.UI.Notifications.ToastNotificationManager]::History.Remove($Tag, $Group, $AppId) } catch {}
}

function Invoke-Queue {
  $files = @(Get-ChildItem -LiteralPath $Queue -Filter 'req-*.req' -ErrorAction SilentlyContinue | Sort-Object Name)
  foreach ($f in $files) {
    try {
      $lines = @([IO.File]::ReadAllLines($f.FullName, [Text.Encoding]::UTF8))
      if ($lines.Length -ge 1) {
        if ($lines[0] -eq '__remove__') {
          Hide-Toast
          Write-Log 'hide'
        } else {
          $body = ''
          if ($lines.Length -ge 2) { $body = $lines[1] }
          Show-Toast $lines[0] $body
          $t = $lines[0]
          if ($t.Length -gt 60) { $t = $t.Substring(0, 60) }
          Write-Log ('show ' + $t)
        }
      }
    } catch { Write-Log ('ERR ' + $_.Exception.Message) }
    try { Remove-Item -LiteralPath $f.FullName -Force } catch {}
  }
}

Write-Log ('start pid=' + $PID)
Get-ChildItem -LiteralPath $Queue -Filter '.tmp-*' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
Invoke-Queue

$w = New-Object System.IO.FileSystemWatcher
$w.Path = $Queue
$w.Filter = 'req-*.req'
$w.NotifyFilter = [IO.NotifyFilters]::FileName
$w.EnableRaisingEvents = $true

$lastWork = Get-Date
while ($true) {
  try { $null = $w.WaitForChanged([IO.WatcherChangeTypes]::All, 1500) } catch {}
  $pending = @(Get-ChildItem -LiteralPath $Queue -Filter 'req-*.req' -ErrorAction SilentlyContinue)
  if ($pending.Count -gt 0) {
    try { Invoke-Queue } catch { Write-Log ('loop ' + $_.Exception.Message) }
    $lastWork = Get-Date
  }
  try { [IO.File]::SetLastWriteTime($Hb, [datetime]::Now) } catch {}
  if (((Get-Date) - $lastWork).TotalMinutes -gt $IdleMinutes) { Write-Log 'idle exit'; break }
}
Remove-Item -LiteralPath $PidFile -Force -ErrorAction SilentlyContinue
