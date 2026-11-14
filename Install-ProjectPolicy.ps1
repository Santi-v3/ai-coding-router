[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Project
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$routerRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectPath = (Resolve-Path -LiteralPath $Project).Path
$templateRoot = Join-Path $routerRoot 'templates'

foreach ($file in @('AGENTS.md', 'CLAUDE.md')) {
    $source = Join-Path $templateRoot $file
    $target = Join-Path $projectPath $file
    if (Test-Path -LiteralPath $target) {
        Write-Warning "$file existiert bereits und wurde nicht ueberschrieben: $target"
        continue
    }
    Copy-Item -LiteralPath $source -Destination $target
    Write-Host "Installiert: $target"
}

$gitIgnore = Join-Path $projectPath '.gitignore'
if (Test-Path -LiteralPath $gitIgnore) {
    $content = Get-Content -LiteralPath $gitIgnore -Raw
    if ($content -notmatch '(?m)^\.agent-runs/$') {
        Add-Content -LiteralPath $gitIgnore -Value "`n.agent-runs/"
        Write-Host 'Ergaenzt: .agent-runs/ in .gitignore'
    }
}
