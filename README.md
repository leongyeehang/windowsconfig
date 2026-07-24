# windowsconfig

My Windows machine setup: a macOS keyboard layout (**SharpKeys** + **AutoHotkey**), the
usual apps (**winget**), a couple of Explorer/theme tweaks, **Windows Terminal**
defaulting into WSL, and a bootstrapped **WSL2 Ubuntu** running my
[dotfiles](https://github.com/leongyeehang/dotfiles) repo.

This repo is a snapshot of that config plus a one-command installer, so I can
rebuild the same machine from scratch without trying to remember what I
changed. It plays the same role for the Windows host that `dotfiles` plays for
the shell/editor environment.

---

## TL;DR — new machine

In a plain PowerShell window:

```powershell
irm https://raw.githubusercontent.com/leongyeehang/windowsconfig/main/bootstrap.ps1 | iex
```

That installs git/winget prerequisites, clones this repo to `~/windowsconfig`,
and hands off to `install.ps1 all`, which self-elevates (one UAC prompt) and
runs every module in order: `ssh` → `keyboard` → `apps` → `settings` →
`terminal` → `wsl`.

Prefer to do it in stages, or re-run a single step?

```powershell
cd ~/windowsconfig
./install.ps1 ssh        # generate an SSH key if missing, wait for it to be added to GitHub
./install.ps1 keyboard   # import SharpKeys scancode map + set up AutoHotkey autostart
./install.ps1 apps       # install apps listed in apps/apps.json via winget
./install.ps1 settings   # Explorer (extensions/hidden files) + dark mode
./install.ps1 terminal   # set Windows Terminal's default profile to WSL Ubuntu
./install.ps1 wsl        # install WSL2 + Ubuntu, then clone/run dotfiles inside it
./install.ps1 all        # everything above, in order
```

Every step is safe to re-run: registry imports are idempotent, `winget`
skips already-installed packages, the startup shortcut is only created once,
`terminal` backs up the real `settings.json` to `settings.json.bak.<timestamp>`
before editing it, and `ssh` no-ops once a key exists.

> **First WSL install:** `wsl --install -d Ubuntu` may need a reboot and the
> Ubuntu first-run username/password prompt before it can be scripted into
> further. If `install.ps1 wsl` tells you to reboot, do so, finish the Ubuntu
> prompts, then re-run `install.ps1 wsl`.

---

## Repo layout

```
windowsconfig/
├── README.md              # this guide
├── bootstrap.ps1           # entry point for the irm | iex one-liner above
├── install.ps1              # installer (ssh | keyboard | apps | settings | terminal | wsl | all | help)
├── keyboard/
│   ├── mac-layout.reg      # SharpKeys scancode map export → imported via `reg import`
│   └── mac-shortcuts.ahk   # AutoHotkey script → autostart shortcut in shell:startup
└── apps/
    └── apps.json           # winget package IDs, installed by `install.ps1 apps`
```

> **Placeholders:** `keyboard/mac-layout.reg` and `keyboard/mac-shortcuts.ahk`
> aren't in the repo yet — `install.ps1 keyboard` warns and skips cleanly
> until they're added. `apps/apps.json` currently only lists `git` and
> `PowerShell 7` as examples; add the rest of your usual apps' winget package
> IDs (`winget search <name>`) as you go.

---

## The modules

### Keyboard — `keyboard/`

I use a Mac keyboard's physical layout on this Windows machine, so the
remap has two layers:

- **SharpKeys** (`mac-layout.reg`) — a low-level scancode swap (e.g. Ctrl/Alt
  physical position), exported from SharpKeys and imported straight into the
  registry (`HKLM\SYSTEM\CurrentControlSet\Control\Keyboard Layout`) via
  `reg import`. Takes effect after signing out or rebooting.
- **AutoHotkey** (`mac-shortcuts.ahk`) — the higher-level shortcut behavior
  SharpKeys can't do alone (e.g. Cmd-style app shortcuts). `install.ps1
  keyboard` installs AutoHotkey via winget if missing and drops a shortcut
  into `shell:startup` so it launches at every login.

### Apps — `apps/apps.json`

A flat list of `{ "id": "<winget package id>", "name": "<display name>" }`
entries. `install.ps1 apps` checks `winget list --id <id> --exact` first and
only installs what's missing, so re-running is a no-op once everything's
there.

### Settings — registry tweaks

`install.ps1 settings` sets two things under `HKCU`, no restart of Windows
required (just Explorer/sign-out to fully refresh):

- Explorer: `HideFileExt = 0` and `Hidden = 1` — always show file extensions
  and hidden files, like Finder.
- Dark mode: `AppsUseLightTheme` / `SystemUsesLightTheme = 0` under
  `...\Themes\Personalize`.

### Windows Terminal — `terminal/settings.json`

Windows Terminal auto-generates its `settings.json` (including a
machine-specific GUID for each detected WSL distro) the first time it's
launched, so this repo can't just symlink a static file over it without
wiping that out. Instead, `install.ps1 terminal` reads the real settings
file, finds the profile whose name matches `Ubuntu`, and sets
`defaultProfile` to that profile's GUID — backing up the original to
`settings.json.bak.<timestamp>` first. Launch Windows Terminal at least once
(so the Ubuntu profile exists) before running this step.

### WSL — Ubuntu + dotfiles

`install.ps1 wsl` runs `wsl --install -d Ubuntu` if it isn't already present,
then clones and runs my [dotfiles](https://github.com/leongyeehang/dotfiles)
repo inside it:

```bash
git clone git@github.com:leongyeehang/dotfiles ~/dotfiles && ~/dotfiles/install.sh all
```

That needs an SSH key registered with GitHub — see the `ssh` module below,
and inside WSL itself (this script runs it from the Windows side over
`wsl -d Ubuntu -- bash -c ...`, using whatever SSH setup already exists in
that WSL instance).

### SSH — `install.ps1 ssh`

Generates an `ed25519` keypair at `~/.ssh/id_ed25519` if one doesn't already
exist, prints the public key, and waits for you to add it to
[github.com/settings/keys](https://github.com/settings/keys) before
continuing. This is what lets the `wsl` module clone the private `dotfiles`
repo over SSH.

---

## Elevation

Most modules touch the registry, winget, or the WSL feature, so
`install.ps1` checks whether it's running as Administrator and
**self-relaunches under UAC** (one approval prompt) if not — you never need
to manually open an elevated PowerShell yourself.

---

## Out of scope (for now)

Multiple git identities (work/personal) on the Windows side, VS Code
settings sync, and a native PowerShell profile aren't covered yet — WSL
already covers the real dev environment via `dotfiles`. These can be added
incrementally later the same way `dotfiles` grew over time.
