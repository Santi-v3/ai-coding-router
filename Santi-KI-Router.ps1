[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Task,

    [Parameter(Mandatory = $true)]
    [string]$Project,

    [ValidateSet('auto', 'simple', 'medium', 'hard', 'critical')]
    [string]$Tier = 'auto',

    [ValidateSet('auto', 'free', 'claude', 'codex')]
    [string]$MainAI = 'auto',

    [ValidateSet('preview', 'plan', 'apply')]
    [string]$Mode = 'preview',

    [switch]$Review
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$routerRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$config = Get-Content -LiteralPath (Join-Path $routerRoot 'router.config.json') -Raw | ConvertFrom-Json
$projectPath = (Resolve-Path -LiteralPath $Project).Path

function Get-NativeCommand {
    param([Parameter(Mandatory = $true)][string]$Name)

    foreach ($candidate in @("$Name.cmd", "$Name.exe", $Name)) {
        $command = Get-Command $candidate -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $command) {
            return $command.Source
        }
    }

    return $null
}

function Test-TaskPolicy {
    param([Parameter(Mandatory = $true)][string]$Text)

    $blockedPatterns = @(
        '(?i)crack\w*\s+(license|activation)',
        '(?i)bypass\w*\s+(license|activation|subscription)',
        '(?i)remove\w*\s+(license check|activation check|paywall)',
        '(?i)steal\w*\s+(token|credential|password)'
    )
    foreach ($pattern in $blockedPatterns) {
        if ($Text -match $pattern) {
            throw 'Die Aufgabe wurde durch die Sicherheitsregel gestoppt (Lizenz-/Zugangsumgehung).'
        }
    }

    if ($Text -match '(?i)(sk-[a-z0-9_-]{16,}|api[_ -]?key\s*[:=]\s*\S+|password\s*[:=]\s*\S+)') {
        throw 'Die Aufgabe scheint ein Geheimnis zu enthalten. Entferne Schlüssel oder Passwörter aus dem Prompt.'
    }
}

function Test-KeywordGroup {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)]$Keywords
    )

    foreach ($keyword in $Keywords) {
        if ($Text.IndexOf([string]$keyword, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
            return $true
        }
    }
    return $false
}

function Get-TaskTier {
    param([Parameter(Mandatory = $true)][string]$Text)

    if (Test-KeywordGroup -Text $Text -Keywords $config.classification.critical) { return 'critical' }
    if (Test-KeywordGroup -Text $Text -Keywords $config.classification.hard) { return 'hard' }
    if (Test-KeywordGroup -Text $Text -Keywords $config.classification.medium) { return 'medium' }
    if ($Text.Length -gt 700 -or ($Text -split "`n").Count -gt 12) { return 'medium' }
    return 'simple'
}

function Get-FreeModel {
    param(
        [Parameter(Mandatory = $true)][string]$RequestedTier,
        [Parameter(Mandatory = $true)][string]$OpenCodeCommand
    )

    $available = @(& $OpenCodeCommand models 2>$null)
    $candidateTier = if ($RequestedTier -eq 'critical') { 'hard' } else { $RequestedTier }
    foreach ($candidate in $config.freeModels.$candidateTier) {
        if ($available -contains [string]$candidate) {
            return [string]$candidate
        }
    }

    throw "Kein konfiguriertes Gratis-Modell fuer Tier '$candidateTier' ist aktuell verfuegbar."
}

function Get-Route {
    param(
        [Parameter(Mandatory = $true)][string]$RequestedTier,
        [Parameter(Mandatory = $true)][string]$RequestedMain,
        [Parameter(Mandatory = $true)]$Commands
    )

    $primary = $RequestedMain
    if ($primary -eq 'auto') {
        if ($RequestedTier -in @('simple', 'medium')) {
            $primary = 'free'
        } elseif ($null -ne $Commands.Claude) {
            $primary = 'claude'
        } elseif ($null -ne $Commands.Codex) {
            $primary = 'codex'
        } else {
            $primary = 'free'
        }
    }

    $reviewer = 'none'
    if ($RequestedTier -eq 'medium') {
        $reviewer = 'free'
    } elseif ($RequestedTier -in @('hard', 'critical')) {
        if ($primary -eq 'claude' -and $null -ne $Commands.Codex) { $reviewer = 'codex' }
        elseif ($primary -eq 'codex' -and $null -ne $Commands.Claude) { $reviewer = 'claude' }
        elseif ($null -ne $Commands.Codex) { $reviewer = 'codex' }
        elseif ($null -ne $Commands.Claude) { $reviewer = 'claude' }
        else { $reviewer = 'free' }
    }

    if ($Review -and $reviewer -eq 'none') {
        $reviewer = if ($primary -eq 'free') { 'free' } elseif ($primary -eq 'claude') { 'codex' } else { 'claude' }
    }

    [pscustomobject]@{ Primary = $primary; Reviewer = $reviewer }
}

