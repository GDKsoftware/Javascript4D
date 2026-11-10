param(
    [string]$Delphi = 'C:\Program Files (x86)\Embarcadero\Studio\37.0',
    [string[]]$RunnerArguments = @()
)

$ErrorActionPreference = 'Stop'

$Root = $PSScriptRoot
$OutputDir = Join-Path $Root 'Win64\Release'
$Executable = Join-Path $OutputDir 'JS4D.Conformance.exe'

$Source = '..\Source\Core;..\Source\Lexer;..\Source\Parser;..\Source\Runtime;..\Source\API'
$SearchPath = "$Delphi\lib\Win64\release;$Source"

# Always rebuild: a run against an executable older than the sources
# produces a different pass list without any test changing.
New-Item -ItemType Directory -Force $OutputDir | Out-Null
Push-Location $Root
try {
    & "$Delphi\bin\dcc64.exe" '-$O+' '--no-config' '-B' '-Q' '-TX.exe' '-DRELEASE' `
        "-E$OutputDir" "-N0$OutputDir" "-NH$OutputDir" "-NO$OutputDir" `
        '-NSSystem;Xml;Data;Datasnap;Web;Soap' `
        "-U$SearchPath" "-I$SearchPath" "-O$SearchPath" "-R$SearchPath" `
        'JS4D.Conformance.dpr'
    if ($LASTEXITCODE -ne 0) { throw 'Build failed' }

    & $Executable @RunnerArguments
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
