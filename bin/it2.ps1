# it2.ps1 - iTerm2 CLI shim for wezcld (Windows PowerShell version)
# Compatible with Windows PowerShell 5.1+ and PowerShell 7+
# NOTE: No param() block - we use $args directly so --version is not swallowed by PS parameter binding

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# All raw arguments as string array
$Argv = @($args | ForEach-Object { "$_" })

# ── State directory ───────────────────────────────────────────────────────────
$StateDir = if ($env:WEZCLD_STATE) { $env:WEZCLD_STATE } else {
    Join-Path $env:USERPROFILE ".local\state\wezcld"
}
New-Item -ItemType Directory -Path $StateDir -Force | Out-Null

$LogFile     = Join-Path $StateDir "it2-calls.log"
$CounterFile = Join-Path $StateDir "it2-counter"

# ── Atomic counter (Named Mutex) ──────────────────────────────────────────────
function Get-NextSessionId {
    $mtx = New-Object System.Threading.Mutex($false, "Global\WezcldCounter")
    $acquired = $false
    try {
        $acquired = $mtx.WaitOne(3000)
        if (-not $acquired) { return 0 }
        $counter = 0
        if (Test-Path $CounterFile) {
            $counter = [int](Get-Content $CounterFile -Raw).Trim()
        }
        $counter++
        Set-Content $CounterFile $counter -Encoding UTF8
        return $counter
    } finally {
        if ($acquired) { try { $mtx.ReleaseMutex() } catch {} }
        $mtx.Dispose()
    }
}

