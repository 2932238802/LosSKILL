param(
  [string]$Title = 'Claude Code',
  [string]$Body  = '需要你的操作',
  [string]$Tag   = 'claude-code',
  [string]$Group = 'claude',
  [switch]$Remove
)

# 从 WSL 调用：powershell.exe -NoProfile -ExecutionPolicy Bypass -File toast.ps1 ...
#   -Remove  : 从通知中心撤掉这条（提权完成后自动关）
#   默认     : 弹一条新的（同 Tag+Group 会替换上一条）
$ErrorActionPreference = 'Stop'
$appId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'

try {
  [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
  [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime] | Out-Null

  if ($Remove) {
    try { [Windows.UI.Notifications.ToastNotificationManager]::History.Remove($Tag, $Group, $appId) } catch { }
    exit 0
  }

  $template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent(
    [Windows.UI.Notifications.ToastTemplateType]::ToastText02)
  $texts = $template.GetElementsByTagName('text')
  $null = $texts.Item(0).AppendChild($template.CreateTextNode($Title))
  $null = $texts.Item(1).AppendChild($template.CreateTextNode($Body))

  $toast = [Windows.UI.Notifications.ToastNotification]::new($template)
  $toast.Tag = $Tag
  $toast.Group = $Group
  [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show($toast)
  exit 0
} catch {
  if (-not $Remove) {
    try {
      (New-Object -ComObject WScript.Shell).Popup($Body, 10, $Title, 64) | Out-Null
      exit 0
    } catch { exit 1 }
  }
  exit 0
}
