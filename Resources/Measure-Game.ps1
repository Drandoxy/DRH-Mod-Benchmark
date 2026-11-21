param(
    [Parameter(Mandatory=$true)][int]$GameProcessId,
    [Parameter(Mandatory=$true)][string]$BenchmarkData
)
$ErrorActionPreference = 'Stop'
$folder = (Resolve-Path -LiteralPath $BenchmarkData).Path
$requestPath = Join-Path $folder 'attach.json'
if (-not (Test-Path -LiteralPath $requestPath)) { throw 'Press Start in Benchmark first.' }
$request = Get-Content -LiteralPath $requestPath -Raw | ConvertFrom-Json
if ($request.running -ne $true) { throw 'Press Start in Benchmark before attaching.' }
$game = Get-Process -Id $GameProcessId
if ($game.ProcessName -notlike '*Dungeon*Rampage*') { throw 'Select the Dungeon Rampage Haxe game PID, not the launcher or another process.' }
$identity = $game.StartTime.ToUniversalTime().Ticks
$name = $game.ProcessName
$output = Join-Path $folder 'process.json'
$tempOutput = Join-Path $folder 'process.pending.json'
$cores = [Environment]::ProcessorCount
$lastCpu = $game.TotalProcessorTime.TotalSeconds
$clock = [Diagnostics.Stopwatch]::StartNew()
$lastTime = $clock.Elapsed.TotalSeconds
$nextGpuTry = 0.0
$utf8 = [Text.UTF8Encoding]::new($false)
Write-Host "Measuring only $name (PID $GameProcessId). Ctrl+C stops. Start a new sampler for each benchmark session."
try {
    while ($true) {
        Start-Sleep -Milliseconds 1500
        $freshRequest = Get-Content -LiteralPath $requestPath -Raw | ConvertFrom-Json
        if ($freshRequest.session -ne $request.session -or $freshRequest.running -ne $true) { break }
        $game = Get-Process -Id $GameProcessId -ErrorAction Stop
        if ($game.StartTime.ToUniversalTime().Ticks -ne $identity) { break }
        $nowTime = $clock.Elapsed.TotalSeconds
        $cpuSeconds = $game.TotalProcessorTime.TotalSeconds
        $cpu = 100 * ($cpuSeconds - $lastCpu) / (($nowTime - $lastTime) * $cores)
        $lastCpu = $cpuSeconds
        $lastTime = $nowTime
        $gpu = $null
        if ($clock.Elapsed.TotalSeconds -ge $nextGpuTry) {
            try {
                # Windows per-process GPU engine counters; never whole-machine GPU utilization.
                $samples = (Get-Counter -Counter "\GPU Engine(pid_${GameProcessId}_*)\Utilization Percentage" -ErrorAction Stop).CounterSamples |
                    Where-Object { $_.InstanceName -match "^pid_${GameProcessId}_" -and $_.Status -eq 0 }
                $engines = @{}
                foreach ($sample in $samples) {
                    # Sum this process's contexts on the same physical engine, then use the busiest engine.
                    $engine = $sample.InstanceName -replace '^pid_\d+_', ''
                    if (-not $engines.ContainsKey($engine)) { $engines[$engine] = 0.0 }
                    $engines[$engine] += [double]$sample.CookedValue
                }
                if ($engines.Count -gt 0) {
                    $gpu = [Math]::Round([Math]::Min(100, ($engines.Values | Measure-Object -Maximum).Maximum), 1)
                }
            } catch { $nextGpuTry = $clock.Elapsed.TotalSeconds + 15 }
        }
        $result = @{
            session = $request.session; time = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
            pid = $GameProcessId; name = $name
            cpu = [Math]::Round([Math]::Max(0, [Math]::Min(100, $cpu)), 1)
            gpu = $gpu; ram = [Math]::Round($game.WorkingSet64 / 1MB, 1)
        } | ConvertTo-Json -Compress
        [IO.File]::WriteAllText($tempOutput, $result, $utf8)
        Move-Item -LiteralPath $tempOutput -Destination $output -Force
    }
} finally {
    # Do not remove a newer session's readings.
    if (Test-Path -LiteralPath $output) {
        try {
            $saved = Get-Content -LiteralPath $output -Raw | ConvertFrom-Json
            if ($saved.session -eq $request.session) { Remove-Item -LiteralPath $output }
        } catch {}
    }
}
