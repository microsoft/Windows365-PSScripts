# Dev Ready Image Uninstaller

A PowerShell script for **external customers** who have provisioned a Cloud PC from the Windows 365 **Dev Ready Image** and want to remove all of the bundled third-party developer tools from their machine.

After Node.js is uninstalled, the script also reinstalls **GitHub Copilot CLI** in its standalone form so the `copilot` command keeps working without Node.js.

## What it removes

- **Python 3.13** (MSI + the `C:\Python313` install directory)
- **Node.js LTS** (winget package)
- **nvm-windows** (`%ProgramData%\nvm` and the `%ProgramFiles%\nodejs` symlink)
- **oh-my-posh** (`%ProgramFiles%\oh-my-posh`) and the **Cascadia Code / Cascadia Mono** Nerd Font variants it installs (registry + font files)
- **uv tools** (`%ProgramData%\UVTools`)
- **Ubuntu WSL** distribution (VHDX, install folder, and `HKCU\Software\Microsoft\Windows\CurrentVersion\Lxss` registry keys, including the default-user entry)
- Tool entries added to the **machine `PATH`**
- The `oh-my-posh` blocks in the **Windows Terminal** `settings.json` and the PowerShell `Microsoft.PowerShell_profile.ps1` files for every local user

## What it reinstalls

After Node.js is removed, the script reinstalls the **standalone GitHub Copilot CLI** via winget (`GitHub.Copilot`) and patches the existing npm shims (`%ProgramData%\npm\copilot.ps1` and `copilot.cmd`) to point at the standalone executable. This keeps the `copilot` command — and the Start Menu shortcut — working without Node.js.

## Prerequisites

- Windows PowerShell **5.1** or PowerShell **7+**
- **Run as Administrator** (the script enforces this)
- Internet access (winget needs it for the Copilot CLI reinstall)
- A **reboot** is recommended after the script completes (font cache, `PATH`, and WSL changes do not all take effect until next sign-in)

## Usage

From an **elevated** PowerShell window:

```powershell
cd DevReadyImage-Uninstaller
.\Uninstall-ThirdPartyTools.ps1
```

The script:

1. Scans the machine and prints a **removal plan** of everything it would touch.
2. Asks you to confirm (`Y` / `N`) before changing anything.
3. Runs each removal step, printing one section per item.
4. If Node.js was removed, reinstalls Copilot CLI standalone and verifies `copilot.exe` is on `PATH`.

## Logging

A full PowerShell transcript of every run is written to:

```
%TEMP%\Uninstall-ThirdPartyTools_<yyyyMMdd_HHmmss>.log
```

Attach this file when reporting issues.

## Notes & known behavior

- The script **deletes** any `Microsoft.PowerShell_profile.ps1` that references `oh-my-posh` rather than editing it. Back the file up first if you have custom content you want to keep.
- The Ubuntu removal calls `wsl --shutdown` before deleting the VHDX so the file is not locked. If the delete still fails, sign out and re-run.
- Some MSI components (Python in particular) must be uninstalled in a specific order; the script handles this with a 3-pass sort, but a non-zero MSI exit code on the first pass is normal and not fatal.
- The Copilot CLI reinstall step is **skipped** if Node.js was not actually present (nothing to fix up).