function Invoke-Logged {
    param(
        [Parameter(Mandatory = $true)][string]$Executable,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$LogPath
    )

    & $Executable @Arguments 2>&1 |
        Tee-Object -FilePath $LogPath |
        ForEach-Object { Write-Host $_ }
    $nativeExitCode = $LASTEXITCODE
    return $nativeExitCode
}

function Invoke-Provider {
    param(
        [Parameter(Mandatory = $true)][string]$Provider,
        [Parameter(Mandatory = $true)][string]$RunMode,
        [Parameter(Mandatory = $true)][string]$Prompt,
        [Parameter(Mandatory = $true)][string]$LogPath,
        [string]$FreeModel
    )

    switch ($Provider) {
        'free' {
            if ($null -eq $commands.OpenCode) { throw 'OpenCode wurde nicht gefunden.' }
            $agent = if ($RunMode -eq 'apply') { 'build' } else { 'plan' }
            $args = @('run', '--model', $FreeModel, '--agent', $agent, '--format', 'json', '--archived', '--title', 'Santi KI Router', $Prompt)
            if ($RunMode -eq 'apply') { $args = @('run', '--model', $FreeModel, '--agent', $agent, '--format', 'json', '--archived', '--auto', '--title', 'Santi KI Router', $Prompt) }
            return Invoke-Logged -Executable $commands.OpenCode -Arguments $args -LogPath $LogPath
        }
        'claude' {
            if ($null -eq $commands.Claude) { throw 'Claude Code wurde nicht gefunden.' }
            $permissionMode = if ($RunMode -eq 'apply') { 'acceptEdits' } else { 'plan' }
            return Invoke-Logged -Executable $commands.Claude -Arguments @('-p', '--permission-mode', $permissionMode, '--model', 'sonnet', '--output-format', 'json', $Prompt) -LogPath $LogPath
        }
        'codex' {
            if ($null -eq $commands.Codex) { throw 'Codex wurde nicht gefunden.' }
            $sandbox = if ($RunMode -eq 'apply') { 'workspace-write' } else { 'read-only' }
            return Invoke-Logged -Executable $commands.Codex -Arguments @('exec', '-C', $projectPath, '--sandbox', $sandbox, '--ephemeral', '--skip-git-repo-check', $Prompt) -LogPath $LogPath
        }
        default { throw "Unbekannter Provider: $Provider" }
    }
}

function Invoke-Verification {
    param([Parameter(Mandatory = $true)][string]$LogPath)

    $dotnetProject = Get-ChildItem -LiteralPath $projectPath -File | Where-Object { $_.Extension -in @('.sln', '.csproj') } | Select-Object -First 1
    if ($null -ne $dotnetProject) {
        $localDotnet = Join-Path $projectPath '.tools\dotnet8\dotnet.exe'
        $dotnet = if (Test-Path -LiteralPath $localDotnet) { $localDotnet } else { Get-NativeCommand -Name 'dotnet' }
        if ($null -eq $dotnet) { throw 'dotnet wurde fuer die Verifikation nicht gefunden.' }
        return Invoke-Logged -Executable $dotnet -Arguments @('build', $dotnetProject.FullName, '--nologo') -LogPath $LogPath
    }

    $packageJson = Join-Path $projectPath 'package.json'
    if (Test-Path -LiteralPath $packageJson) {
        $npm = Get-NativeCommand -Name 'npm'
        if ($null -eq $npm) { throw 'npm wurde fuer die Verifikation nicht gefunden.' }
        $package = Get-Content -LiteralPath $packageJson -Raw | ConvertFrom-Json
        if ($null -ne $package.scripts.test) { return Invoke-Logged -Executable $npm -Arguments @('test', '--', '--runInBand') -LogPath $LogPath }
        if ($null -ne $package.scripts.build) { return Invoke-Logged -Executable $npm -Arguments @('run', 'build') -LogPath $LogPath }
    }

    if (Test-Path -LiteralPath (Join-Path $projectPath 'pyproject.toml')) {
        $pytest = Get-NativeCommand -Name 'pytest'
        if ($null -ne $pytest) { return Invoke-Logged -Executable $pytest -Arguments @('-q') -LogPath $LogPath }
    }

    if (Test-Path -LiteralPath (Join-Path $projectPath 'Cargo.toml')) {
        $cargo = Get-NativeCommand -Name 'cargo'
        if ($null -ne $cargo) { return Invoke-Logged -Executable $cargo -Arguments @('test') -LogPath $LogPath }
    }

    'Kein automatischer Verifier erkannt.' | Set-Content -LiteralPath $LogPath -Encoding utf8
    return 0
}

