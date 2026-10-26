param(
    [Parameter(Position = 0)]
    [ValidateSet('snapshot', 'restore', 'lock', 'unlock', 'status', 'watch')]
    [string]$Action = 'status',
    [int]$IntervalSeconds = 8
)

$ErrorActionPreference = 'Stop'
$ProtectDir = $PSScriptRoot
$Root = Split-Path -Parent $ProtectDir
$SnapshotDir = Join-Path $ProtectDir 'snapshot'
$ListFile = Join-Path $ProtectDir 'files.txt'
$Stamp = { (Get-Date).ToString('HH:mm:ss') }

function Get-ProtectedFiles {
    if (-not (Test-Path -LiteralPath $ListFile)) { throw "files.txt not found: $ListFile" }
    Get-Content -LiteralPath $ListFile -Encoding UTF8 |
        Where-Object { $_ -and -not $_.TrimStart().StartsWith('#') } |
        ForEach-Object { $_.Trim() }
}

function Get-LivePath([string]$rel) { Join-Path $Root $rel }
function Get-SnapPath([string]$rel) { Join-Path $SnapshotDir $rel }

function Get-Hash([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return '' }
    (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
}

function Clear-ReadOnly([string]$path) {
    if (Test-Path -LiteralPath $path) {
        $item = Get-Item -LiteralPath $path -Force
        if ($item.IsReadOnly) { $item.IsReadOnly = $false }
    }
}

function Set-FileLock([string]$rel, [bool]$locked) {
    $live = Get-LivePath $rel
    if (Test-Path -LiteralPath $live) {
        $item = Get-Item -LiteralPath $live -Force
        if ($item.IsReadOnly -ne $locked) { $item.IsReadOnly = $locked }
    }
}

function Copy-Into([string]$from, [string]$to) {
    $dir = Split-Path -Parent $to
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Clear-ReadOnly $to
    Copy-Item -LiteralPath $from -Destination $to -Force
}

function Do-Snapshot {
    foreach ($rel in Get-ProtectedFiles) {
        $live = Get-LivePath $rel
        if (-not (Test-Path -LiteralPath $live)) {
            Write-Host ("[{0}] MISSING  {1}" -f (& $Stamp), $rel) -ForegroundColor Yellow
            continue
        }
        Copy-Into $live (Get-SnapPath $rel)
        Write-Host ("[{0}] saved    {1}" -f (& $Stamp), $rel) -ForegroundColor DarkGray
    }
    Write-Host "snapshot updated: $SnapshotDir" -ForegroundColor Green
}

function Do-Restore([switch]$Quiet, [switch]$Relock) {
    $changed = 0
    foreach ($rel in Get-ProtectedFiles) {
        $live = Get-LivePath $rel
        $snap = Get-SnapPath $rel
        if (-not (Test-Path -LiteralPath $snap)) { continue }
        $liveHash = Get-Hash $live
        $snapHash = Get-Hash $snap
        if ($liveHash -eq $snapHash) { continue }
        $wasLocked = (Test-Path -LiteralPath $live) -and (Get-Item -LiteralPath $live -Force).IsReadOnly
        Copy-Into $snap $live
        if ($wasLocked -or $Relock) { Set-FileLock $rel $true }
        $changed++
        if (-not $Quiet) {
            $why = if ($liveHash -eq '') { 'restored (was deleted)' } else { 'restored (was modified)' }
            Write-Host ("[{0}] {1}: {2}" -f (& $Stamp), $why, $rel) -ForegroundColor Cyan
        }
    }
    if ($changed -gt 0) {
        Write-Host ("[{0}] {1} file(s) restored from protected snapshot" -f (& $Stamp), $changed) -ForegroundColor Green
    } elseif (-not $Quiet) {
        Write-Host "all protected files match the snapshot" -ForegroundColor Green
    }
    return $changed
}

function Do-Lock([bool]$locked) {
    foreach ($rel in Get-ProtectedFiles) {
        Set-FileLock $rel $locked
        $state = if ($locked) { 'read-only' } else { 'writable' }
        Write-Host ("[{0}] {1}: {2}" -f (& $Stamp), $state, $rel) -ForegroundColor DarkGray
    }
    $word = if ($locked) { 'locked (another editor can no longer overwrite these files)' } else { 'unlocked' }
    Write-Host $word -ForegroundColor Green
}

function Do-Status {
    $drift = 0
    foreach ($rel in Get-ProtectedFiles) {
        $liveHash = Get-Hash (Get-LivePath $rel)
        $snapHash = Get-Hash (Get-SnapPath $rel)
        $live = Get-LivePath $rel
        $locked = (Test-Path -LiteralPath $live) -and (Get-Item -LiteralPath $live -Force).IsReadOnly
        $state = if ($liveHash -eq '') { 'MISSING' } elseif ($liveHash -ne $snapHash) { 'CHANGED' } else { 'ok' }
        if ($state -ne 'ok') { $drift++ }
        Write-Host ("{0,-8} {1,-10} {2}" -f $state, ($(if ($locked) { 'read-only' } else { 'writable' })), $rel)
    }
    Write-Host ("visible changes vs snapshot: {0}" -f $drift) -ForegroundColor Green
}

switch ($Action) {
    'snapshot' { Do-Snapshot }
    'restore' { Do-Restore | Out-Null }
    'lock' { Do-Lock $true }
    'unlock' { Do-Lock $false }
    'status' { Do-Status }
    'watch' {
        Write-Host "watching protected files every $IntervalSeconds s (Ctrl+C to stop)" -ForegroundColor Green
        while ($true) { Do-Restore -Quiet -Relock | Out-Null; Start-Sleep -Seconds $IntervalSeconds }
    }
}
