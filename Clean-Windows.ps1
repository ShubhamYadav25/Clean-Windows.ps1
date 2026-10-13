<#
.SYNOPSIS
  Scan and clean temp files, logs, caches, crash dumps, Recycle Bin on Windows.

.EXAMPLES
  .\Clean-Windows.ps1 -DryRun                 # show what can be recovered (nothing deleted)
  .\Clean-Windows.ps1 -DryRun -Detail         # same, plus size per folder ("from where")
  .\Clean-Windows.ps1 -Select "1,3,5-6"       # clean only these numbers
  .\Clean-Windows.ps1 -All                    # clean EVERYTHING in the list
  .\Clean-Windows.ps1                         # show list, then ask what to clean
  Add -Yes to skip the confirmation prompt.

  Run from an ADMIN PowerShell for full results (system folders, Recycle Bin of all users).
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [string]$Select,
    [switch]$All,
    [switch]$Detail,
    [switch]$Yes
)

$ErrorActionPreference = 'SilentlyContinue'

# ---------- helpers ----------
function Format-Size([double]$b) {
    if ($b -ge 1GB) { return "{0:N2} GB" -f ($b / 1GB) }
    if ($b -ge 1MB) { return "{0:N0} MB" -f ($b / 1MB) }
    if ($b -ge 1KB) { return "{0:N0} KB" -f ($b / 1KB) }
    return "$([int]$b) B"
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "NOTE: Not running as Administrator - system folders will be skipped / undercounted." -ForegroundColor Yellow
}

$L  = $env:LOCALAPPDATA
$W  = $env:SystemRoot
$PD = $env:ProgramData
$drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match '^[A-Z]:\\$' }

function Browser-Paths([string]$userData) {
    # Chromium style browsers: every profile
    @(
        "$userData\*\Cache", "$userData\*\Code Cache", "$userData\*\GPUCache",
        "$userData\*\Service Worker\CacheStorage", "$userData\ShaderCache",
        "$userData\GrShaderCache"
    )
}

