# integration-test.ps1 - wezcld Windows PowerShell integration tests
# Compatible with Windows PowerShell 5.1+ and PowerShell 7+

$ErrorActionPreference = "Stop"

# Detect powershell executable (pwsh for PS7+, powershell for PS5)
$PS_EXE = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }

$TESTS  = 0
$PASSED = 0
$FAILED = 0

function Pass { param($msg) $script:TESTS++; $script:PASSED++; Write-Host "  + $msg" -ForegroundColor Green }
function Fail { param($msg,$reason) $script:TESTS++; $script:FAILED++; Write-Host "  x ${msg}: $reason" -ForegroundColor Red }

# Resolve paths
$ScriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$ShimDir   = Split-Path $ScriptDir -Parent
$It2Script = Join-Path $ShimDir "bin\it2.ps1"
$WezcldScript = Join-Path $ShimDir "bin\wezcld.ps1"

# Setup temp state directory
$TempState = Join-Path ([System.IO.Path]::GetTempPath()) "wezcld-test-$PID"
New-Item -ItemType Directory -Path $TempState -Force | Out-Null
$env:WEZCLD_STATE = $TempState

# Cleanup on exit
try {

Write-Host ""
Write-Host "Testing wezcld - it2 shim (Windows PowerShell)" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Helper: run it2.ps1 and capture stdout
function Invoke-It2 {
    param([string[]]$ArgList)
    $result = & $PS_EXE -NoProfile -ExecutionPolicy Bypass -File $It2Script @ArgList 2>&1
    return ($result | Out-String).Trim()
}

# ── Group 1: Unit tests ───────────────────────────────────────────────────────
Write-Host "Group 1: Unit tests"
Write-Host "-------------------"

# Test 1: it2 --version
$out = Invoke-It2 @("--version")
if ($out -eq "it2 0.2.3") { Pass "it2 --version outputs 'it2 0.2.3'" }
else { Fail "it2 --version outputs 'it2 0.2.3'" "got '$out'" }

# Test 2: it2 app version
$out = Invoke-It2 @("app","version")
if ($out -eq "it2 0.2.3") { Pass "it2 app version outputs 'it2 0.2.3'" }
else { Fail "it2 app version outputs 'it2 0.2.3'" "got '$out'" }

# Test 3: it2 session send exits 0
$exitCode = 0
try { Invoke-It2 @("session","send","--session","fake-session-0","hello") | Out-Null }
catch { $exitCode = 1 }
if ($exitCode -eq 0) { Pass "it2 session send exits 0" }
else { Fail "it2 session send exits 0" "non-zero exit" }

# Test 4: it2 session close outputs "Session closed"
$out = Invoke-It2 @("session","close","--session","fake-session-0")
if ($out -eq "Session closed") { Pass "it2 session close outputs 'Session closed'" }
else { Fail "it2 session close outputs 'Session closed'" "got '$out'" }

# Test 5: it2 session list outputs table header
$out = Invoke-It2 @("session","list")
if ($out -match "Session ID") { Pass "it2 session list outputs table header" }
else { Fail "it2 session list outputs table header" "got '$out'" }

# Test 6: it2 --help outputs help text
$out = Invoke-It2 @("--help")
if ($out -match "it2 - iTerm2 CLI \(wezcld shim\)") { Pass "it2 --help outputs help text" }
else { Fail "it2 --help outputs help text" "got '$out'" }

# Test 7: it2 ls outputs table header
$out = Invoke-It2 @("ls")
if ($out -match "Session ID") { Pass "it2 ls alias outputs table header" }
else { Fail "it2 ls alias outputs table header" "got '$out'" }

# Test 8: it2 send exits 0
$exitCode = 0
try { Invoke-It2 @("send","hello") | Out-Null }
catch { $exitCode = 1 }
if ($exitCode -eq 0) { Pass "it2 send shortcut exits 0" }
else { Fail "it2 send shortcut exits 0" "non-zero exit" }

# Test 9: it2 run exits 0
$exitCode = 0
try { Invoke-It2 @("run","ls") | Out-Null }
catch { $exitCode = 1 }
if ($exitCode -eq 0) { Pass "it2 run shortcut exits 0" }
else { Fail "it2 run shortcut exits 0" "non-zero exit" }

# Test 10: unknown command exits 0
$exitCode = 0
try { Invoke-It2 @("unknown-command","--some-flag") | Out-Null }
catch { $exitCode = 1 }
if ($exitCode -eq 0) { Pass "unknown commands exit 0" }
else { Fail "unknown commands exit 0" "non-zero exit" }

# Test 11: log file exists
$logFile = Join-Path $TempState "it2-calls.log"
if (Test-Path $logFile) { Pass "log file exists at `$WEZCLD_STATE/it2-calls.log" }
else { Fail "log file exists" "file not found: $logFile" }

# Test 12: log file has entries
$logLines = (Get-Content $logFile -ErrorAction SilentlyContinue | Measure-Object -Line).Lines
if ($logLines -gt 0) { Pass "log file has entries" }
else { Fail "log file has entries" "file is empty" }

# Test 13: log entries have [timestamp] ARGV: format
$logContent = Get-Content $logFile -Raw -ErrorAction SilentlyContinue
if ($logContent -match '\[\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\] ARGV:') {
    Pass "log entries have [timestamp] ARGV: format"
} else {
    Fail "log entries have [timestamp] ARGV: format" "format mismatch"
}

# Test 14: wezcld --version
$out = (& $PS_EXE -NoProfile -ExecutionPolicy Bypass -File $WezcldScript "--version" 2>&1 | Out-String).Trim()
if ($out -eq "wezcld dev") { Pass "wezcld --version outputs 'wezcld dev'" }
else { Fail "wezcld --version outputs 'wezcld dev'" "got '$out'" }

# Test 15: wezcld -v
$out = (& $PS_EXE -NoProfile -ExecutionPolicy Bypass -File $WezcldScript "-v" 2>&1 | Out-String).Trim()
if ($out -eq "wezcld dev") { Pass "wezcld -v outputs 'wezcld dev'" }
else { Fail "wezcld -v outputs 'wezcld dev'" "got '$out'" }

Write-Host ""

# ── Group 2: Live WezTerm tests (conditional) ─────────────────────────────────
if ($env:TERM_PROGRAM -eq "WezTerm") {
    Write-Host "Group 2: Live WezTerm grid layout tests"
    Write-Host "----------------------------------------"

    # Clean state
    $GridFile = Join-Path $TempState "grid-panes-$($env:WEZTERM_PANE)"
    if (Test-Path $GridFile) { Remove-Item $GridFile -Force }

    # Test 20: First split
    $out1 = Invoke-It2 @("session","split","-v")
    $pane1 = $out1 -replace "Created new pane: ",""
    if ($pane1 -match "^\d+$") { Pass "first split returns valid pane ID ($pane1)" }
    else { Fail "first split returns valid pane ID" "got '$out1'" }

    # Test 21: grid-panes has 1 entry
    $count = (Get-Content $GridFile -ErrorAction SilentlyContinue | Where-Object { $_.Trim() } | Measure-Object).Count
    if ($count -eq 1) { Pass "grid-panes has 1 entry after first split" }
    else { Fail "grid-panes has 1 entry" "got $count" }

    # Test 22: Second split
    $out2 = Invoke-It2 @("session","split","-s",$pane1)
    $pane2 = $out2 -replace "Created new pane: ",""
    if ($pane2 -match "^\d+$") { Pass "second split returns valid pane ID ($pane2)" }
    else { Fail "second split returns valid pane ID" "got '$out2'" }

    # Test 23: Third split
    $out3 = Invoke-It2 @("session","split","-s",$pane2)
    $pane3 = $out3 -replace "Created new pane: ",""
    if ($pane3 -match "^\d+$") { Pass "third split returns valid pane ID ($pane3)" }
    else { Fail "third split returns valid pane ID" "got '$out3'" }

    # Test 24: Fourth split (new row)
    $out4 = Invoke-It2 @("session","split","-s",$pane3)
    $pane4 = $out4 -replace "Created new pane: ",""
    if ($pane4 -match "^\d+$") { Pass "fourth split (new row) returns valid pane ID ($pane4)" }
    else { Fail "fourth split (new row) returns valid pane ID" "got '$out4'" }

    # Test 25: grid-panes has 4 entries
    $count = (Get-Content $GridFile | Where-Object { $_.Trim() } | Measure-Object).Count
    if ($count -eq 4) { Pass "grid-panes has 4 entries after 4 splits" }
    else { Fail "grid-panes has 4 entries" "got $count" }

    # Test 26: session close removes from grid
    Invoke-It2 @("session","close","-s",$pane4) | Out-Null
    $count = (Get-Content $GridFile | Where-Object { $_.Trim() } | Measure-Object).Count
    if ($count -eq 3) { Pass "session close removes pane from grid ($count entries)" }
    else { Fail "session close removes pane from grid" "got $count entries" }

    # Test 27: session run sends command
    $exitCode = 0
    try { Invoke-It2 @("session","run","-s",$pane1,"echo test") | Out-Null }
    catch { $exitCode = 1 }
    if ($exitCode -eq 0) { Pass "session run sends command to target pane" }
    else { Fail "session run sends command to target pane" "non-zero exit" }

    # Cleanup panes
    foreach ($p in @($pane1, $pane2, $pane3)) {
        wezterm cli kill-pane --pane-id $p 2>$null | Out-Null
    }

    Write-Host ""
} else {
    Write-Host "Group 2: Live WezTerm grid layout tests (SKIPPED - not in WezTerm)" -ForegroundColor DarkGray
    Write-Host ""
}

} finally {
    # Cleanup temp state
    Remove-Item $TempState -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "Results: $PASSED/$TESTS passed" -ForegroundColor $(if ($FAILED -gt 0) { "Red" } else { "Green" })
Write-Host ""

if ($FAILED -gt 0) { exit 1 } else { exit 0 }
