# it2.ps1 - iTerm2 CLI shim for wezcld (Windows PowerShell version)
# Compatible with Windows PowerShell 5.1+ and PowerShell 7+
# NOTE: No param() block - we use $args directly so --version is not swallowed by PS parameter binding

$ErrorActionPreference = "SilentlyContinue"   # never let internal errors bubble up to Claude Code

# All raw arguments as string array
$Argv = @($args | ForEach-Object { "$_" })

# ── State directory ───────────────────────────────────────────────────────────
$StateDir = if ($env:WEZCLD_STATE) { $env:WEZCLD_STATE } else {
    Join-Path $env:USERPROFILE ".local\state\wezcld"
}
$null = New-Item -ItemType Directory -Path $StateDir -Force -ErrorAction SilentlyContinue

$LogFile = Join-Path $StateDir "it2-calls.log"

# ── File-lock based grid I/O ──────────────────────────────────────────────────
# Uses an exclusive .lock file (FileShare.None) with retries.
# Much more reliable than Named Mutex on Windows PS5 across multiple processes.

function Invoke-WithFileLock {
    param(
        [string]$LockPath,
        [scriptblock]$Action,
        [int]$TimeoutMs = 8000,
        [int]$RetryMs   = 50
    )
    $deadline = [datetime]::UtcNow.AddMilliseconds($TimeoutMs)
    $fs = $null
    while ([datetime]::UtcNow -lt $deadline) {
        try {
            $fs = [System.IO.File]::Open(
                $LockPath,
                [System.IO.FileMode]::OpenOrCreate,
                [System.IO.FileAccess]::ReadWrite,
                [System.IO.FileShare]::None
            )
            # Got the lock - run the action
            try { & $Action } finally { $fs.Close(); $fs.Dispose() }
            return
        } catch [System.IO.IOException] {
            if ($fs) { try { $fs.Dispose() } catch {} ; $fs = $null }
            Start-Sleep -Milliseconds $RetryMs
        } catch {
            if ($fs) { try { $fs.Dispose() } catch {} ; $fs = $null }
            break
        }
    }
    # Timed out - run anyway without lock (better than failing silently)
    & $Action
}

function Read-GridFile {
    param([string]$GridFile)
    if (-not (Test-Path $GridFile)) { return @() }
    $lines = Get-Content $GridFile -ErrorAction SilentlyContinue
    if (-not $lines) { return @() }
    return @($lines | Where-Object { $_.Trim() -ne "" })
}

function Write-GridFile {
    param([string]$GridFile, [string[]]$Lines)
    $content = ($Lines | Where-Object { $_.Trim() -ne "" }) -join "`n"
    # Direct write - we already hold the .lock file so no concurrent writer possible
    [System.IO.File]::WriteAllText($GridFile, $content, [System.Text.Encoding]::UTF8)
}

# ── Logging ───────────────────────────────────────────────────────────────────
function Write-Log {
    param([int]$ExitCode, [string]$Output, [string]$ArgvStr)
    try {
        $ts   = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        $line = "[$ts] ARGV: $ArgvStr | EXIT: $ExitCode | STDOUT: $Output`n"
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($line)
        $logFs = [System.IO.File]::Open($LogFile,
            [System.IO.FileMode]::Append,
            [System.IO.FileAccess]::Write,
            [System.IO.FileShare]::ReadWrite)
        try { $logFs.Write($bytes, 0, $bytes.Length) } finally { $logFs.Close() }
    } catch {}
}

# Build ARGV string for logging
$ArgvStr = "it2 " + ($Argv | ForEach-Object {
    $s = $_ -replace "`n"," "
    if ($s -match '[ "|]') { "'$s'" } else { $s }
} | Where-Object { $_ -ne "" }) -join " "

# ── Prune stale panes (called inside lock) ────────────────────────────────────
function Get-LivePaneIds {
    try {
        $out = wezterm cli list 2>$null
        if (-not $out) { return $null }
        return @($out | Select-Object -Skip 1 | ForEach-Object {
            $cols = ($_ -split '\s+') | Where-Object { $_ }
            if ($cols.Count -gt 2) { $cols[2] }
        } | Where-Object { $_ })
    } catch { return $null }
}

