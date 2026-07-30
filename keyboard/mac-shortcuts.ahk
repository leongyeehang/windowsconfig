#Requires AutoHotkey v2.0
#SingleInstance Force

; =============================================================================
; ORIGINAL v2 SCRIPT (prabowomurti, Dec 2025) — PRESERVED VERBATIM BELOW
; =============================================================================

; as a flag for Switching Apps process status
global isAltTabbing := false

; ADDED: if the script exits or reloads mid-switch (tray Exit, Reload Script),
; the synthetic Alt below would be left held down. Release it on the way out.
; Must live in the auto-execute section, above the first hotkey, to register.
OnExit(ReleaseAltOnExit)

ReleaseAltOnExit(*)
{
    EndAltTab()
    return 0        ; an OnExit callback that returns truthy CANCELS the exit
}

;  Switching Apps
LCtrl & Tab::
{
    global isAltTabbing
    shiftHeld := GetKeyState("Shift", "P")              ; <-- ADDED: detect Shift for reverse cycling
    if (!isAltTabbing) {
        isAltTabbing := true
        Send shiftHeld ? "{Alt Down}+{Tab}" : "{Alt Down}{Tab}"   ; <-- ADDED: + when shift held
        SetTimer(AltTabWatchdog, 250)                   ; <-- ADDED: see EndAltTab() below
    } else {
        Send shiftHeld ? "+{Tab}" : "{Tab}"             ; <-- ADDED: + when shift held
    }
}

~LCtrl Up::EndAltTab()                                  ; <-- CHANGED: single release path

; Exception for multitasking view frame
#HotIf isAltTabbing
    ; while in the state of choosing the window, send Arrow as it is
    ^Left::Send "{Left}"
    ^Right::Send "{Right}"
    ^Up::Send "{Up}"
    ^Down::Send "{Down}"

    ; commit the highlighted window (releasing Alt is what alt-tab acts on)
    Enter::EndAltTab()

    ; ADDED: cancel and stay on the current window. Escape must go out while Alt
    ; is still held — that is what dismisses the switcher — then release Alt.
    Escape::
    {
        Send "{Escape}"
        EndAltTab()
    }
#HotIf

; --- Alt-Tab watchdog (ADDED) ---
; The switcher above holds a synthetic Alt down between Ctrl+Tab presses and
; releases it on ~LCtrl Up. If that up-event never arrives — focus stolen by
; another app, an RDP/VM session grabbing input, the script suspended or
; reloaded mid-hold — Alt stays logically down forever and every later keypress
; acts as Alt+key. This timer notices the physical Ctrl is no longer held and
; cleans up. Every path out of alt-tab funnels through EndAltTab().
EndAltTab()
{
    global isAltTabbing
    SetTimer(AltTabWatchdog, 0)
    if (!isAltTabbing)                  ; guard: a lone Alt-up with Alt not down
        return                          ; would pop the focused window's menu bar
    isAltTabbing := false
    Send "{Blind}{Alt Up}"
}

AltTabWatchdog()
{
    global isAltTabbing
    if (!isAltTabbing || !GetKeyState("LCtrl", "P"))
        EndAltTab()
}

; --- Browser/App Tab Switching ---
; Alt + Tab triggers Ctrl + Tab (Next Tab)
!Tab::Send "^{Tab}"
; Alt + Shift + Tab sends Ctrl + Shift + Tab (Previous Tab)
!+Tab::Send "^+{Tab}"

; --- Start Menu or Copilot overlay / Spotlight wannabe ---
; Ctrl + Space sends Ctrl + Esc
;^Space::Send "^{Esc}"
;^Space::Send "!{Space}"                  ; <-- DISABLED: let Ctrl+Space pass through to Raycast.
                                          ;     Set Raycast's hotkey to Ctrl+Space in Raycast Settings.

; --- Navigation Shortcuts (Mac Style) ---
; Command + Left (Home)
^Left::Send "{Home}"

; Command + Right (End)
^Right::Send "{End}"

; Command + Shift + Left (Select to Home)
^+Left::Send "+{Home}"

; Command + Shift + Right (Select to End)
^+Right::Send "+{End}"

; Command + Up (Top of Document)
^Up::Send "^{Home}"

; Command + Down (Bottom of Document)
^Down::Send "^{End}"

; Command + Shift + Up (Select to Top)
^+Up::Send "^+{Home}"

; Command + Shift + Down (Select to Bottom)
^+Down::Send "^+{End}"

; --- Custom Page Up/Down ---
; Windows + Up Arrow turns to Page Up
#Up::Send "{PgUp}"

; Windows + Down Arrow turns to Page Down
#Down::Send "{PgDn}"