# ── Logging ───────────────────────────────────────────────────────────────────
function Write-Log {
    param([int]$ExitCode, [string]$Output, [string]$ArgvStr)
    $ts   = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $line = "[$ts] ARGV: $ArgvStr | EXIT: $ExitCode | STDOUT: $Output"
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

# Build ARGV string for logging
$ArgvStr = "it2 " + ($Argv | ForEach-Object {
    $s = $_ -replace "`n"," "
    if ($s -match '[ "|]') { "'$s'" } else { $s }
} | Where-Object { $_ -ne "" }) -join " "

# ── Grid mutex helpers ────────────────────────────────────────────────────────
$script:GridMutex = $null

function Lock-Grid {
    $paneId = if ($env:WEZTERM_PANE) { $env:WEZTERM_PANE } else { "0" }
    $script:GridMutex = New-Object System.Threading.Mutex($false, "Global\WezcldGrid_$paneId")
    $acquired = $script:GridMutex.WaitOne(5000)
    if (-not $acquired) {
        Write-Host "Failed to acquire grid lock" -ForegroundColor Red
        return $false
    }
    return $true
}

function Unlock-Grid {
    if ($script:GridMutex) {
        try { $script:GridMutex.ReleaseMutex() } catch {}
        $script:GridMutex.Dispose()
        $script:GridMutex = $null
    }
}

# ── Prune stale panes ─────────────────────────────────────────────────────────
function Remove-StalePanes {
    param([string]$GridFile)
    if (-not (Test-Path $GridFile)) { return }
    $content = @(Get-Content $GridFile -ErrorAction SilentlyContinue | Where-Object { $_.Trim() })
    if (-not $content) { return }
    try {
        $liveOutput = wezterm cli list 2>$null
        if (-not $liveOutput) { return }
        $livePanes = @($liveOutput | Select-Object -Skip 1 | ForEach-Object {
            ($_ -split '\s+') | Where-Object { $_ } | Select-Object -Index 2
        } | Where-Object { $_ })
    } catch { return }
    $kept = $content | Where-Object { $id = $_.Trim(); $id -and ($livePanes -contains $id) }
    Set-Content $GridFile ($kept -join "`n") -NoNewline -Encoding UTF8
}

# ── session split ─────────────────────────────────────────────────────────────
function Invoke-SessionSplit {
    param([string[]]$SubArgs)
    if (-not (Lock-Grid)) { exit 1 }
    try {
        $MAX_COLS = 3
        $paneEnv  = if ($env:WEZTERM_PANE) { $env:WEZTERM_PANE } else { "0" }
        $GridFile = Join-Path $StateDir "grid-panes-$paneEnv"

        Remove-StalePanes $GridFile

        $agentCount = 0
        if (Test-Path $GridFile) {
            $lines = @(Get-Content $GridFile | Where-Object { $_.Trim() -ne "" })
            $agentCount = $lines.Count
        }

        $row = [math]::Floor($agentCount / $MAX_COLS)
        $col = $agentCount % $MAX_COLS
        $newPaneId = ""

        if ($row -eq 0 -and $col -eq 0) {
            $newPaneId = (wezterm cli split-pane --top --percent 65 --pane-id "$paneEnv" 2>$null) | Select-Object -First 1
        } elseif ($row -eq 0) {
            $allLines   = @(Get-Content $GridFile | Where-Object { $_.Trim() -ne "" })
            $prevPane   = $allLines[-1].Trim()
            $remaining  = $MAX_COLS - $col
            $pct        = [math]::Floor((100 * $remaining + ($remaining + 1) / 2) / ($remaining + 1))
            $newPaneId  = (wezterm cli split-pane --right --percent $pct --pane-id "$prevPane" 2>$null) | Select-Object -First 1
        } else {
            $paneAboveIdx = $agentCount - $MAX_COLS
            $allLines     = @(Get-Content $GridFile | Where-Object { $_.Trim() -ne "" })
            $paneAbove    = $allLines[$paneAboveIdx].Trim()
            $newPaneId    = (wezterm cli split-pane --bottom --pane-id "$paneAbove" 2>$null) | Select-Object -First 1
        }

        if (-not $newPaneId) {
            Write-Host "Failed to create split pane" -ForegroundColor Red
            exit 1
        }

        Add-Content -Path $GridFile -Value $newPaneId.Trim() -Encoding UTF8
        wezterm cli activate-pane --pane-id "$paneEnv" 2>$null | Out-Null

        return "Created new pane: $($newPaneId.Trim())"
    } finally {
        Unlock-Grid
    }
}

# ── Convert Unix shell command to PowerShell syntax ───────────────────────────
# Handles Claude Code's agent launch pattern:
#   cd 'dir' && env K1=V1 K2=V2 'node_script' --args
# Converts to PowerShell:
#   Set-Location 'dir'; $env:K1='V1'; $env:K2='V2'; & 'node_script' --args
function Convert-UnixToPowerShell {
    param([string]$cmd)

    # 1. Unescape backslash-escaped colons that Unix shells produce (https\:// → https://)
    $cmd = $cmd -replace '\\:', ':'

    # 2. Replace && with ; (PS5 does not support &&)
    $cmd = $cmd -replace '\s*&&\s*', '; '

    # 3. Convert Unix "env K1=V1 K2=V2 <executable> <args>" block
    #    Regex: after start-of-string or "; ", match "env " followed by one-or-more KEY=VALUE pairs,
    #    then capture everything after as the real command.
    $envPattern = '(?:^|(?<=;\s))env\s+((?:[A-Za-z_][A-Za-z_0-9]*=[^\s]+\s+)+)(.*)'
    $cmd = [regex]::Replace($cmd, $envPattern, {
        param($m)
        $pairsRaw = $m.Groups[1].Value.Trim() -split '\s+'
        $rest     = $m.Groups[2].Value.Trim()

        $setters = ($pairsRaw | Where-Object { $_ -match '^[A-Za-z_][A-Za-z_0-9]*=' } | ForEach-Object {
            $kv  = $_ -split '=', 2
            $key = $kv[0]
            $val = $kv[1] -replace "'", "''"   # escape single quotes inside value
            "`$env:$key='$val'"
        }) -join '; '

        # $rest is the executable + args. In PowerShell a bare string is not executed,
        # need & to invoke it. If it's a .js file, invoke via "node".
        $invoke = if ($rest -match "\.js'?\s*") { "& node $rest" } else { "& $rest" }

        "$setters; $invoke"
    })

    # 4. Convert "cd 'path'" → "Set-Location 'path'"
    $cmd = $cmd -replace '(?:^|(?<=;\s))cd\s+', 'Set-Location '

    return $cmd.Trim()
}

# ── session run ───────────────────────────────────────────────────────────────
function Invoke-SessionRun {
    param([string[]]$SubArgs)
    $target   = ""
    $cmdParts = @()
    $i = 0
    while ($i -lt $SubArgs.Count) {
        if ($SubArgs[$i] -in @("-s","--session") -and ($i+1) -lt $SubArgs.Count) {
            $target = $SubArgs[$i+1]; $i += 2
        } else { $cmdParts += $SubArgs[$i]; $i++ }
    }
    $cmd = $cmdParts -join " "
    if ($target -and $cmd) {
        $psCmd = Convert-UnixToPowerShell $cmd
        "$psCmd`n" | wezterm cli send-text --no-paste --pane-id "$target" 2>$null | Out-Null
    }
    return ""
}

# ── session close ─────────────────────────────────────────────────────────────
function Invoke-SessionClose {
    param([string[]]$SubArgs)
    $target = ""
    $i = 0
    while ($i -lt $SubArgs.Count) {
        if ($SubArgs[$i] -in @("-s","--session") -and ($i+1) -lt $SubArgs.Count) {
            $target = $SubArgs[$i+1]; $i += 2
        } else { $i++ }
    }
    if ($target) {
        # Suppress all output/errors from wezterm (pane may not exist in unit tests)
        # Use cmd /c to fully isolate native command exit codes from PowerShell error handling
        $ErrorActionPreference = "SilentlyContinue"
        cmd /c "wezterm cli kill-pane --pane-id `"$target`" >nul 2>&1" | Out-Null
        $ErrorActionPreference = "Stop"
        if (Lock-Grid) {
            try {
                $paneEnv  = if ($env:WEZTERM_PANE) { $env:WEZTERM_PANE } else { "0" }
                $GridFile = Join-Path $StateDir "grid-panes-$paneEnv"
                if (Test-Path $GridFile) {
                    $kept = Get-Content $GridFile | Where-Object { $_.Trim() -ne $target }
                    Set-Content $GridFile ($kept -join "`n") -NoNewline -Encoding UTF8
                }
            } finally { Unlock-Grid }
        }
    }
    return "Session closed"
}