# ── session split ─────────────────────────────────────────────────────────────
function Invoke-SessionSplit {
    $MAX_COLS = 3
    $paneEnv  = if ($env:WEZTERM_PANE) { $env:WEZTERM_PANE } else { "0" }
    $GridFile = Join-Path $StateDir "grid-panes-$paneEnv"
    $LockFile = "$GridFile.lock"

    # All grid work done inside the file lock
    # We use a .NET List to pass results out of the scriptblock (scriptblock has its own scope)
    $resultBox = [System.Collections.Generic.List[string]]::new()

    Invoke-WithFileLock -LockPath $LockFile -Action {
        # Read current panes
        $panes = Read-GridFile $GridFile

        # Prune stale panes
        $live = Get-LivePaneIds
        if ($live) {
            $panes = @($panes | Where-Object { $live -contains $_.Trim() })
        }

        $agentCount = $panes.Count
        $row = [math]::Floor($agentCount / $MAX_COLS)
        $col = $agentCount % $MAX_COLS
        $newPaneId = $null

        if ($row -eq 0 -and $col -eq 0) {
            # First agent: split upward from leader (leader stays at bottom 35%)
            $newPaneId = (wezterm cli split-pane --top --percent 65 --pane-id "$paneEnv" 2>$null) |
                         Select-Object -First 1
        } elseif ($row -eq 0) {
            # Fill first row: split right from the previous pane
            $prevPane  = $panes[-1].Trim()
            $remaining = $MAX_COLS - $col
            $pct       = [math]::Floor((100 * $remaining + ($remaining + 1) / 2) / ($remaining + 1))
            $newPaneId = (wezterm cli split-pane --right --percent $pct --pane-id "$prevPane" 2>$null) |
                         Select-Object -First 1
        } else {
            # New row: split downward from the pane in the same column above
            $paneAbove = $panes[$agentCount - $MAX_COLS].Trim()
            $newPaneId = (wezterm cli split-pane --bottom --pane-id "$paneAbove" 2>$null) |
                         Select-Object -First 1
        }

        if ($newPaneId) {
            $newId = $newPaneId.Trim()
            $panes += $newId
            Write-GridFile -GridFile $GridFile -Lines $panes
            wezterm cli activate-pane --pane-id "$paneEnv" 2>$null | Out-Null
            $resultBox.Add("Created new pane: $newId")   # pass result out via reference type
        }
    }

    if ($resultBox.Count -gt 0) { return $resultBox[0] }
    return ""
}

# ── Convert Unix shell command → PowerShell ───────────────────────────────────
function Convert-UnixToPowerShell {
    param([string]$cmd)
    # Unescape backslash-escaped colons (https\:// → https://)
    $cmd = $cmd -replace '\\:', ':'
    # Replace && with ;
    $cmd = $cmd -replace '\s*&&\s*', '; '
    # Convert "env K=V ... <exe>" block
    $envPattern = '(?:^|(?<=;\s))env\s+((?:[A-Za-z_][A-Za-z_0-9]*=[^\s]+\s+)+)(.*)'
    $cmd = [regex]::Replace($cmd, $envPattern, {
        param($m)
        $pairsRaw = $m.Groups[1].Value.Trim() -split '\s+'
        $rest     = $m.Groups[2].Value.Trim()
        $setters  = ($pairsRaw | Where-Object { $_ -match '^[A-Za-z_][A-Za-z_0-9]*=' } | ForEach-Object {
            $kv = $_ -split '=', 2
            "`$env:$($kv[0])='$($kv[1] -replace "'","''")'"
        }) -join '; '
        $invoke = if ($rest -match "\.js'?\s*") { "& node $rest" } else { "& $rest" }
        "$setters; $invoke"
    })
    # cd → Set-Location
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
        cmd /c "wezterm cli kill-pane --pane-id `"$target`" >nul 2>&1"
        $paneEnv  = if ($env:WEZTERM_PANE) { $env:WEZTERM_PANE } else { "0" }
        $GridFile = Join-Path $StateDir "grid-panes-$paneEnv"
        $LockFile = "$GridFile.lock"
        Invoke-WithFileLock -LockPath $LockFile -Action {
            $panes = Read-GridFile $GridFile
            $panes = @($panes | Where-Object { $_.Trim() -ne $target })
            Write-GridFile -GridFile $GridFile -Lines $panes
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
        "--version"                      { $output = "it2 0.2.3" }
        { $_ -in @("--help", "") }       { $output = "it2 - iTerm2 CLI (wezcld shim)" }
        "app" {
            if ($Argv.Count -gt 1 -and $Argv[1] -eq "version") { $output = "it2 0.2.3" }
        }
        "session" {
            $sub     = if ($Argv.Count -gt 1) { $Argv[1] } else { "" }
            $subArgs = if ($Argv.Count -gt 2) { $Argv[2..($Argv.Count-1)] } else { @() }
            switch ($sub) {
                "split"                              { $output = Invoke-SessionSplit }
                { $_ -in @("send","send-text") }    { $output = "" }
                "run"                               { $output = Invoke-SessionRun $subArgs }
                "close"                             { $output = Invoke-SessionClose $subArgs }
                "list"                              { $output = "Session ID       Name    Title           Size    TTY" }
                { $_ -in @("focus","clear","restart") } { $output = "" }
                default                             { $output = "" }
            }
        }
        { $_ -in @("split","vsplit") }   { $output = Invoke-SessionSplit }
        { $_ -in @("send","run") }       { $output = "" }
        "ls"                             { $output = "Session ID       Name    Title           Size    TTY" }
        default                          { $output = "" }
    }

    if ($output) { Write-Output $output }
    Write-Log -ExitCode $exitCode -Output $output -ArgvStr $ArgvStr
    exit 0   # always exit 0 - never fail Claude Code
}

Main
