# wezcld.ps1 - WezTerm it2 shim launcher for Claude Code (Windows PowerShell version)
# Compatible with Windows PowerShell 5.1+ and PowerShell 7+

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Parse args manually to avoid PS parameter binding quirks with --version / -v
$RawArgs    = @($args | ForEach-Object { "$_" })
$ShowVersion = ($RawArgs -contains "--version") -or ($RawArgs -contains "-v") -or ($RawArgs -contains "-Version")
$Uninstall   = $RawArgs -contains "--uninstall" -or $RawArgs -contains "-Uninstall"
$ClaudeArgs  = $RawArgs | Where-Object { $_ -notin @("--version","-v","-Version","--uninstall","-Uninstall") }

# ── Uninstall ────────────────────────────────────────────────────────────────
if ($Uninstall) {
    $BinDir     = Join-Path $env:USERPROFILE ".local\bin"
    $InstallDir = Join-Path $env:USERPROFILE ".local\share\wezcld"
    $StateDir   = Join-Path $env:USERPROFILE ".local\state\wezcld"

    Write-Host "Uninstalling wezcld..." -ForegroundColor Yellow

    # Remove scripts from bin
    foreach ($f in @("wezcld.ps1","it2.ps1","wezcld.cmd","it2.cmd")) {
        $p = Join-Path $BinDir $f
        if (Test-Path $p) { Remove-Item $p -Force }
    }

    # Remove install/state dirs
    if (Test-Path $InstallDir) { Remove-Item $InstallDir -Recurse -Force }
    if (Test-Path $StateDir)   { Remove-Item $StateDir   -Recurse -Force }

    # Remove from PowerShell profile PATH line
    foreach ($profilePath in @($PROFILE.CurrentUserAllHosts, $PROFILE.CurrentUserCurrentHost)) {
        if (Test-Path $profilePath) {
            $lines = Get-Content $profilePath
            $filtered = $lines | Where-Object { $_ -notmatch '# wezcld$' }
            Set-Content $profilePath $filtered
        }
    }

    Write-Host "wezcld uninstalled." -ForegroundColor Green
    exit 0
}

# ── Version ──────────────────────────────────────────────────────────────────
if ($ShowVersion) {
    Write-Output "wezcld dev"
    exit 0
}

# ── Resolve script's own directory (follow junctions/symlinks) ───────────────
$ScriptPath = $MyInvocation.MyCommand.Path
if (-not $ScriptPath) { $ScriptPath = $PSCommandPath }
$ShimDir = Split-Path (Split-Path $ScriptPath -Parent) -Parent

# ── Detect WezTerm ───────────────────────────────────────────────────────────
if ($env:TERM_PROGRAM -ne "WezTerm") {
    Write-Warning "Not running in WezTerm. Falling back to plain claude."
    $allArgs = if ($ClaudeArgs) { $ClaudeArgs } else { @() }
    & claude @allArgs
    exit $LASTEXITCODE
}

# ── State directory ──────────────────────────────────────────────────────────
$StateDir = if ($env:WEZCLD_STATE) { $env:WEZCLD_STATE } else {
    Join-Path $env:USERPROFILE ".local\state\wezcld"
}
New-Item -ItemType Directory -Path $StateDir -Force | Out-Null

# ── Clean up stale state from previous sessions ───────────────────────────────
# Remove grid-panes-*, *.lock, *.tmp left by previous runs
Get-ChildItem -Path $StateDir -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^grid-panes' } |
    ForEach-Object { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue }
Remove-Item (Join-Path $StateDir "it2-counter") -Force -ErrorAction SilentlyContinue

# ── Override env vars to trigger Claude Code's iTerm detection ───────────────
$env:TERM_PROGRAM    = "iTerm.app"
$env:LC_TERMINAL     = "iTerm2"
$env:ITERM_SESSION_ID = "wezcld-$PID"

# ── Put our it2 shim first in PATH ───────────────────────────────────────────
$env:WEZCLD_STATE = $StateDir
$env:PATH = (Join-Path $ShimDir "bin") + [System.IO.Path]::PathSeparator + $env:PATH

# ── Watchdog: clean up panes after this process exits ────────────────────────
$parentPid  = $PID
$weztermPane = $env:WEZTERM_PANE
$watchdogScript = @"
`$statDir   = '$($StateDir -replace "'","''")'
`$wztPane   = '$weztermPane'
`$parentPid = $parentPid

# Wait for parent to exit
while (`$true) {
    try {
        `$proc = Get-Process -Id `$parentPid -ErrorAction Stop
        Start-Sleep -Seconds 1
    } catch {
        break
    }
}

# Kill all tracked panes
`$gridFile = Join-Path `$statDir "grid-panes-`$wztPane"
if (Test-Path `$gridFile) {
    Get-Content `$gridFile | ForEach-Object {
        `$paneId = `$_.Trim()
        if (`$paneId) {
            wezterm cli kill-pane --pane-id `$paneId 2>`$null
        }
    }
    Remove-Item `$gridFile -Force -ErrorAction SilentlyContinue
}
"@

# Launch watchdog as a detached background process
$psExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
Start-Process $psExe -ArgumentList "-NoProfile","-NonInteractive","-WindowStyle","Hidden","-Command",$watchdogScript -WindowStyle Hidden

# ── Launch Claude ─────────────────────────────────────────────────────────────
$allArgs = @("--teammate-mode","tmux")
if ($ClaudeArgs) { $allArgs += $ClaudeArgs }
& claude @allArgs
exit $LASTEXITCODE
