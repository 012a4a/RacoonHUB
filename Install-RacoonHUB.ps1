$ErrorActionPreference = 'Stop'
$taskRealRoot = Join-Path $env:LOCALAPPDATA 'Real'
if (-not (Test-Path -LiteralPath $taskRealRoot -PathType Container)) {
    throw 'Install and open Real on this Windows machine first.'
}
$taskSource = Join-Path $PSScriptRoot 'RacoonHUB.luau'
$taskIcon = Join-Path $PSScriptRoot 'racoon-hub.jpg'
if (-not (Test-Path -LiteralPath $taskSource -PathType Leaf) -or -not (Test-Path -LiteralPath $taskIcon -PathType Leaf)) {
    throw 'Extract the whole RacoonHUB ZIP first. Keep the script, icon and installer together.'
}
$taskScriptFolder = Join-Path $taskRealRoot 'scripts\MCP'
$taskAssetFolder = Join-Path $taskRealRoot 'workspace\CodexPullASword'
New-Item -ItemType Directory -Path $taskScriptFolder -Force | Out-Null
New-Item -ItemType Directory -Path $taskAssetFolder -Force | Out-Null
Copy-Item -LiteralPath $taskSource -Destination (Join-Path $taskScriptFolder 'RacoonHUB.luau') -Force
Copy-Item -LiteralPath $taskIcon -Destination (Join-Path $taskAssetFolder 'racoon-hub.jpg') -Force
Write-Host 'RacoonHUB installed. Open Scripts/MCP/RacoonHUB.luau in Real while playing Pull A Sword.'