# ---------- categories (edit freely) ----------
# Type: Files (delete files under Paths) | RecycleBin | EventLogs
$A = $env:APPDATA
$categories = @(
    @{ Name = 'Temporary files and crash dumps'; Type = 'Files'; Paths = @(
        $env:TEMP, "$W\Temp", "$L\CrashDumps", "$W\Minidump", "$W\MEMORY.DMP", "$W\LiveKernelReports") },

    @{ Name = 'Windows error reports and DirectX shader cache'; Type = 'Files'; Paths = @(
        "$PD\Microsoft\Windows\WER", "$L\Microsoft\Windows\WER",
        "$L\D3DSCache", "$L\NVIDIA\DXCache", "$L\NVIDIA\GLCache", "$L\AMD\DxCache") },

    @{ Name = 'Google Chrome cache'; Type = 'Files'
       Paths = (Browser-Paths "$L\Google\Chrome\User Data") },

    @{ Name = 'Microsoft Edge cache'; Type = 'Files'
       Paths = (Browser-Paths "$L\Microsoft\Edge\User Data") },

    @{ Name = 'Mozilla Firefox cache'; Type = 'Files'; Paths = @(
        "$L\Mozilla\Firefox\Profiles\*\cache2", "$L\Mozilla\Firefox\Profiles\*\startupCache") },

    @{ Name = 'Other browsers cache (Brave, Opera, Vivaldi)'; Type = 'Files'
       Paths = @(
        (Browser-Paths "$L\BraveSoftware\Brave-Browser\User Data"),
        (Browser-Paths "$L\Vivaldi\User Data"),
        "$A\Opera Software\Opera Stable\Cache", "$A\Opera Software\Opera Stable\Code Cache",
        "$A\Opera Software\Opera Stable\GPUCache", "$L\Opera Software\Opera Stable\Cache") },

    @{ Name = 'Temporary Internet Files (INetCache, Java cache)'; Type = 'Files'; Paths = @(
        "$L\Microsoft\Windows\INetCache", "$env:USERPROFILE\AppData\LocalLow\Sun\Java\Deployment\cache") },

    @{ Name = 'Windows and IIS log files (CBS, DISM, setup)'; Type = 'Files'; Paths = @(
        "$W\Logs", "$W\Panther", "$W\Performance\WinSAT\DataStore",
        "$PD\Microsoft\Windows\Power Efficiency Diagnostics", "$env:SystemDrive\inetpub\logs\LogFiles") },

    @{ Name = 'Windows Update download cache'; Type = 'Files'
       Paths = @("$W\SoftwareDistribution\Download")
       Pre  = { Stop-Service wuauserv, bits -Force }
       Post = { Start-Service bits, wuauserv } },

    @{ Name = 'Delivery Optimization cache'; Type = 'Files'; Paths = @(
        "$W\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache") },

    @{ Name = 'Thumbnail and icon cache'; Type = 'Files'; Paths = @(
        "$L\Microsoft\Windows\Explorer\thumbcache_*.db", "$L\Microsoft\Windows\Explorer\iconcache_*.db", "$L\IconCache.db") },

    @{ Name = 'Prefetch (app launch cache, rebuilds itself)'; Type = 'Files'; Paths = @("$W\Prefetch") },

    @{ Name = 'Windows Defender scan history and logs'; Type = 'Files'; Paths = @(
        "$PD\Microsoft\Windows Defender\Scans\History", "$PD\Microsoft\Windows Defender\Support") },

    @{ Name = 'Microsoft Store and app package caches'; Type = 'Files'; Paths = @(
        "$L\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalCache",
        "$L\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\TempState",
        "$L\Microsoft\Windows\AppCache") },

    @{ Name = 'Microsoft Office and Teams cache'; Type = 'Files'; Paths = @(
        "$L\Microsoft\Office\16.0\OfficeFileCache", "$L\Microsoft\Office\16.0\Wef",
        "$A\Microsoft\Teams\Cache", "$A\Microsoft\Teams\Code Cache", "$A\Microsoft\Teams\GPUCache",
        "$A\Microsoft\Teams\Service Worker\CacheStorage", "$A\Microsoft\Teams\tmp",
        "$L\Packages\MSTeams_8wekyb3d8bbwe\LocalCache") },

    @{ Name = 'App caches (Discord, Slack, Spotify, VS Code, Zoom)'; Type = 'Files'; Paths = @(
        "$A\discord\Cache", "$A\discord\Code Cache", "$A\discord\GPUCache",
        "$A\Slack\Cache", "$A\Slack\Code Cache", "$A\Slack\GPUCache", "$A\Slack\Service Worker\CacheStorage",
        "$L\Spotify\Storage", "$L\Spotify\Data",
        "$A\Code\Cache", "$A\Code\CachedData", "$A\Code\Code Cache", "$A\Code\GPUCache", "$A\Code\logs",
        "$A\Zoom\logs", "$A\Zoom\data\Cache") },

    @{ Name = 'Developer package caches (npm, yarn, pip, NuGet)'; Type = 'Files'; Paths = @(
        "$L\npm-cache", "$A\npm-cache", "$L\Yarn\Cache", "$L\pip\Cache", "$L\NuGet\v3-cache", "$L\NuGet\plugins-cache") },

    @{ Name = 'Windows Event Logs (.evtx)'; Type = 'EventLogs'; Paths = @("$W\System32\winevt\Logs\*.evtx") },

    @{ Name = 'Recycle Bin (all drives)'; Type = 'RecycleBin'
       Paths = @($drives | ForEach-Object { "$($_.Root)`$Recycle.Bin" }) }
)

# ---------- scan ----------
function Scan-Category($cat) {
    $result = @()
    foreach ($p in $cat.Paths) {
        $roots = @(Resolve-Path -Path $p -ErrorAction SilentlyContinue)
        foreach ($r in $roots) {
            $item = Get-Item -LiteralPath $r.ProviderPath -Force -ErrorAction SilentlyContinue
            if ($null -eq $item) { continue }
            if ($item.PSIsContainer) {
                $files = @(Get-ChildItem -LiteralPath $item.FullName -Recurse -Force -File -ErrorAction SilentlyContinue)
            } else { $files = @($item) }
            $size = ($files | Measure-Object Length -Sum).Sum
            if (-not $size) { $size = 0 }
            $result += [pscustomobject]@{
                Path = $item.FullName; IsDir = $item.PSIsContainer; Files = $files
                Count = $files.Count; Size = [double]$size
            }
        }
    }
    $result
}

