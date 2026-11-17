param(
    [string]$Delphi = $(if ($env:BDS) { $env:BDS } else { 'C:\Program Files (x86)\Embarcadero\Studio\37.0' }),
    [string[]]$RunnerArguments = @()
)

$ErrorActionPreference = 'Stop'

$Root = $PSScriptRoot
$Project = Join-Path $Root 'JS4D.Conformance.dproj'
$Executable = Join-Path $Root 'Win64\Release\JS4D.Conformance.exe'
$MSBuild = Join-Path $env:windir 'Microsoft.NET\Framework\v4.0.30319\MSBuild.exe'
$StudioVersion = Split-Path -Leaf $Delphi

$env:BDS = $Delphi
$env:BDSINCLUDE = Join-Path $Delphi 'include'
$env:BDSCOMMONDIR = Join-Path $env:PUBLIC "Documents\Embarcadero\Studio\$StudioVersion"
$env:FrameworkDir = Split-Path -Parent $MSBuild
$env:FrameworkVersion = 'v4.5'

& $MSBuild $Project /nologo /verbosity:minimal /target:Rebuild /property:Config=Release /property:Platform=Win64
if ($LASTEXITCODE -ne 0) { throw 'Build failed' }

& $Executable @RunnerArguments
exit $LASTEXITCODE
