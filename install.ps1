#Requires -Version 5.1
<#
  windowsconfig installer — SharpKeys/AutoHotkey · winget apps · Explorer/theme
  tweaks · Windows Terminal · WSL2 + dotfiles

  Usage: install.ps1 <ssh|keyboard|apps|settings|terminal|wsl|all|help>

  Every step is safe to re-run: registry imports are idempotent, winget skips
  already-installed packages, the startup shortcut is only created once,
  terminal backs up settings.json to settings.json.bak.<timestamp> before
  editing it, and the ssh step no-ops if a key exists.
#>

param(
    [Parameter(Position = 0)]
    [ValidateSet('ssh', 'keyboard', 'apps', 'settings', 'terminal', 'wsl', 'all', 'help')]
    [string]$Command = 'help'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = $PSScriptRoot

function Write-Info { param([string]$Message) Write-Host "==> $Message" -ForegroundColor Cyan }
function Write-Warn { param([string]$Message) Write-Host "[!] $Message" -ForegroundColor Yellow }
function Write-Ok   { param([string]$Message) Write-Host "[ok] $Message" -ForegroundColor Green }

function Test-IsElevated {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-Ssh {
    $sshDir = Join-Path $HOME '.ssh'
    $keyPath = Join-Path $sshDir 'id_ed25519'
    if (-not (Test-Path $sshDir)) { New-Item -ItemType Directory -Path $sshDir -Force | Out-Null }

    if (Test-Path $keyPath) {
        Write-Ok "SSH key already exists: $keyPath"
        return
    }

    Write-Info 'no SSH key found — generating a new ed25519 keypair'
    ssh-keygen -t ed25519 -f $keyPath -N '""' -C "$env:USERNAME@$env:COMPUTERNAME"
    Write-Ok "generated $keyPath"

    Write-Host ''
    Write-Host 'Add this public key to GitHub: https://github.com/settings/keys'
    Write-Host ''
    Get-Content "$keyPath.pub"
    Write-Host ''
    Read-Host 'Press Enter once the key has been added to GitHub to continue'
}

function Invoke-Keyboard {
    $regFile = Join-Path $RepoRoot 'keyboard\mac-layout.reg'
    $ahkFile = Join-Path $RepoRoot 'keyboard\mac-shortcuts.ahk'

    if (Test-Path $regFile) {
        Write-Info "importing scancode map from $regFile"
        reg import $regFile
        Write-Ok 'scancode map imported (sign out/in or reboot for it to take effect)'
    } else {
        Write-Warn 'keyboard\mac-layout.reg not found — export it from SharpKeys, place it here, then re-run: install.ps1 keyboard'
    }

    if (Test-Path $ahkFile) {
        $ahkInstalled = (Test-Path "$env:ProgramFiles\AutoHotkey\AutoHotkey.exe") -or
                        (Test-Path "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey.exe") -or
                        [bool](Get-Command AutoHotkey.exe -ErrorAction SilentlyContinue)
        if (-not $ahkInstalled) {
            Write-Info 'AutoHotkey not found — installing via winget'
            winget install --id AutoHotkey.AutoHotkey -e --silent --accept-package-agreements --accept-source-agreements
        }

        $startupDir = [Environment]::GetFolderPath('Startup')
        $shortcutPath = Join-Path $startupDir 'mac-shortcuts.lnk'
        if (Test-Path $shortcutPath) {
            Write-Ok "startup shortcut already exists: $shortcutPath"
        } else {
            $shell = New-Object -ComObject WScript.Shell
            $shortcut = $shell.CreateShortcut($shortcutPath)
            $shortcut.TargetPath = $ahkFile
            $shortcut.Save()
            Write-Ok "created startup shortcut: $shortcutPath -> $ahkFile"
        }
    } else {
        Write-Warn 'keyboard\mac-shortcuts.ahk not found — add your AutoHotkey script, then re-run: install.ps1 keyboard'
    }
}

function Invoke-Apps {
    $appsFile = Join-Path $RepoRoot 'apps\apps.json'
    if (-not (Test-Path $appsFile)) {
        Write-Warn 'apps\apps.json not found — nothing to install'
        return
    }

    $apps = Get-Content $appsFile -Raw | ConvertFrom-Json
    foreach ($app in $apps) {
        $installed = winget list --id $app.id --exact 2>$null | Select-String -SimpleMatch $app.id
        if ($installed) {
            Write-Ok "already installed: $($app.name) ($($app.id))"
        } else {
            Write-Info "installing $($app.name) ($($app.id))"
            winget install --id $app.id -e --silent --accept-package-agreements --accept-source-agreements
        }
    }
}

function Invoke-Settings {
    Write-Info 'Explorer: showing file extensions and hidden files'
    $advancedPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    Set-ItemProperty -Path $advancedPath -Name 'HideFileExt' -Value 0
    Set-ItemProperty -Path $advancedPath -Name 'Hidden' -Value 1
    Write-Ok 'Explorer settings updated'

    Write-Info 'enabling dark mode'
    $personalizePath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    Set-ItemProperty -Path $personalizePath -Name 'AppsUseLightTheme' -Value 0
    Set-ItemProperty -Path $personalizePath -Name 'SystemUsesLightTheme' -Value 0
    Write-Ok 'dark mode enabled'

    Write-Warn 'sign out and back in (or restart explorer.exe) for all changes to take full effect'
}

function Invoke-Terminal {
    $settingsPath = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
    if (-not (Test-Path $settingsPath)) {
        Write-Warn 'Windows Terminal settings.json not found — launch Windows Terminal once first, then re-run: install.ps1 terminal'
        return
    }

    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
    $ubuntuProfile = $settings.profiles.list | Where-Object { $_.name -match 'Ubuntu' } | Select-Object -First 1

    if (-not $ubuntuProfile) {
        Write-Warn 'no Ubuntu profile found in Windows Terminal yet — run install.ps1 wsl first so it is detected, then re-run: install.ps1 terminal'
        return
    }

    if ($settings.defaultProfile -eq $ubuntuProfile.guid) {
        Write-Ok 'default profile already set to Ubuntu'
        return
    }

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backup = "$settingsPath.bak.$stamp"
    Copy-Item -Path $settingsPath -Destination $backup
    Write-Ok "backed up $settingsPath -> $backup"

    $settings.defaultProfile = $ubuntuProfile.guid
    $settings | ConvertTo-Json -Depth 32 | Set-Content -Path $settingsPath -Encoding utf8
    Write-Ok "default Windows Terminal profile set to $($ubuntuProfile.name)"
}

function Invoke-Wsl {
    $distros = wsl -l -q 2>$null
    if ($distros -match 'Ubuntu') {
        Write-Ok 'Ubuntu already installed under WSL'
    } else {
        Write-Info 'installing WSL2 + Ubuntu (this may require a reboot on first run)'
        wsl --install -d Ubuntu
        Write-Warn 'if this was the first WSL install on this machine, reboot, finish the Ubuntu first-run prompts, then re-run: install.ps1 wsl'
        return
    }

    Write-Info 'cloning + running dotfiles inside WSL Ubuntu'
    $cloneAndInstall = 'if [ ! -d ~/dotfiles ]; then git clone git@github.com:leongyeehang/dotfiles ~/dotfiles; fi && ~/dotfiles/install.sh all'
    wsl -d Ubuntu -- bash -c $cloneAndInstall
    Write-Ok 'dotfiles installed inside WSL Ubuntu'
}

function Invoke-All {
    Invoke-Ssh
    Invoke-Keyboard
    Invoke-Apps
    Invoke-Settings
    Invoke-Terminal
    Invoke-Wsl
}

function Show-Help {
    @'
windowsconfig installer

Usage:
  install.ps1 <command>

Commands:
  ssh        generate an SSH key if missing, wait for it to be added to GitHub
  keyboard   import SharpKeys scancode map + set up AutoHotkey autostart
  apps       install apps listed in apps/apps.json via winget
  settings   Explorer (extensions/hidden files) + dark mode registry tweaks
  terminal   set Windows Terminal's default profile to WSL Ubuntu
  wsl        install WSL2 + Ubuntu, then clone/run the dotfiles repo inside it
  all        run every command above, in order
  help       show this message
'@ | Write-Host
}

$ElevatedCommands = @('keyboard', 'apps', 'settings', 'terminal', 'wsl', 'all')

if ($Command -in $ElevatedCommands -and -not (Test-IsElevated)) {
    Write-Info 'not running elevated — relaunching under UAC'
    Start-Process powershell -Verb RunAs -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, $Command)
    exit
}

switch ($Command) {
    'ssh'      { Invoke-Ssh }
    'keyboard' { Invoke-Keyboard }
    'apps'     { Invoke-Apps }
    'settings' { Invoke-Settings }
    'terminal' { Invoke-Terminal }
    'wsl'      { Invoke-Wsl }
    'all'      { Invoke-All }
    'help'     { Show-Help }
}
