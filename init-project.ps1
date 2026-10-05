<#
.SYNOPSIS
  Apply the harness project layer to a target repository.

.DESCRIPTION
  Writes AGENTS.md (core rules + project template), CLAUDE.md (imports AGENTS.md),
  and .claude/settings.json (core permissions + model provider env) into the target
  repository. Safe to re-run: the core block and harness-managed keys are replaced,
  everything else in existing files is kept. No stack detection is done here; the
  agent fills in the project facts afterwards (see the printed next step).

  Compatible with Windows PowerShell 5.1. This file is ASCII-only on purpose.

.EXAMPLE
  .\init-project.ps1 -ProjectPath C:\work\my-app
  .\init-project.ps1 -ProjectPath C:\work\my-app -Provider bedrock -AwsProfile my-profile
  .\init-project.ps1 -ProjectPath C:\work\my-app -Provider gateway -GatewayUrl https://llm-gw.corp.example
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProjectPath,
    [ValidateSet('direct', 'bedrock', 'gateway')][string]$Provider = 'direct',
    [string]$AwsProfile,
    [string]$GatewayUrl,
    [switch]$WithVerifySkill
)

$ErrorActionPreference = 'Stop'
$HarnessRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$CoreStart = '<!-- harness:core:start -->'
$CoreEnd = '<!-- harness:core:end -->'

