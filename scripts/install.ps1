#Requires -Version 5.1
<#
.SYNOPSIS
  Install skills from the LosSKILL repo into a target skills directory.

.DESCRIPTION
  Copy only. No network access, and nothing inside a skill is executed.
  Each skill is a self-contained folder, so copying it is enough for any
  tool that follows the SKILL.md convention.

.PARAMETER Skill
  Skill folder name (e.g. sandra-sales), a comma separated list, or "all" (default).

.PARAMETER Target
  Destination skills directory. Defaults to <UserProfile>\.dsh\skills.

.PARAMETER Force
  Overwrite a skill folder that already exists in the target.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1
  powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Skill sandra-sales
  powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Skill all -Target 'D:\MyProject\.claude\skills' -Force
#>
[CmdletBinding()]
param(
  [string]$Skill = 'all',
  [string]$Target,
  [switch]$Force
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $repoRoot 'skills'
if (-not (Test-Path -LiteralPath $sourceRoot)) {
  throw "skills directory not found: $sourceRoot (run this script from the repo's scripts folder)"
}

if (-not $Target) {
  $Target = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.dsh\skills'
}

$Target = [System.IO.Path]::GetFullPath($Target)
$resolvedSource = (Resolve-Path -LiteralPath $sourceRoot).Path

# Installable skills: every sub-directory that contains a SKILL.md
$available = @(Get-ChildItem -LiteralPath $sourceRoot -Directory |
  Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md') } |
  Select-Object -ExpandProperty Name)

if ($available.Count -eq 0) { throw "No installable skill found under $sourceRoot (missing SKILL.md)" }

if ($Skill -eq 'all') {
  $names = $available
} else {
  $names = @($Skill -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
  $unknown = @($names | Where-Object { $available -notcontains $_ })
  if ($unknown.Count -gt 0) {
    throw ("Unknown skill: {0}. Available: {1}" -f ($unknown -join ', '), ($available -join ', '))
  }
}

New-Item -ItemType Directory -Force -Path $Target | Out-Null
Write-Host "Repo  : $repoRoot"
Write-Host "Target: $Target"
Write-Host ''

$installed = 0
$skipped = 0
foreach ($name in $names) {
  $src = Join-Path $resolvedSource $name
  $dst = Join-Path $Target $name

  if (Test-Path -LiteralPath $dst) {
    if (-not $Force) {
      Write-Warning "Already exists, skipped: $dst (use -Force to overwrite)"
      $skipped++
      continue
    }
    # Only remove this one skill folder, and only if it really sits inside Target
    $resolvedDst = [System.IO.Path]::GetFullPath($dst)
    if (-not $resolvedDst.StartsWith($Target, [System.StringComparison]::OrdinalIgnoreCase)) {
      throw "Refusing to delete a path outside the target directory: $resolvedDst"
    }
    Remove-Item -LiteralPath $resolvedDst -Recurse -Force
  }

  Copy-Item -LiteralPath $src -Destination $dst -Recurse
  $fileCount = @(Get-ChildItem -LiteralPath $dst -Recurse -File).Count
  Write-Host ("  [OK] {0} ({1} files)" -f $name, $fileCount)
  $installed++
}

Write-Host ''
Write-Host ("Done: {0} installed, {1} skipped." -f $installed, $skipped)

# --- Additional: Personal environment configuration (optional)
$applyEnv = Read-Host "Do you want to apply personal environment configurations (configs & software)? [Y/n]"
if ($applyEnv -ne 'n' -and $applyEnv -ne 'N') {
    Write-Host "`nApplying personal environment configurations for Windows..."
    $userProfile = [Environment]::GetFolderPath('UserProfile')

    function Backup-File([string]$Path) {
        if (Test-Path -LiteralPath $Path) {
            Copy-Item -LiteralPath $Path -Destination "$Path.losskill.bak" -Force
        }
    }

    # ---------- git 配置（带备份） ----------
    $gitConfig = Join-Path $repoRoot 'configs\.gitconfig'
    if (Test-Path $gitConfig) {
        $gitTarget = Join-Path $userProfile '.gitconfig'
        Backup-File $gitTarget
        Copy-Item -LiteralPath $gitConfig -Destination $gitTarget -Force
        Write-Host "  [OK] .gitconfig -> $gitTarget (旧文件备份为 .gitconfig.losskill.bak)"
    }

    # ---------- PowerShell profile（正确语法，替代旧的 alias ... = '...'） ----------
    $psConfig = Join-Path $repoRoot 'configs\powershell-profile.ps1'
    if (Test-Path $psConfig) {
        $psProfilePath = $PROFILE.CurrentUserAllHosts
        $psDir = Split-Path -Parent $psProfilePath
        if ($psDir -and -not (Test-Path $psDir)) { New-Item -ItemType Directory -Path $psDir -Force | Out-Null }
        Backup-File $psProfilePath
        # 幂等：先删掉本脚本以前写入的旧块，再追加一次
        if (Test-Path $psProfilePath) {
            $kept = Get-Content -LiteralPath $psProfilePath |
                    Where-Object { $_ -notmatch 'Custom aliases from LosSKILL' -and $_ -notmatch "^alias \w+ = '" }
            Set-Content -LiteralPath $psProfilePath -Value $kept -Encoding UTF8
        }
        if (-not (Select-String -LiteralPath $psProfilePath -Pattern 'LosSKILL: PowerShell profile' -Quiet -ErrorAction SilentlyContinue)) {
            Add-Content -LiteralPath $psProfilePath -Encoding UTF8 -Value @(
                ''
                '# LosSKILL: PowerShell profile (详见仓库 configs/powershell-profile.ps1)'
                ". `"$psConfig`""
            )
        }
        Write-Host "  [OK] PowerShell profile 已接入：$psProfilePath"
    }

    # ---------- Neovim 配置 ----------
    $nvimConfig = Join-Path $repoRoot 'configs\nvim'
    if (Test-Path $nvimConfig) {
        $nvimTarget = Join-Path $userProfile 'AppData\Local\nvim'
        New-Item -ItemType Directory -Path $nvimTarget -Force | Out-Null
        Backup-File (Join-Path $nvimTarget 'init.vim')
        Copy-Item -LiteralPath (Join-Path $nvimConfig 'init.vim') -Destination $nvimTarget -Force
        Write-Host "  [OK] Neovim 配置 -> $nvimTarget"
    }

    # ---------- 常用软件（winget） ----------
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        $packages = @(
            @{ Id = 'Git.Git';                  Name = 'Git' },
            @{ Id = 'Neovim.Neovim';            Name = 'Neovim' },
            @{ Id = 'Microsoft.VisualStudioCode'; Name = 'VS Code' },
            @{ Id = 'JanDeDobbeleer.OhMyPosh';  Name = 'Oh My Posh' },
            @{ Id = 'Rustlang.Rustup';          Name = 'Rust' },
            @{ Id = 'Kitware.CMake';            Name = 'CMake' },
            @{ Id = 'Microsoft.VisualStudio.2022.BuildTools'; Name = 'MSVC Build Tools' }
        )
        foreach ($pkg in $packages) {
            $installed = winget list --id $pkg.Id --exact 2>$null | Select-String -Pattern $pkg.Id -Quiet
            if ($installed) {
                Write-Host "    [skip] $($pkg.Name) 已安装"
            } else {
                Write-Host "    [installing] $($pkg.Name) ..."
                winget install --id $pkg.Id --silent --accept-package-agreements --accept-source-agreements
            }
        }
    } else {
        Write-Host "  winget 不可用，请手动安装：Git / Neovim / VS Code / Oh My Posh / Rust"
    }

    # ---------- SSH 密钥（存在就不重建，邮箱已一致就不再提示） ----------
    $sshDir = Join-Path $userProfile '.ssh'
    $sshKey = Join-Path $sshDir 'id_ed25519'
    $sshPub = "$sshKey.pub"
    if (-not (Test-Path $sshDir)) { New-Item -ItemType Directory -Path $sshDir -Force | Out-Null }
    if (-not (Test-Path $sshKey)) {
        ssh-keygen -t ed25519 -C 'losangelous@windows' -f $sshKey -N '""'
        Write-Host "  [OK] 已创建新的 SSH 密钥：$sshKey"
    } else {
        Write-Host "  [OK] 已有 SSH 密钥：$sshKey"
    }
    if (Test-Path $sshPub) {
        $pub = (Get-Content -LiteralPath $sshPub -Raw).Trim()
        if ($pub -match '19857198709@163\.com') {
            Write-Host "  [skip] 该公钥邮箱为 19857198709@163.com，已加入过 GitHub，无需重复添加"
        } else {
            Write-Host "`n  === 把下面这行公钥加到 GitHub ==="
            Write-Host "  页面：https://github.com/settings/keys"
            Write-Host "  $pub"
            Write-Host "  ----------------------------------"
        }
    }

    Write-Host "`nPersonal environment configuration applied successfully!"
}

Write-Host 'Note: some tools need a session restart or skill list refresh before the new skills appear.'
