#Requires -Version 5.1
# install.ps1 - wezcld Windows installer
# Usage:
#   Install:   irm https://gitlab.leihuo.netease.com/public-tool/wezcld-main/-/raw/main/install.ps1 | iex
#   Uninstall: .\install.ps1 -Uninstall

param(
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

$REPO        = "public-tool/wezcld-main"
$GITLAB      = "https://gitlab.leihuo.netease.com"
$DEPLOY_USER  = "gitlab+deploy-token-79"
$DEPLOY_TOKEN = "gldt-yXcMc2xSXn_M3k1o-md2"
$BASE_URL    = "https://${DEPLOY_USER}:${DEPLOY_TOKEN}@gitlab.leihuo.netease.com/$REPO/-/raw/main/bin"
$InstallDir  = Join-Path $env:USERPROFILE ".local\share\wezcld\bin"
$BinDir      = Join-Path $env:USERPROFILE ".local\bin"
$StateDir    = Join-Path $env:USERPROFILE ".local\state\wezcld"

# ── Helpers ───────────────────────────────────────────────────────────────────
function Write-Ok  { param($msg) Write-Host "  $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "  $msg" -ForegroundColor Yellow }
function Write-Err { param($msg) Write-Host "  $msg" -ForegroundColor Red }

# ── Uninstall ─────────────────────────────────────────────────────────────────
if ($Uninstall) {
    Write-Host "Uninstalling wezcld..." -ForegroundColor Yellow

    foreach ($f in @("wezcld.ps1","it2.ps1","wezcld.cmd","it2.cmd")) {
        $p = Join-Path $BinDir $f
        if (Test-Path $p) { Remove-Item $p -Force; Write-Ok "Removed $p" }
    }

    if (Test-Path $InstallDir) { Remove-Item (Split-Path $InstallDir -Parent) -Recurse -Force; Write-Ok "Removed $InstallDir" }
    if (Test-Path $StateDir)   { Remove-Item $StateDir -Recurse -Force; Write-Ok "Removed $StateDir" }

    # Remove PATH entry from PowerShell profile
    foreach ($profilePath in @($PROFILE.CurrentUserAllHosts, $PROFILE.CurrentUserCurrentHost)) {
        if (Test-Path $profilePath) {
            $lines    = Get-Content $profilePath
            $filtered = $lines | Where-Object { $_ -notmatch '# wezcld$' }
            Set-Content $profilePath $filtered
            Write-Ok "Cleaned profile: $profilePath"
        }
    }

    Write-Ok "wezcld uninstalled."
    exit 0
}

# ── Install ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host " Installing wezcld (Windows / PowerShell edition)" -ForegroundColor Cyan
Write-Host " =================================================" -ForegroundColor Cyan
Write-Host ""

# Check wezterm
if (-not (Get-Command wezterm -ErrorAction SilentlyContinue)) {
    Write-Warn "Warning: 'wezterm' not found in PATH. Please install WezTerm first."
}

# Check claude
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Warn "Warning: 'claude' not found in PATH. Please install Claude Code first."
}

# Create directories
foreach ($d in @($InstallDir, $BinDir, $StateDir)) {
    New-Item -ItemType Directory -Path $d -Force | Out-Null
}

# Copy or download scripts
function Install-Script {
    param([string]$File, [string]$Dest)

    # 1. Look for the file next to install.ps1 (local clone / development)
    $LocalSrc = Join-Path $PSScriptRoot "bin\$File"
    if (Test-Path $LocalSrc) {
        Write-Host "  Installing $File from local source..." -NoNewline
        Copy-Item $LocalSrc $Dest -Force
        Write-Ok " OK"
        return
    }

    # 2. Fall back to GitHub Releases download
    Write-Host "  Downloading $File from GitHub..." -NoNewline
    try {
        Invoke-WebRequest -Uri "$BASE_URL/$File" -OutFile $Dest -UseBasicParsing -ErrorAction Stop
        Write-Ok " OK"
    } catch {
        Write-Err " FAILED: $_"
        Write-Host ""
        Write-Host "  Tip: Run this script from the cloned repo folder so it can use local files." -ForegroundColor Yellow
        exit 1
    }
}

Install-Script "wezcld.ps1" (Join-Path $InstallDir "wezcld.ps1")
Install-Script "it2.ps1"    (Join-Path $InstallDir "it2.ps1")

# Create .cmd shim wrappers so plain `wezcld` and `it2` work without typing .ps1
# Detect available PowerShell exe
$psExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }

@"
@echo off
$psExe -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\.local\share\wezcld\bin\wezcld.ps1" %*
"@ | Set-Content (Join-Path $BinDir "wezcld.cmd") -Encoding ASCII

@"
@echo off
$psExe -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\.local\share\wezcld\bin\it2.ps1" %*
"@ | Set-Content (Join-Path $BinDir "it2.cmd") -Encoding ASCII

Write-Ok "Created wezcld.cmd and it2.cmd in $BinDir"

# ── Add BinDir to user PATH (persistent) ──────────────────────────────────────
$userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
if ($userPath -notlike "*$BinDir*") {
    [System.Environment]::SetEnvironmentVariable("PATH", "$BinDir;$userPath", "User")
    Write-Ok "Added $BinDir to user PATH (persistent)"
} else {
    Write-Ok "$BinDir already in user PATH"
}

# ── Add to PowerShell profile ─────────────────────────────────────────────────
$profilePath = $PROFILE.CurrentUserCurrentHost
$profileDir  = Split-Path $profilePath -Parent
if (-not (Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }
if (-not (Test-Path $profilePath)) { New-Item -ItemType File -Path $profilePath -Force | Out-Null }

$pathLine = '$env:PATH = "$env:USERPROFILE\.local\bin;$env:PATH" # wezcld'
if (-not (Select-String -Path $profilePath -Pattern '# wezcld$' -Quiet)) {
    # Always append on a new line (existing file may not end with newline)
    $existing = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
    if ($existing -and -not $existing.EndsWith("`n")) {
        Add-Content -Path $profilePath -Value "" -Encoding UTF8
    }
    Add-Content -Path $profilePath -Value $pathLine -Encoding UTF8
    Write-Ok "Added PATH to PowerShell profile: $profilePath"
}

# ── Done ──────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host " Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "  Usage:"
Write-Host "    wezcld                  Launch Claude Code with WezTerm integration"
Write-Host "    wezcld --resume         Resume last session"
Write-Host ""
Write-Host "  Note: Restart your terminal (or run '. `$PROFILE') to refresh PATH."
Write-Host ""
Write-Host "  To uninstall:"
Write-Host "    .\install.ps1 -Uninstall"
Write-Host ""
