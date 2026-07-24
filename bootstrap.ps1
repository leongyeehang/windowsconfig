#Requires -Version 5.1
<#
  windowsconfig bootstrap — entry point for:
    irm https://raw.githubusercontent.com/leongyeehang/windowsconfig/main/bootstrap.ps1 | iex

  Installs prerequisites (git, winget), clones this repo, then hands off to
  install.ps1 all. Safe to re-run: re-clone is skipped if the repo already
  exists, and install.ps1's own steps are idempotent.
#>

Set-StrictMode -Version Latest

$RepoUrl  = 'https://github.com/leongyeehang/windowsconfig.git'
$CloneDir = Join-Path $HOME 'windowsconfig'

function Write-Info { param([string]$Message) Write-Host "==> $Message" -ForegroundColor Cyan }
function Write-Warn { param([string]$Message) Write-Host "[!] $Message" -ForegroundColor Yellow }
function Write-Ok   { param([string]$Message) Write-Host "[ok] $Message" -ForegroundColor Green }

function Test-CommandExists {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

if (-not (Test-CommandExists 'winget')) {
    Write-Warn 'winget not found. Install "App Installer" from the Microsoft Store, then re-run this command.'
    exit 1
}

if (-not (Test-CommandExists 'git')) {
    Write-Info 'git not found — installing via winget'
    winget install --id Git.Git -e --silent --accept-package-agreements --accept-source-agreements
    Write-Ok 'git installed (you may need to open a new PowerShell window for PATH to update)'
}

if (Test-Path (Join-Path $CloneDir '.git')) {
    Write-Ok "windowsconfig already cloned at $CloneDir"
} else {
    Write-Info "Cloning windowsconfig to $CloneDir"
    git clone $RepoUrl $CloneDir
}

Write-Info 'Handing off to install.ps1 all'
& (Join-Path $CloneDir 'install.ps1') all