Write-Host "`nScanning... (this can take a minute)" -ForegroundColor Cyan
$i = 0
foreach ($cat in $categories) {
    $cat.Paths = @($cat.Paths | ForEach-Object { $_ })
    $i++
    $cat.Index = $i
    $cat.Scan  = @(Scan-Category $cat)
    $cat.Size  = [double](($cat.Scan | Measure-Object Size  -Sum).Sum)
    $cat.Count = [int]   (($cat.Scan | Measure-Object Count -Sum).Sum)
}

# ---------- report ----------
Write-Host ""
foreach ($cat in $categories) {
    "{0,2}. {1,-50} approx. {2,10}  ({3:N0} files)" -f $cat.Index, $cat.Name, (Format-Size $cat.Size), $cat.Count
    if ($Detail) {
        foreach ($s in ($cat.Scan | Where-Object Size -gt 0 | Sort-Object Size -Descending)) {
            "      - {0,10}  {1}" -f (Format-Size $s.Size), $s.Path
        }
    }
}
$total = ($categories | Measure-Object Size -Sum).Sum
Write-Host ("`nTOTAL recoverable: approx. {0}" -f (Format-Size $total)) -ForegroundColor Green

if ($DryRun) {
    Write-Host "`nDRY RUN - nothing was deleted." -ForegroundColor Yellow
    return
}

# ---------- choose ----------
$chosen = @()
if ($All) {
    $chosen = $categories
} else {
    if (-not $Select) {
        $Select = Read-Host "`nEnter numbers to clean (e.g. 1,3,5-6), 'all' for everything, or Enter to quit"
    }
    if ([string]::IsNullOrWhiteSpace($Select)) { Write-Host "Nothing selected."; return }
    if ($Select.Trim() -eq 'all') {
        $chosen = $categories
    } else {
        $nums = foreach ($part in ($Select -split '[,\s]+' | Where-Object { $_ })) {
            if ($part -match '^(\d+)-(\d+)$') { [int]$Matches[1]..[int]$Matches[2] }
            elseif ($part -match '^\d+$')     { [int]$part }
        }
        $chosen = $categories | Where-Object { $nums -contains $_.Index }
    }
}
if (-not $chosen) { Write-Host "No valid selection."; return }

Write-Host "`nWill clean:" -ForegroundColor Cyan
$chosen | ForEach-Object { "  {0}. {1} ({2})" -f $_.Index, $_.Name, (Format-Size $_.Size) }
if (-not $Yes) {
    $ans = Read-Host "`nType YES to delete permanently"
    if ($ans -ne 'YES') { Write-Host "Cancelled."; return }
}

# ---------- clean ----------
$freed = 0.0
foreach ($cat in $chosen) {
    Write-Host ("Cleaning {0}..." -f $cat.Name) -ForegroundColor Cyan
    if ($cat.Pre) { & $cat.Pre }
    $before = $cat.Size

    switch ($cat.Type) {
        'RecycleBin' { Clear-RecycleBin -Force -ErrorAction SilentlyContinue }
        'EventLogs'  { wevtutil el | ForEach-Object { wevtutil cl "$_" 2>$null } }
        default {
            foreach ($s in $cat.Scan) {
                foreach ($f in $s.Files) {
                    Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue
                }
                if ($s.IsDir) {   # remove empty sub-folders, keep the root folder
                    Get-ChildItem -LiteralPath $s.Path -Recurse -Force -Directory -ErrorAction SilentlyContinue |
                        Sort-Object { $_.FullName.Length } -Descending |
                        Where-Object { -not (Get-ChildItem -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue) } |
                        Remove-Item -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }

    if ($cat.Post) { & $cat.Post }

    # measure what actually went away (files in use are skipped by Windows)
    $left = [double](($(Scan-Category $cat) | Measure-Object Size -Sum).Sum)
    $got  = [math]::Max(0, $before - $left)
    $freed += $got
    "   freed approx. {0}" -f (Format-Size $got)
}

Write-Host ("`nDONE. Total freed: approx. {0}" -f (Format-Size $freed)) -ForegroundColor Green
Write-Host "Files in use were skipped; close browsers and run again to get the rest."
