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
Write-Host 'Note: some tools need a session restart or skill list refresh before the new skills appear.'
