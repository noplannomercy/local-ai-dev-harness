<#
.SYNOPSIS
  Prepare this PC for the harness: default agent and capability tools.

.DESCRIPTION
  Without -Install this only reports what is missing and what it would run.
  With -Install it installs the missing pieces and nothing else: it never upgrades,
  reconfigures or removes anything that is already present, and it does not touch
  user-level agent settings. Organization policy (core/policy) is a rollout step that
  needs admin rights and is not applied here.

  Compatible with Windows PowerShell 5.1. This file is ASCII-only on purpose.

.EXAMPLE
  .\setup.ps1
  .\setup.ps1 -Install
  .\setup.ps1 -Install -NpmRegistry https://npm.corp.example/
#>
[CmdletBinding()]
param(
    [switch]$Install,
    [string]$NpmRegistry
)

$ErrorActionPreference = 'Stop'
$HarnessRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

function Has([string]$Name) {
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Step([string]$What, [string]$CommandText, [scriptblock]$Action) {
    if ($Install) {
        Write-Host ("[install] {0}: {1}" -f $What, $CommandText)
        & $Action
        if ($LASTEXITCODE -ne 0) { throw "$What failed (exit $LASTEXITCODE)" }
    }
    else {
        Write-Host ("[missing] {0}. -Install would run: {1}" -f $What, $CommandText)
    }
}

$npmArgs = @()
if (-not [string]::IsNullOrWhiteSpace($NpmRegistry)) { $npmArgs = @('--registry', $NpmRegistry) }
$todo = 0

# --- default agent ---------------------------------------------------------
if (Has 'claude') {
    Write-Host '[ok]      Claude Code'
}
else {
    $todo++
    if (Has 'winget') {
        Step 'Claude Code' 'winget install --id Anthropic.ClaudeCode -e' {
            winget install --id Anthropic.ClaudeCode -e --accept-source-agreements --accept-package-agreements
        }
    }
    elseif (Has 'npm') {
        Step 'Claude Code' 'npm install -g @anthropic-ai/claude-code' {
            npm install -g '@anthropic-ai/claude-code' @npmArgs
        }
    }
    else {
        Write-Host '[blocked] Claude Code: neither winget nor npm is available on this PC'
    }
}

# --- capability tools declared in core/capabilities.json -------------------
$caps = ([System.IO.File]::ReadAllText((Join-Path $HarnessRoot 'core\capabilities.json'), [System.Text.Encoding]::UTF8) | ConvertFrom-Json).capabilities
foreach ($cap in $caps) {
    if ([string]::IsNullOrWhiteSpace($cap.command)) {
        Write-Host ("[ok]      Capability '{0}': {1} (nothing to install)" -f $cap.id, $cap.implementation)
        continue
    }
    if (Has $cap.command) {
        Write-Host ("[ok]      Capability '{0}': {1}" -f $cap.id, $cap.command)
        continue
    }
    $todo++
    if (-not (Has 'npm')) {
        Write-Host ("[blocked] Capability '{0}': npm is not available (Node.js 18+ required for {1})" -f $cap.id, $cap.npmPackage)
        continue
    }
    $pkg = $cap.npmPackage
    Step ("Capability '" + $cap.id + "'") ("npm install -g " + $pkg) {
        npm install -g $pkg @npmArgs
    }
}

Write-Host ''
if ($todo -eq 0) { Write-Host 'Nothing to install.' }
elseif (-not $Install) { Write-Host ("{0} item(s) missing. Re-run with -Install to install them." -f $todo) }

Write-Host ''
& (Join-Path $HarnessRoot 'check.ps1')
exit $LASTEXITCODE
