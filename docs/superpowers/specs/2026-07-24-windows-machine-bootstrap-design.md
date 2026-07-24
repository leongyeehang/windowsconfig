# Windows Machine Bootstrap — Design

**Date:** 2026-07-24
**Status:** Approved for planning

## Purpose

`windowsconfig` is a public GitHub repo that rebuilds a fresh Windows machine to a
known, mac-like setup from a single command: keyboard remapping (SharpKeys +
AutoHotkey) so a macOS keyboard layout works naturally on Windows, the usual
apps (via winget), a handful of Explorer/theme tweaks, Windows Terminal
configuration, and a bootstrapped WSL2 Ubuntu instance running the existing
[dotfiles](https://github.com/leongyeehang/dotfiles) repo.

It plays the same role for the Windows host that `dotfiles` plays for the
shell/editor environment: a snapshot of configuration plus a one-command
installer, so the machine can be rebuilt without having to remember what was
changed by hand.

## Repo layout

```
windowsconfig/
├── README.md
├── bootstrap.ps1        # entry point for: irm <raw-url>/bootstrap.ps1 | iex
├── install.ps1           # main installer: cmd_* functions + subcommand dispatch
├── keyboard/
│   ├── mac-layout.reg    # SharpKeys scancode map export (provided by user later)
│   └── mac-shortcuts.ahk # AutoHotkey script (provided by user later)
├── apps/
│   └── apps.json         # winget package IDs — placeholder w/ git, PowerShell 7 as examples
└── terminal/
    └── settings.json     # Windows Terminal settings (theme/font, WSL Ubuntu as default profile)
```

This mirrors the `dotfiles` repo's conventions: a README with a quick-start
block and an "installed via" table, a single installer script with
subcommands, and idempotent, backed-up file operations.

## Bootstrap flow

1. On a brand-new machine, run in a plain PowerShell window:
   ```powershell
   irm https://raw.githubusercontent.com/leongyeehang/windowsconfig/main/bootstrap.ps1 | iex
   ```
   The repo is public, so this works with no authentication.
2. `bootstrap.ps1` checks for and installs `git` and `winget` if missing,
   clones `windowsconfig` to `~/windowsconfig`, then invokes `install.ps1 all`.
3. `install.ps1` detects whether it is running elevated. If not, it
   **self-relaunches under UAC** (one user approval click) — required because
   the keyboard scancode map, WSL feature enablement, and some winget
   installs need admin rights.
4. `cmd_all` runs every module in a fixed order: `ssh` → `keyboard` → `apps`
   → `settings` → `terminal` → `wsl`.

## `install.ps1` subcommands

Single script, `cmd_*` PowerShell function per module, dispatched via a
`switch` on the first argument — the same shape as `dotfiles/install.sh`'s
`case` dispatch and `info`/`warn`/`ok` colored-output helpers.

- **`ssh`** — checks for an existing ed25519 key. If missing, generates one,
  prints the public key, and pauses for the user to add it to GitHub before
  continuing. Needed to clone the private `dotfiles` repo over SSH inside
  WSL.
- **`keyboard`** — imports `keyboard/mac-layout.reg` (SharpKeys' HKLM
  scancode map) via `reg import`; installs AutoHotkey via winget if absent;
  places a shortcut to `keyboard/mac-shortcuts.ahk` in `shell:startup` so it
  launches at every login.
- **`apps`** — reads `apps/apps.json` and runs `winget install --id <id>`
  for each entry, skipping ones already installed.
- **`settings`** — registry tweaks: Explorer `HideFileExt=0` and show hidden
  files, plus dark mode (`AppsUseLightTheme`/`SystemUsesLightTheme = 0`).
- **`terminal`** — symlinks (with backup) `terminal/settings.json` to
  Windows Terminal's real settings path, defaulting the startup profile to
  WSL Ubuntu.
- **`wsl`** — runs `wsl --install -d Ubuntu` (enables the WSL2 feature and
  installs the distro if not already present), then runs
  `wsl -d Ubuntu -- bash -c "git clone git@github.com:leongyeehang/dotfiles ~/dotfiles && ~/dotfiles/install.sh all"`,
  chaining into the existing dotfiles installer.
- **`all`** — runs the modules above in order.
- **`help`** — usage text, in the same style as the dotfiles README's command
  table.

## Idempotency & safety

Every step is safe to re-run:

- Registry imports are idempotent by nature.
- `winget install` no-ops on already-installed packages.
- Symlinks/shortcuts check-before-overwrite using the same
  `<file>.bak.<timestamp>` backup pattern as `dotfiles/install.sh`'s `link()`
  function.
- The SSH step no-ops if a key already exists.

## README

Same style as the `dotfiles` README: a TL;DR quick-start block, a "what's
installed and where it comes from" table, per-module explanation sections,
and an explicit note that `apps/apps.json` and the `keyboard/` files are
placeholders — the winget list and the actual SharpKeys/AutoHotkey files are
filled in by the user after this initial scaffold.

## Implementation note (deviation from the plan above)

The `terminal` module does **not** symlink a repo-tracked `terminal/settings.json`
as originally described. Windows Terminal auto-generates its real
`settings.json` on first launch, including a machine-specific GUID for each
detected WSL distro — a blind symlink-replace would wipe that out. Instead,
`install.ps1 terminal` reads the live settings file, finds the profile named
`Ubuntu`, sets `defaultProfile` to its GUID, and backs up the original before
writing. No `terminal/` directory exists in the repo as a result.

The `keyboard` module also deviates: the user's actual export was a
SharpKeys `.skl` key list, not a `.reg` registry export. Reading SharpKeys'
source showed a `.skl` file is literally the raw bytes SharpKeys itself
writes to the registry's `Scancode Map` value — `SaveMappingsToRegistry()`
and the `.skl` save handler both serialize the same `DefineScancodeMap()`
byte array, just to different destinations. So `install.ps1 keyboard` reads
`keyboard/mac-layout.skl` and writes those bytes directly into
`HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layout` — no SharpKeys GUI
interaction needed to apply it. SharpKeys is still listed in
`apps/apps.json` so it's available for designing new mappings later.

## Out of scope for v1

- Multiple git identities (work/personal split) on the Windows side.
- VS Code settings sync / Remote-WSL setup.
- Native PowerShell profile customization.

These can be layered in later, the same incremental way the `dotfiles` repo
grew over time.