Test-TaskPolicy -Text $Task
$resolvedTier = if ($Tier -eq 'auto') { Get-TaskTier -Text $Task } else { $Tier }
$commands = [pscustomobject]@{
    Claude   = Get-NativeCommand -Name 'claude'
    Codex    = Get-NativeCommand -Name 'codex'
    OpenCode = Get-NativeCommand -Name 'opencode'
}
$route = Get-Route -RequestedTier $resolvedTier -RequestedMain $MainAI -Commands $commands
$freeModel = $null
if ($route.Primary -eq 'free' -or $route.Reviewer -eq 'free') {
    if ($null -eq $commands.OpenCode) { throw 'OpenCode wurde nicht gefunden.' }
    $freeModel = Get-FreeModel -RequestedTier $resolvedTier -OpenCodeCommand $commands.OpenCode
}

$summary = [pscustomobject]@{
    Project   = $projectPath
    Tier      = $resolvedTier
    Mode      = $Mode
    Primary   = $route.Primary
    Reviewer  = $route.Reviewer
    FreeModel = $freeModel
}
$summary | Format-List

if ($Mode -eq 'preview') {
    return
}

if ($resolvedTier -eq 'critical' -and $Mode -eq 'apply') {
    throw 'Kritische Aufgaben duerfen nicht automatisch angewendet werden. Nutze -Mode plan und pruefe den Plan manuell.'
}

$runRoot = Join-Path $projectPath '.agent-runs'
$runDirectory = Join-Path $runRoot (Get-Date -Format 'yyyyMMdd-HHmmss')
New-Item -ItemType Directory -Force -Path $runDirectory | Out-Null
$summary | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $runDirectory 'route.json') -Encoding utf8

Push-Location $projectPath
try {
    $primaryExit = Invoke-Provider -Provider $route.Primary -RunMode $Mode -Prompt $Task -FreeModel $freeModel -LogPath (Join-Path $runDirectory 'primary.log')
    if ($primaryExit -ne 0) { throw "Primaer-Agent ist mit Exitcode $primaryExit fehlgeschlagen." }

    if ($Mode -eq 'apply') {
        $verifyExit = Invoke-Verification -LogPath (Join-Path $runDirectory 'verification.log')
        if ($verifyExit -ne 0) { throw "Verifikation ist mit Exitcode $verifyExit fehlgeschlagen." }
    }

    if ($route.Reviewer -ne 'none') {
        $reviewPrompt = "Pruefe die Umsetzung oder den Plan fuer folgende Aufgabe read-only. Suche konkrete Fehler, Sicherheitsrisiken und fehlende Tests. Aendere keine Dateien.`n`n$Task"
        $reviewExit = Invoke-Provider -Provider $route.Reviewer -RunMode 'plan' -Prompt $reviewPrompt -FreeModel $freeModel -LogPath (Join-Path $runDirectory 'review.log')
        if ($reviewExit -ne 0) { throw "Review-Agent ist mit Exitcode $reviewExit fehlgeschlagen." }
    }
}
finally {
    Pop-Location
}

Write-Host "Fertig. Protokolle: $runDirectory"