; Windows + Left = Jumps one word (Ctrl + Left)
#Left::Send "^{Left}"

; Windows + Right = Jumps one word (Ctrl + Right)
#Right::Send "^{Right}"

; Windows + Shift + Left = (Ctrl + Shift + Left)
#+Left::Send "^+{Left}"

; Windows + Shift + Right = (Ctrl + Shift + Right)
#+Right::Send "^+{Right}"

; Delete per word
#Backspace::Send "^{Backspace}"

; Delete one line
$^Backspace::Send "+{Home}{Backspace}"
;^Backspace::Send "+{Home}{Backspace}"

; Optional: Windows (Option) + Delete = Delete Word to Right
#Delete::Send "^{Delete}"

; Sniping Tool (partial)
^+4::Send "#+s"

; Sniping Tool (full screen)
^+3::Send "{PrintScreen}"

; Cmd (Ctrl) + Opt (Win) + Left = Previous Tab
^#Left::Send "^{PgUp}"

; Cmd (Ctrl) + Opt (Win) + Right = Next Tab
^#Right::Send "^{PgDn}"

; Quit Application
^q::Send "!{F4}"

; Custom script to mimic cycle through different windows but in the same app
^`::
{
    try {
        ; try to get active windows
        activeExe := WinGetProcessName("A")
        ; get the most bottom stack
        WinActivateBottom "ahk_exe " activeExe
    }
}

; REMOVED: Alt+Left/Right = switch virtual desktop (^#{Left} / ^#{Right}).
; Alt got left logically stuck down. Alt is physically held when the hotkey
; fires, so AHK releases it to send Ctrl+Win+Arrow and re-presses it after —
; but the desktop switch changes the foreground window mid-sequence, so the
; real Alt-up can land on a window that never saw the Alt-down. Windows then
; treats Alt as held forever (every keypress acts as Alt+key).
; Use Ctrl+Win+Left/Right (the Windows native binding) directly instead.


; =============================================================================
; ADDITIONS — everything below this line is new, v2 above is untouched
; =============================================================================

; --- Pause / resume the whole script (gaming, RDP, VM safety net) ---
; Ctrl + Shift + Pause
^+Pause::{
    EndAltTab()                         ; <-- ADDED: suspending stops ~LCtrl Up from
                                        ;     firing, which would strand Alt down
    Suspend(-1)
    TrayTip(A_IsSuspended ? "macOS keys: PAUSED" : "macOS keys: ACTIVE", "AutoHotkey", 1)
}

; --- Cmd + M = Minimise window ---
^m::Send "#{Down}"

; --- Cmd + Opt + Esc = Force Quit (Task Manager) ---
^!Escape::Send "^+{Escape}"

; --- Cmd + F3 = Show Desktop ---
^F3::Send "#d"

; --- Cmd + Shift + 5 = Screen recording (Game Bar; needs it enabled in Settings) ---
^+5::Send "#!r"

; --- Cmd + Delete = Delete to end of line (companion to v2's Cmd+Backspace) ---
$^Delete::Send "+{End}{Delete}"

; --- Sleep computer (Cmd + Opt + F12) ---
^!F12::Run "rundll32.exe powrprof.dll,SetSuspendState 0,1,0"

; --- Lock screen (Cmd + Opt + L) ---
; Note: real Mac uses Ctrl+Cmd+Q, but Ctrl and Cmd both send Ctrl after our
; LWin->LCtrl swap, so they're indistinguishable. Cmd+Opt+L is the workaround.
; Win+L (Windows native) also still works — feel free to ignore this binding.
^!l::DllCall("user32.dll\LockWorkStation")

; --- Shutdown with 10-second abort window (Cmd + Opt + Shift + F12) ---
; Run "shutdown /a" within 10 seconds to cancel.
^!+F12::Run "shutdown /s /t 10 /c `"Shutdown via macOS-keys script. Run 'shutdown /a' to abort.`""


