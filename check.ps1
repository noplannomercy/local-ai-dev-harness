<#
.SYNOPSIS
  Check that this PC (and optionally a target repository) is ready for the harness.

.DESCRIPTION
  Reports PASS / WARN / FAIL per item and exits 1 when any FAIL is present.
  Makes no model call and no cloud call unless -Live is given.
  -Live sends one short prompt through the configured model path. It is refused for
  any provider other than "direct" unless -AllowProviderCall is also given, so that
  a check never spends on a cloud account by accident.

  Compatible with Windows PowerShell 5.1. This file is ASCII-only on purpose.

.EXAMPLE
  .\check.ps1
  .\check.ps1 -ProjectPath C:\work\my-app
  .\check.ps1 -ProjectPath C:\work\my-app -Live
#>
[CmdletBinding()]
param(
    [string]$ProjectPath,
    [switch]$Live,
    [switch]$AllowProviderCall
)

$ErrorActionPreference = 'Stop'
$HarnessRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:Fail = 0
$script:Warn = 0

function Report([string]$Level, [string]$Item, [string]$Detail) {
    if ($Level -eq 'FAIL') { $script:Fail++ }
    if ($Level -eq 'WARN') { $script:Warn++ }
    Write-Host ("{0,-5} {1,-28} {2}" -f $Level, $Item, $Detail)
}

function Find-Command([string]$Name) {
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { return $cmd.Source }
    return $null
}

function Get-VersionText([string]$Name, [string[]]$VersionArgs) {
    try {
        $out = & $Name @VersionArgs 2>$null | Select-Object -First 1
        if ($out) { return ([string]$out).Trim() }
    }
    catch { }
    return 'version unknown'
}

function Read-Json([string]$Path) {
    $text = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    return ($text | ConvertFrom-Json)
}

function Get-EnvValue($Settings, [string]$Name) {
    if ($null -eq $Settings) { return $null }
    if (-not ($Settings.PSObject.Properties.Name -contains 'env')) { return $null }
    if ($null -eq $Settings.env) { return $null }
    if ($Settings.env.PSObject.Properties.Name -contains $Name) { return [string]$Settings.env.$Name }
    return $null
}

Write-Host ("Harness check  (harness " + (Get-Content (Join-Path $HarnessRoot 'core\VERSION') -TotalCount 1) + ")")
Write-Host ''
Write-Host '-- PC --'

# shell
Report 'PASS' 'PowerShell' ([string]$PSVersionTable.PSVersion)

# default agent
$claude = Find-Command 'claude'
if ($claude) { Report 'PASS' 'Claude Code (default agent)' (Get-VersionText 'claude' @('--version')) }
else { Report 'FAIL' 'Claude Code (default agent)' 'not found. Run setup.ps1 -Install, or: winget install Anthropic.ClaudeCode' }

# git: optional for Claude Code on native Windows, but every project workflow uses it
$git = Find-Command 'git'
if ($git) { Report 'PASS' 'Git' (Get-VersionText 'git' @('--version')) }
else { Report 'WARN' 'Git' 'not found. Claude Code falls back to its PowerShell tool; project workflows still need git' }

# node: needed by npm-distributed tools
$node = Find-Command 'node'
if ($node) { Report 'PASS' 'Node.js' (Get-VersionText 'node' @('--version')) }
else { Report 'WARN' 'Node.js' 'not found. Needed only for npm-distributed tools (browser tool, compatible agents)' }

# compatible agents (optional)
foreach ($agent in @(@{ n = 'codex'; label = 'Codex CLI (compatible)' }, @{ n = 'opencode'; label = 'OpenCode (compatible)' })) {
    if (Find-Command $agent.n) { Report 'PASS' $agent.label (Get-VersionText $agent.n @('--version')) }
    else { Report 'INFO' $agent.label 'not installed (optional: cross-model review, environment C fallback)' }
}

