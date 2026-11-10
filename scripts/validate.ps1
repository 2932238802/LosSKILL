#Requires -Version 5.1
<#
.SYNOPSIS
  Validate every skill in this repo.

.DESCRIPTION
  Checks, for every folder under skills/:
    1. SKILL.md exists
    2. YAML frontmatter exists and has name + description
    3. frontmatter name equals the folder name (kebab-case)
    4. description is long enough and mentions a "not for" clause
    5. every relative markdown link / backticked references/*.md path resolves
    6. no absolute paths (C:\, /Users/, D:\) are referenced from a skill
  Also checks that every skill is listed in SKILLS.md.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\validate.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$skillsRoot = Join-Path $repoRoot 'skills'
$indexPath = Join-Path $repoRoot 'SKILLS.md'

if (-not (Test-Path -LiteralPath $skillsRoot)) { throw "skills/ not found: $skillsRoot" }
$indexText = if (Test-Path -LiteralPath $indexPath) { Get-Content -LiteralPath $indexPath -Raw -Encoding UTF8 } else { '' }

$errors = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]
$skillDirs = Get-ChildItem -LiteralPath $skillsRoot -Directory | Sort-Object Name

foreach ($dir in $skillDirs) {
  $rel = "skills/$($dir.Name)"
  $skillFile = Join-Path $dir.FullName 'SKILL.md'

  if (-not (Test-Path -LiteralPath $skillFile)) {
    $errors.Add("${rel}: missing SKILL.md")
    continue
  }

  $text = Get-Content -LiteralPath $skillFile -Raw -Encoding UTF8

  # ---- frontmatter ----
  if ($text -notmatch '(?s)^---\r?\n(.*?)\r?\n---') {
    $errors.Add("${rel}: no YAML frontmatter")
  } else {
    $fm = $Matches[1]
    $name = if ($fm -match '(?m)^name:\s*(.+?)\s*$') { $Matches[1].Trim('''', '"') } else { $null }
    $desc = if ($fm -match '(?ms)^description:\s*(?:\|\s*\r?\n)?(.*?)(?=^\S|\z)') { $Matches[1].Trim() } else { $null }

    if (-not $name) {
      $errors.Add("${rel}: frontmatter missing 'name'")
    } elseif ($name -ne $dir.Name) {
      $errors.Add("${rel}: frontmatter name '$name' != folder name")
    } elseif ($name -notmatch '^[a-z0-9]+(-[a-z0-9]+)*$') {
      $errors.Add("${rel}: name '$name' is not kebab-case")
    }

    if (-not $desc) {
      $errors.Add("${rel}: frontmatter missing 'description'")
    } else {
      if ($desc.Length -lt 40) { $warnings.Add("${rel}: description shorter than 40 chars") }
      if ($desc -notmatch '不用于|不适用|Not for|not for') {
        $warnings.Add("${rel}: description has no explicit 'not for' clause (AI may over-trigger)")
      }
    }
  }

  # ---- referenced files ----
  $refs = New-Object System.Collections.Generic.HashSet[string]
  foreach ($m in [regex]::Matches($text, '`(references/[^`\r\n]+?\.md)`')) { [void]$refs.Add($m.Groups[1].Value) }
  foreach ($m in [regex]::Matches($text, '\]\((?!https?:|#)([^)]+?\.md)(?:#[^)]*)?\)')) { [void]$refs.Add($m.Groups[1].Value) }

  foreach ($r in $refs) {
    $candidate = Join-Path $dir.FullName $r
    if (-not (Test-Path -LiteralPath $candidate)) {
      $errors.Add("${rel}: referenced file not found -> $r")
    }
  }

  # ---- absolute paths ----
  $abs = [regex]::Matches($text, '(?m)(?:^|[\s`("''])((?:[A-Za-z]:\\|/(?:Users|home)/)[^\s`"'')\]]+)')
  foreach ($m in $abs) { $warnings.Add("${rel}: absolute path referenced -> $($m.Groups[1].Value)") }

  # ---- index coverage ----
  if ($indexText -and $indexText -notmatch [regex]::Escape($dir.Name)) {
    $warnings.Add("${rel}: not mentioned in SKILLS.md")
  }
}

Write-Host "Checked $($skillDirs.Count) skill(s) under $skillsRoot"
Write-Host ''

if ($warnings.Count -gt 0) {
  Write-Host "WARNINGS ($($warnings.Count))" -ForegroundColor Yellow
  $warnings | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
  Write-Host ''
}

if ($errors.Count -gt 0) {
  Write-Host "ERRORS ($($errors.Count))" -ForegroundColor Red
  $errors | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
  exit 1
}

Write-Host 'All skills OK.' -ForegroundColor Green