# ── Main dispatch ─────────────────────────────────────────────────────────────
function Main {
    $exitCode = 0
    $output   = ""
    $cmd0     = if ($Argv.Count -gt 0) { $Argv[0] } else { "" }

    switch ($cmd0) {
        "--version"                        { $output = "it2 0.2.3" }
        { $_ -in @("--help", "") }         { $output = "it2 - iTerm2 CLI (wezcld shim)" }
        "app" {
            $sub = if ($Argv.Count -gt 1) { $Argv[1] } else { "" }
            if ($sub -eq "version") { $output = "it2 0.2.3" }
        }
        "session" {
            $sub     = if ($Argv.Count -gt 1) { $Argv[1] } else { "" }
            $subArgs = if ($Argv.Count -gt 2) { $Argv[2..($Argv.Count-1)] } else { @() }
            switch ($sub) {
                "split"                              { $output = Invoke-SessionSplit $subArgs }
                { $_ -in @("send","send-text") }    { $output = "" }
                "run"                               { $output = Invoke-SessionRun $subArgs }
                "close"                             { $output = Invoke-SessionClose $subArgs }
                "list"                              { $output = "Session ID       Name    Title           Size    TTY" }
                { $_ -in @("focus","clear","restart") } { $output = "" }
                default                             { $output = "" }
            }
        }
        { $_ -in @("split","vsplit") } {
            $sid    = Get-NextSessionId
            $output = "Created new pane: fake-session-$sid"
        }
        { $_ -in @("send","run") }         { $output = "" }
        "ls"                               { $output = "Session ID       Name    Title           Size    TTY" }
        default                            { $output = "" }
    }

    # Always emit output here (single place), functions return strings without printing
    if ($output) { Write-Output $output }

    Write-Log -ExitCode $exitCode -Output $output -ArgvStr $ArgvStr
    exit $exitCode
}

Main