# an installed browser the browser tool can drive without downloading one
$browsers = @(
    @{ label = 'Microsoft Edge'; paths = @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe") },
    @{ label = 'Google Chrome'; paths = @("$env:ProgramFiles\Google\Chrome\Application\chrome.exe", "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe") }
)
$foundBrowser = @()
foreach ($b in $browsers) {
    foreach ($p in $b.paths) { if ($p -and (Test-Path -LiteralPath $p)) { $foundBrowser += $b.label; break } }
}
if ($foundBrowser.Count -gt 0) { Report 'PASS' 'Installed browser' ($foundBrowser -join ', ') }
else { Report 'FAIL' 'Installed browser' 'neither Edge nor Chrome found; browser verification needs one' }

# capability implementations (declared in core/capabilities.json)
$capFile = Join-Path $HarnessRoot 'core\capabilities.json'
if (Test-Path -LiteralPath $capFile) {
    $caps = Read-Json $capFile
    foreach ($cap in $caps.capabilities) {
        if ([string]::IsNullOrWhiteSpace($cap.command)) {
            Report 'PASS' ("Capability: " + $cap.id) ($cap.implementation + ' (no extra install)')
        }
        elseif (Find-Command $cap.command) {
            Report 'PASS' ("Capability: " + $cap.id) ($cap.implementation + ' -> ' + (Get-VersionText $cap.command @($cap.versionArgs)))
        }
        else {
            Report 'FAIL' ("Capability: " + $cap.id) ($cap.implementation + ' not found. Run setup.ps1 -Install')
        }
    }
}
else {
    Report 'WARN' 'Capabilities' 'core/capabilities.json missing: browser and docs implementations not declared yet'
}

# credentials in the environment override the claude.ai login and any project-level provider choice
$authVars = @('ANTHROPIC_API_KEY', 'ANTHROPIC_AUTH_TOKEN', 'CLAUDE_CODE_OAUTH_TOKEN') | Where-Object { [Environment]::GetEnvironmentVariable($_) }
if (@($authVars).Count -gt 0) {
    Report 'WARN' 'Auth source' ((@($authVars) -join ', ') + ' is set in the environment and takes precedence over the claude.ai login. Remove it unless that is intended')
}
else { Report 'PASS' 'Auth source' 'no credential override in the environment' }
foreach ($routeVar in @('ANTHROPIC_BASE_URL', 'CLAUDE_CODE_USE_BEDROCK', 'CLAUDE_CODE_USE_VERTEX', 'CLAUDE_CODE_USE_FOUNDRY')) {
    if ([Environment]::GetEnvironmentVariable($routeVar)) {
        Report 'WARN' 'Model route override' "$routeVar is set in the environment and competes with the project-level provider setting"
    }
}

# organization policy (informational: applying it needs admin rights and is a rollout step)
$managed = Join-Path $env:ProgramFiles 'ClaudeCode\managed-settings.json'
$managedReg = $false
try { $managedReg = [bool](Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\ClaudeCode' -Name 'Settings' -ErrorAction Stop) } catch { }
if ((Test-Path -LiteralPath $managed) -or $managedReg) { Report 'PASS' 'Organization policy' 'managed settings present' }
else { Report 'INFO' 'Organization policy' 'none on this PC (expected on a dev box; template in core/policy)' }

# --- project ---------------------------------------------------------------
$provider = 'direct'
$settings = $null
if (-not [string]::IsNullOrWhiteSpace($ProjectPath)) {
    Write-Host ''
    Write-Host '-- Project --'
    if (-not (Test-Path -LiteralPath $ProjectPath -PathType Container)) {
        Report 'FAIL' 'Project path' "not found: $ProjectPath"
    }
    else {
        $proj = (Resolve-Path -LiteralPath $ProjectPath).Path
        Report 'PASS' 'Project path' $proj

        $agents = Join-Path $proj 'AGENTS.md'
        if (-not (Test-Path -LiteralPath $agents)) {
            Report 'FAIL' 'AGENTS.md' 'missing. Run init-project.ps1'
        }
        else {
            $text = [System.IO.File]::ReadAllText($agents, [System.Text.Encoding]::UTF8)
            if ($text -match 'harness:core:start') { Report 'PASS' 'AGENTS.md core block' 'present' }
            else { Report 'FAIL' 'AGENTS.md core block' 'missing. Run init-project.ps1' }

            # project facts: count command-table rows that still have an empty command cell
            # a data row is a 3-column table row that is neither the header nor the |---| separator
            $lines = $text -split "`r?`n"
            $dataRows = 0; $emptyRows = 0
            for ($i = 0; $i -lt $lines.Count; $i++) {
                $line = $lines[$i].Trim()
                if (-not $line.StartsWith('|')) { continue }
                $cells = @($line.Trim('|').Split('|') | ForEach-Object { $_.Trim() })
                if ($cells.Count -ne 3) { continue }
                if ($cells[0] -match '^:?-+:?$') { continue }
                $next = ''
                if ($i + 1 -lt $lines.Count) { $next = $lines[$i + 1].Trim() }
                if ($next -match '^\|\s*:?-+') { continue }
                $dataRows++
                if ($cells[1] -eq '') { $emptyRows++ }
            }
            if ($dataRows -eq 0) { Report 'WARN' 'Project facts' 'no command table found in AGENTS.md' }
            elseif ($emptyRows -gt 0) { Report 'WARN' 'Project facts' "$emptyRows command(s) still empty in AGENTS.md. Let the agent fill them, then run them once" }
            else { Report 'PASS' 'Project facts' 'command table filled' }
        }

        $claudeMd = Join-Path $proj 'CLAUDE.md'
        if (-not (Test-Path -LiteralPath $claudeMd)) { Report 'FAIL' 'CLAUDE.md' 'missing. Run init-project.ps1' }
        elseif ([System.IO.File]::ReadAllText($claudeMd, [System.Text.Encoding]::UTF8) -match '(?m)^@AGENTS\.md\s*$') { Report 'PASS' 'CLAUDE.md' 'imports AGENTS.md' }
        else { Report 'WARN' 'CLAUDE.md' 'does not import AGENTS.md: Claude Code will not see the shared rules' }

        $settingsPath = Join-Path $proj '.claude\settings.json'
        if (-not (Test-Path -LiteralPath $settingsPath)) {
            Report 'FAIL' '.claude/settings.json' 'missing. Run init-project.ps1'
        }
        else {
            try {
                $settings = Read-Json $settingsPath
                Report 'PASS' '.claude/settings.json' 'valid JSON'
                $deny = @()
                if ($settings.PSObject.Properties.Name -contains 'permissions' -and $settings.permissions.PSObject.Properties.Name -contains 'deny') { $deny = @($settings.permissions.deny) }
                if ($deny -contains 'Read(**/.env)') { Report 'PASS' 'Secret-file deny rules' ("{0} rule(s)" -f $deny.Count) }
                else { Report 'FAIL' 'Secret-file deny rules' 'core deny rules missing. Run init-project.ps1' }
            }
            catch { Report 'FAIL' '.claude/settings.json' ('not valid JSON: ' + $_.Exception.Message) }
        }

        # model path
        if (Get-EnvValue $settings 'CLAUDE_CODE_USE_BEDROCK') { $provider = 'bedrock' }
        elseif (Get-EnvValue $settings 'ANTHROPIC_BASE_URL') { $provider = 'gateway' }
        switch ($provider) {
            'direct' { Report 'PASS' 'Model path' 'direct (Anthropic login or API key)' }
            'bedrock' {
                $region = Get-EnvValue $settings 'AWS_REGION'
                $opus = Get-EnvValue $settings 'ANTHROPIC_DEFAULT_OPUS_MODEL'
                Report 'PASS' 'Model path' "bedrock, region=$region, opus=$opus"
                if ($opus -match '^(us|eu|apac|jp|au|global)\.') { Report 'WARN' 'Region pinning' 'model ID is a cross-region inference profile: requests may leave the region' }
                else { Report 'PASS' 'Region pinning' 'in-region model IDs (not verified by a live call)' }
                if (-not (Find-Command 'aws')) { Report 'INFO' 'AWS credentials' 'aws CLI not found; credentials are not checked by this script' }
                else { Report 'INFO' 'AWS credentials' 'not checked (no cloud call without -Live -AllowProviderCall)' }
            }
            'gateway' {
                $url = Get-EnvValue $settings 'ANTHROPIC_BASE_URL'
                Report 'PASS' 'Model path' "gateway, url=$url"
                if ($url -match 'example\.com') { Report 'FAIL' 'Gateway URL' 'still the placeholder' }
                if (-not $env:ANTHROPIC_AUTH_TOKEN -and -not ($settings.PSObject.Properties.Name -contains 'apiKeyHelper')) {
                    Report 'WARN' 'Gateway credential' 'no ANTHROPIC_AUTH_TOKEN in this shell and no apiKeyHelper configured'
                }
            }
        }
    }
}

# --- live model call -------------------------------------------------------
if ($Live) {
    Write-Host ''
    Write-Host '-- Live model path --'
    if (-not $claude) {
        Report 'FAIL' 'Live call' 'Claude Code not installed'
    }
    elseif ($provider -ne 'direct' -and -not $AllowProviderCall) {
        Report 'WARN' 'Live call' "skipped: provider is '$provider'. Add -AllowProviderCall to spend on that account deliberately"
    }
    else {
        $where = $HarnessRoot
        if ($settings -and -not [string]::IsNullOrWhiteSpace($ProjectPath)) { $where = (Resolve-Path -LiteralPath $ProjectPath).Path }
        Push-Location $where
        # Windows PowerShell 5.1 turns native stderr into errors under 'Stop'; relax it for this call only
        $previousPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $raw = & claude -p 'Reply with exactly: HARNESS-OK' --tools '' --strict-mcp-config --no-session-persistence --output-format text 2>&1
            $code = $LASTEXITCODE
            $answerText = ((@($raw) | ForEach-Object { [string]$_ }) -join ' ').Trim()
            if ($answerText -match 'has not been trusted') {
                Report 'WARN' 'Workspace trust' 'not trusted yet: permission allow rules are ignored. Run "claude" once in the project and accept the trust dialog'
            }
            if ($code -eq 0 -and $answerText -match 'HARNESS-OK') {
                Report 'PASS' 'Live call' "model answered through '$provider' path"
            }
            elseif ($answerText -match 'Credit balance is too low') {
                Report 'FAIL' 'Live call' 'the credential in effect has no credit (see "Auth source" above)'
            }
            else {
                $tail = $answerText
                if ($tail.Length -gt 160) { $tail = $tail.Substring($tail.Length - 160) }
                Report 'FAIL' 'Live call' "exit=$code output='...$tail'"
            }
        }
        catch { Report 'FAIL' 'Live call' $_.Exception.Message }
        finally {
            $ErrorActionPreference = $previousPreference
            Pop-Location
        }
    }
}

Write-Host ''
Write-Host ("Result: {0} FAIL, {1} WARN" -f $script:Fail, $script:Warn)
if ($script:Fail -gt 0) { exit 1 }
exit 0
