# LosSKILL: PowerShell 个人配置（Windows / PowerShell 7+）
# 由 scripts/install.ps1 复制到 $PROFILE.CurrentUserAllHosts
# 说明：本文件只做「锦上添花」的交互增强，不改系统设置，出错也不影响正常 shell。

# ---------------------------------------------------------------
# 1) PSReadLine：历史预测列表（就是截图里 <-/10> + [History] 那套）
# ---------------------------------------------------------------
if (Get-Module -ListAvailable -Name PSReadLine) {
    Import-Module PSReadLine -ErrorAction SilentlyContinue

    # 从历史里预测，ListView 才有「边打字边列候选」的效果
    Set-PSReadLineOption -PredictionSource History -PredictionViewStyle ListView -ErrorAction SilentlyContinue

    # ↑/↓：只翻「以当前输入开头」的历史（与 WSL 侧行为保持一致）
    Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
}

# ---------------------------------------------------------------
# 2) Oh My Posh（装了才启用；huvix 主题与 WSL 侧一致）
# ---------------------------------------------------------------
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    $ompTheme = Join-Path $HOME '.config\oh-my-posh\themes\huvix.omp.json'
    if (Test-Path $ompTheme) {
        oh-my-posh init pwsh --config $ompTheme | Invoke-Expression
    } else {
        oh-my-posh init pwsh | Invoke-Expression
    }
}

# ---------------------------------------------------------------
# 3) 常用别名（用函数实现，才能透传参数）
# ---------------------------------------------------------------
function gs      { git status @args }
function gp      { git pull @args }
function gpush   { git push @args }
function gc      { git commit @args }
function gco     { git checkout @args }
function gd      { git diff @args }
function glog    { git log --color --graph --pretty=format:'%h %s (%cr)' --abbrev-commit @args }
function ..      { Set-Location .. }
function ...     { Set-Location ../.. }
function ll      { Get-ChildItem -Force @args }
function which   { Get-Command @args }

# ---------------------------------------------------------------
# 4) 编辑：默认用 VS Code
# ---------------------------------------------------------------
if (Get-Command code -ErrorAction SilentlyContinue) {
    $env:EDITOR = 'code --wait'
    $env:VISUAL = 'code --wait'
}