; =============================================================================
; SCENARIOS NOT COVERED BY THIS SCRIPT
; =============================================================================
; Reference for what's intentionally left out, what works natively, and what
; this kind of remap fundamentally cannot do.
;
; -----------------------------------------------------------------------------
; A. WORKS NATIVELY AFTER THE LWIN -> LCTRL SWAP (no script entry needed)
; -----------------------------------------------------------------------------
; These Mac shortcuts already map identically to Windows Ctrl+ equivalents,
; so pressing Cmd+<key> just sends Ctrl+<key> and Windows/the app handles it:
;
;   Cmd+C / V / X / Z         Copy / Paste / Cut / Undo
;   Cmd+Shift+Z               Redo
;   Cmd+A                     Select All
;   Cmd+S                     Save
;   Cmd+F                     Find
;   Cmd+G / Cmd+Shift+G       Find next / previous
;   Cmd+P                     Print
;   Cmd+N / Cmd+Shift+N       New window / new incognito window
;   Cmd+T / Cmd+Shift+T       New tab / reopen closed tab
;   Cmd+W                     Close tab/window
;   Cmd+R                     Reload page
;   Cmd+L                     Focus address bar
;   Cmd+1..9                  Switch to tab 1..9
;   Cmd+= / Cmd+-             Zoom in / out
;   Cmd+0                     Reset zoom
;   Cmd+B / Cmd+I / Cmd+U     Bold / Italic / Underline (in editors)
;
; -----------------------------------------------------------------------------
; B. DELIBERATELY NOT BOUND (no clean Windows equivalent or too risky)
; -----------------------------------------------------------------------------
;   Cmd+,                Open app preferences/settings
;                        -> No universal Windows convention; varies per app.
;
;   Cmd+H                Hide app
;                        -> Closest is minimise (^m::Send "#{Down}"). Not bound
;                           because Ctrl+H = Find/Replace in many editors.
;
;   Cmd+Opt+W            Close all windows of current app
;                        -> Would need per-app logic; complicated.
;
;   Cmd+Shift+.          Show/hide hidden files in Finder
;                        -> Explorer has no hotkey for this; must use the
;                           View ribbon or registry edit.
;
;   Cmd+Shift+D          Open Desktop folder
;                        -> Conflicts with Win+D (show desktop). Use Win+E
;                           and navigate, or pin Desktop.
;
;   Cmd+Opt+D            Show/hide Dock
;                        -> Closest is auto-hide taskbar, not a hotkey.
;
;   Ctrl+Cmd+Power       Force restart
;                        -> Not bound: too easy to fat-finger. Use shutdown /r
;                           from a terminal or the Start menu.
;
;   Ctrl+Shift+Power     Display-only sleep (lock screen but stay logged in)
;                        -> Needs nircmd.exe or similar third-party tool.
;                           Win+L is the closest native alternative.
;
;   F3 (alone)           Mission Control
;                        -> Could map to Win+Tab (Task View) but F3 = "Find Next"
;                           in many IDEs. Cmd+F3 is bound to Show Desktop instead.
;
;   Fn+A / Fn+C / Fn+N   Show Dock / Control Center / Notification Center
;                        -> No equivalents. Win+A opens Action Center (similar).
;
; -----------------------------------------------------------------------------
; C. CANNOT BE DONE WITH THIS REMAP APPROACH
; -----------------------------------------------------------------------------
;   1. Terminal Cmd+C vs Ctrl+C (SIGINT) collision
;      After the swap, both the corner Ctrl key AND the Cmd-position key send
;      Ctrl. So "Cmd+C to copy" and "Ctrl+C to interrupt a process" become
;      indistinguishable. In Windows Terminal / WSL / Git Bash this means
;      Cmd+C may kill your running process instead of copying.
;      Workaround: use Ctrl+Shift+C / Ctrl+Shift+V for copy/paste in terminals
;      (the modern default in Windows Terminal already).
;
;   2. Shortcuts that require Ctrl AND Cmd as separate modifiers
;      e.g. real Mac uses Ctrl+Cmd+Q for lock screen. Both keys send Ctrl after
;      the swap, so AHK can't tell them apart. Worked around with Cmd+Opt+L.
;      Same limitation applies to:
;        - Ctrl+Cmd+F (toggle fullscreen)
;        - Ctrl+Cmd+Space (Character Viewer / emoji picker — use Win+. instead)
;        - Ctrl+Cmd+arrows (in some apps for window snap)
;
;   3. Trackpad / gesture-based actions
;      Mission Control, Spaces, three/four-finger swipes, force-touch lookups —
;      these are hardware/driver-level on macOS. On Windows they depend on your
;      trackpad driver (Precision Touchpad settings) and are not keyboard-
;      remappable.
;
;   4. Globe (fn) key behaviour
;      Modern Mac keyboards have a Globe key with its own shortcuts (Globe+E
;      for emoji, Globe+F for fullscreen, etc). Logitech Mac-layout keyboards
;      typically don't have this key, so these shortcuts simply don't exist.
;
;   5. App-specific Cmd-key shortcuts that clash with Windows defaults
;      e.g. Cmd+M in Finder = minimise; in Microsoft Word, Ctrl+M = increase
;      indent. After the swap, Word's Ctrl+M still works (it's bound here too)
;      but you may need to retrain muscle memory for app-specific edge cases.
; =============================================================================