function Read-Text([string]$Path) {
    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Write-Text([string]$Path, [string]$Text) {
    [System.IO.File]::WriteAllText($Path, $Text, $Utf8NoBom)
}

function ConvertTo-Hash($Object) {
    if ($null -eq $Object) { return $null }
    if ($Object -is [System.Management.Automation.PSCustomObject]) {
        $hash = [ordered]@{}
        foreach ($prop in $Object.PSObject.Properties) {
            $hash[$prop.Name] = ConvertTo-Hash $prop.Value
        }
        return $hash
    }
    if (($Object -is [System.Collections.IEnumerable]) -and -not ($Object -is [string])) {
        $list = @()
        foreach ($item in $Object) { $list += , (ConvertTo-Hash $item) }
        return , $list
    }
    return $Object
}

function Read-JsonHash([string]$Path) {
    $text = Read-Text $Path
    if ([string]::IsNullOrWhiteSpace($text)) { return [ordered]@{} }
    $hash = ConvertTo-Hash ($text | ConvertFrom-Json)
    if ($null -eq $hash) { return [ordered]@{} }
    return $hash
}

function Write-JsonHash([string]$Path, $Hash) {
    Write-Text $Path (($Hash | ConvertTo-Json -Depth 20) + "`n")
}

function Merge-Unique($Existing, $Additional) {
    $result = @()
    foreach ($item in @($Existing) + @($Additional)) {
        if ($null -ne $item -and ($result -notcontains $item)) { $result += $item }
    }
    return , $result
}

function Say([string]$Tag, [string]$Message) {
    Write-Host ("[{0}] {1}" -f $Tag, $Message)
}

# --- 1. target -------------------------------------------------------------
if (-not (Test-Path -LiteralPath $ProjectPath -PathType Container)) {
    throw "Project path not found: $ProjectPath"
}
$Project = (Resolve-Path -LiteralPath $ProjectPath).Path
if ($Project -eq $HarnessRoot) {
    throw "Target is the harness folder itself. Point -ProjectPath at the repository you develop in."
}

# --- 2. provider -----------------------------------------------------------
$providerFile = Join-Path $HarnessRoot "core\providers\$Provider.json"
if (-not (Test-Path -LiteralPath $providerFile)) {
    $providerFile = Join-Path $HarnessRoot "core\providers\$Provider.example.json"
}
if (-not (Test-Path -LiteralPath $providerFile)) { throw "Provider definition not found: $Provider" }
$providerDef = Read-JsonHash $providerFile
$providerEnv = [ordered]@{}
if ($providerDef.Contains('env') -and $null -ne $providerDef['env']) {
    foreach ($key in $providerDef['env'].Keys) { $providerEnv[$key] = [string]$providerDef['env'][$key] }
}
$providerSettings = [ordered]@{}
if ($providerDef.Contains('settings') -and $null -ne $providerDef['settings']) {
    foreach ($key in $providerDef['settings'].Keys) { $providerSettings[$key] = $providerDef['settings'][$key] }
}

if ($Provider -eq 'gateway') {
    if ([string]::IsNullOrWhiteSpace($GatewayUrl)) {
        throw "Provider 'gateway' needs -GatewayUrl (the approved gateway endpoint)."
    }
    $providerEnv['ANTHROPIC_BASE_URL'] = $GatewayUrl
}
if ($Provider -eq 'bedrock' -and -not [string]::IsNullOrWhiteSpace($AwsProfile)) {
    $providerEnv['AWS_PROFILE'] = $AwsProfile
}

# --- 3. AGENTS.md ----------------------------------------------------------
$coreText = (Read-Text (Join-Path $HarnessRoot 'core\AGENTS.core.md')).Trim()
$coreBlock = $CoreStart + "`n" + $coreText + "`n" + $CoreEnd
$agentsPath = Join-Path $Project 'AGENTS.md'

if (-not (Test-Path -LiteralPath $agentsPath)) {
    $projectText = (Read-Text (Join-Path $HarnessRoot 'profiles\_template\AGENTS.project.md')).Trim()
    Write-Text $agentsPath ("# AGENTS.md`n`n" + $coreBlock + "`n`n" + $projectText + "`n")
    Say 'new ' 'AGENTS.md (core rules + empty project section)'
}
else {
    $existing = Read-Text $agentsPath
    $pattern = '(?s)' + [regex]::Escape($CoreStart) + '.*?' + [regex]::Escape($CoreEnd)
    if ([regex]::IsMatch($existing, $pattern)) {
        $updated = [regex]::Replace($existing, $pattern, { param($m) $coreBlock })
        if ($updated -ne $existing) {
            Write-Text $agentsPath $updated
            Say 'upd ' 'AGENTS.md (core block refreshed, project content untouched)'
        }
        else { Say 'keep' 'AGENTS.md (core block already current)' }
    }
    else {
        Write-Text $agentsPath ($existing.TrimEnd() + "`n`n" + $coreBlock + "`n")
        Say 'upd ' 'AGENTS.md existed without a harness block: core block appended, nothing else changed'
    }
}

# --- 4. CLAUDE.md ----------------------------------------------------------
$claudeMd = Join-Path $Project 'CLAUDE.md'
if (-not (Test-Path -LiteralPath $claudeMd)) {
    Write-Text $claudeMd "@AGENTS.md`n"
    Say 'new ' 'CLAUDE.md (imports AGENTS.md)'
}
elseif ((Read-Text $claudeMd) -notmatch '(?m)^@AGENTS\.md\s*$') {
    Say 'WARN' 'CLAUDE.md exists but does not import AGENTS.md. Add a line "@AGENTS.md" to it; not modified automatically.'
}
else { Say 'keep' 'CLAUDE.md (already imports AGENTS.md)' }

# --- 5. .claude/settings.json ---------------------------------------------
$claudeDir = Join-Path $Project '.claude'
if (-not (Test-Path -LiteralPath $claudeDir)) { New-Item -ItemType Directory -Path $claudeDir | Out-Null }
$settingsPath = Join-Path $claudeDir 'settings.json'
$statePath = Join-Path $claudeDir 'harness.json'

$settings = [ordered]@{}
$settingsBefore = $null
if (Test-Path -LiteralPath $settingsPath) {
    $settingsBefore = Read-Text $settingsPath
    $settings = Read-JsonHash $settingsPath
}
$state = [ordered]@{}
if (Test-Path -LiteralPath $statePath) { $state = Read-JsonHash $statePath }

# remove what a previous run of this script put there
if (-not $settings.Contains('env') -or $null -eq $settings['env']) { $settings['env'] = [ordered]@{} }
if ($state.Contains('managedEnvKeys')) {
    foreach ($key in @($state['managedEnvKeys'])) {
        if ($settings['env'].Contains($key)) { $settings['env'].Remove($key) }
    }
}
if ($state.Contains('managedSettingsKeys')) {
    foreach ($key in @($state['managedSettingsKeys'])) {
        if ($settings.Contains($key)) { $settings.Remove($key) }
    }
}

# core permissions: union with whatever the project already has
$core = Read-JsonHash (Join-Path $HarnessRoot 'core\settings.core.json')
if (-not $settings.Contains('permissions') -or $null -eq $settings['permissions']) {
    $settings['permissions'] = [ordered]@{}
}
foreach ($kind in @('allow', 'deny')) {
    $current = @()
    if ($settings['permissions'].Contains($kind)) { $current = @($settings['permissions'][$kind]) }
    $settings['permissions'][$kind] = Merge-Unique $current @($core['permissions'][$kind])
}

# provider
foreach ($key in $providerEnv.Keys) { $settings['env'][$key] = $providerEnv[$key] }
foreach ($key in $providerSettings.Keys) { $settings[$key] = $providerSettings[$key] }
if ($settings['env'].Count -eq 0) { $settings.Remove('env') }

$settingsAfter = ($settings | ConvertTo-Json -Depth 20) + "`n"
if ($settingsAfter -eq $settingsBefore) {
    Say 'keep' (".claude/settings.json (already current, provider = $Provider)")
}
else {
    if ($null -ne $settingsBefore) {
        Write-Text "$settingsPath.bak" $settingsBefore
        Say 'bak ' 'previous settings.json saved as settings.json.bak'
    }
    Write-Text $settingsPath $settingsAfter
    Say 'set ' (".claude/settings.json (core permissions, provider = $Provider)")
}

# keep tool output and the backup out of version control when the target is a git repository
if (Test-Path -LiteralPath (Join-Path $Project '.git')) {
    $ignorePath = Join-Path $Project '.gitignore'
    $ignoreText = ''
    if (Test-Path -LiteralPath $ignorePath) { $ignoreText = Read-Text $ignorePath }
    $wanted = @('.playwright-cli/', '.claude/settings.json.bak')
    $missing = @($wanted | Where-Object { $ignoreText -notmatch ('(?m)^' + [regex]::Escape($_) + '\s*$') })
    if ($missing.Count -gt 0) {
        $addition = "`n# harness`n" + ($missing -join "`n") + "`n"
        Write-Text $ignorePath ($ignoreText.TrimEnd() + $addition)
        Say 'upd ' ('.gitignore (added: ' + ($missing -join ', ') + ')')
    }
}

$newState = [ordered]@{
    harnessVersion      = (Read-Text (Join-Path $HarnessRoot 'core\VERSION')).Trim()
    provider            = $Provider
    managedEnvKeys      = @($providerEnv.Keys)
    managedSettingsKeys = @($providerSettings.Keys)
    appliedAt           = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')
}
Write-JsonHash $statePath $newState

# --- 6. optional skill template -------------------------------------------
if ($WithVerifySkill) {
    $skillDir = Join-Path $claudeDir 'skills\verify-change'
    $skillFile = Join-Path $skillDir 'SKILL.md'
    if (-not (Test-Path -LiteralPath $skillFile)) {
        New-Item -ItemType Directory -Path $skillDir -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $HarnessRoot 'profiles\_template\skills\verify-change\SKILL.md') -Destination $skillFile
        Say 'new ' '.claude/skills/verify-change/SKILL.md (template; useless until filled with project facts)'
    }
    else { Say 'keep' '.claude/skills/verify-change/SKILL.md' }
}

# --- 7. next step ----------------------------------------------------------
$promptFile = Join-Path $HarnessRoot 'profiles\_template\fill-profile.prompt.md'
Write-Host ''
Write-Host 'Next:'
Write-Host ("  1. cd `"$Project`"")
Write-Host ("  2. Run claude there, accept the trust dialog, then paste the contents of this file into the session:")
Write-Host ("       $promptFile")
Write-Host ("  3. Verify:  $HarnessRoot\check.ps1 -ProjectPath `"$Project`"")
if ($Provider -eq 'bedrock') {
    Write-Host ''
    Write-Host 'Bedrock: this script made no AWS call. Credentials and in-region model access must be confirmed with the target account.'
}
if ($Provider -eq 'gateway') {
    Write-Host ''
    Write-Host 'Gateway: the credential is not stored in the repository. Provide it on the PC (apiKeyHelper or ANTHROPIC_AUTH_TOKEN).'
}
