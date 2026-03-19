function Convert-UnixToPowerShell {
    param([string]$cmd)
    $cmd = $cmd -replace '\\:', ':'
    $cmd = $cmd -replace '\s*&&\s*', '; '
    $envPattern = '(?:^|(?<=;\s))env\s+((?:[A-Za-z_][A-Za-z_0-9]*=[^\s]+\s+)+)(.*)'
    $cmd = [regex]::Replace($cmd, $envPattern, {
        param($m)
        $pairsRaw = $m.Groups[1].Value.Trim() -split '\s+'
        $rest     = $m.Groups[2].Value.Trim()
        $setters = ($pairsRaw | Where-Object { $_ -match '^[A-Za-z_][A-Za-z_0-9]*=' } | ForEach-Object {
            $kv = $_ -split '=', 2; $key = $kv[0]; $val = $kv[1] -replace "'","''"
            "`$env:$key='$val'"
        }) -join '; '
        $invoke = if ($rest -match "\.js'?\s*") { "& node $rest" } else { "& $rest" }
        "$setters; $invoke"
    })
    $cmd = $cmd -replace '(?:^|(?<=;\s))cd\s+', 'Set-Location '
    return $cmd.Trim()
}

$raw = "cd 'D:\temp\wezcld-main' && env CLAUDECODE=1 CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 ANTHROPIC_BASE_URL=https\://ai.leihuo.netease.com/ 'C:\Users\zhangshuai18\AppData\Roaming\npm\node_modules\@anthropic-ai\claude-code\cli.js' --agent-id test-updater\@purrfect-chasing-whale --agent-name test-updater --team-name purrfect-chasing-whale --agent-color blue --parent-session-id 8ffb2a9a-d585-4a7e-bbc8-f9eeb821dadf --agent-type general-purpose --model haiku"

$result = Convert-UnixToPowerShell $raw
Write-Host "INPUT :"
Write-Host $raw
Write-Host ""
Write-Host "OUTPUT:"
Write-Host $result
