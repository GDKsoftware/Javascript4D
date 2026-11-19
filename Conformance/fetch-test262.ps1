param(
    [string]$Destination = (Join-Path $PSScriptRoot 'test262')
)

$ErrorActionPreference = 'Stop'

$PinnedCommit = 'e4fbf57745c6aae3d1f12f181ecef78b1665d812'
$Repository = 'https://github.com/tc39/test262.git'

$GitOptions = @('-c', 'core.longpaths=true', '-c', 'core.autocrlf=false')

if (-not (Test-Path (Join-Path $Destination '.git'))) {
    New-Item -ItemType Directory -Force $Destination | Out-Null
    git -C $Destination init --quiet
    if ($LASTEXITCODE -ne 0) { throw 'git init failed' }

    git -C $Destination remote add origin $Repository
    if ($LASTEXITCODE -ne 0) { throw 'git remote add failed' }
}

$CurrentCommit = git -C $Destination rev-parse --verify --quiet HEAD
if ($CurrentCommit -eq $PinnedCommit) {
    Write-Host "test262 is already at $PinnedCommit"
    exit 0
}

Write-Host "Fetching test262 at $PinnedCommit"
git @GitOptions -C $Destination fetch --depth 1 --quiet origin $PinnedCommit
if ($LASTEXITCODE -ne 0) { throw 'git fetch failed' }

git @GitOptions -C $Destination checkout --quiet --force $PinnedCommit
if ($LASTEXITCODE -ne 0) { throw 'git checkout failed' }

Write-Host "test262 is at $PinnedCommit in $Destination"
