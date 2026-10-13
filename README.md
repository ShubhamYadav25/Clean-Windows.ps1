# Windows Cleanup Utility

A PowerShell script that scans common Windows temporary files, caches, logs, crash dumps, and the Recycle Bin, then estimates how much disk space could be recovered. You can preview the results, inspect the source folders, and choose exactly which categories to clean.

> **Important:** This script can permanently delete files and clear Windows Event Logs. Review the selected categories before confirming. Run PowerShell as Administrator for the most complete scan; without elevation, protected system locations may be skipped or undercounted.

## Features

- Scans common temporary files and crash dumps.
- Checks Windows error reports and DirectX/GPU shader caches.
- Scans caches for Chrome, Edge, Firefox, Brave, Opera, and Vivaldi.
- Includes Windows/IIS logs, Windows Update downloads, and Delivery Optimization cache.
- Includes thumbnail/icon caches, Prefetch, Windows Defender history/support logs, Store/app caches, Office/Teams caches, and selected application caches.
- Includes developer package caches for npm, Yarn, pip, and NuGet.
- Can scan Windows Event Logs (`.evtx`) and the Recycle Bin.
- Displays numbered categories, estimated size, and file count.
- Supports dry runs, detailed per-folder reporting, selection by number/range, and non-interactive confirmation bypass.
- Reports an approximate amount freed after cleaning.

## Requirements

- Windows with Windows PowerShell or a compatible PowerShell environment.
- Permission to access the target locations. Administrator privileges are recommended.
- The script file saved as `Clean-Windows.ps1`.

## Usage

Open PowerShell in the directory containing the script.

### 1. Preview only (recommended first step)

```powershell
.\Clean-Windows.ps1 -DryRun
```

Scans and lists the categories and approximate recoverable space. **Nothing is deleted.**

### 2. Preview with folder-level details

```powershell
.\Clean-Windows.ps1 -DryRun -Detail
```

Shows the scanned paths and estimated size for each path, helping you see where the space is being used.

### 3. Clean selected categories

```powershell
.\Clean-Windows.ps1 -Select "1,3,5-6"
```

Cleans categories 1, 3, 5, and 6 after showing the selection and asking for confirmation.

You can provide a single category:

```powershell
.\Clean-Windows.ps1 -Select "1"
```

You can also use ranges:

```powershell
.\Clean-Windows.ps1 -Select "3-6"
```

### 4. Clean all categories

```powershell
.\Clean-Windows.ps1 -All
```

Selects every category in the script and asks for confirmation before cleaning.

The script also accepts `all` as the selection when prompted:

```text
Enter numbers to clean (e.g. 1,3,5-6), 'all' for everything, or Enter to quit: all
```

### 5. Show the list and choose interactively

```powershell
.\Clean-Windows.ps1
```

Scans the system, displays the numbered categories and estimates, then asks which categories to clean. Press Enter at the selection prompt to quit without cleaning.

### 6. Skip the confirmation prompt

```powershell
.\Clean-Windows.ps1 -Select "1,3" -Yes
```

Or, to clean every category without the final confirmation prompt:

```powershell
.\Clean-Windows.ps1 -All -Yes
```

> **Caution:** `-Yes` bypasses the final `YES` confirmation. Use it only when you have reviewed the categories and are certain about the selection.

## Parameters

| Parameter | Description |
|---|---|
| `-DryRun` | Scans and reports estimated recoverable space without deleting anything. |
| `-Select "1,3,5-6"` | Cleans only the specified category numbers or ranges. |
| `-All` | Selects all categories for cleaning. |
| `-Detail` | Shows folder-level size details in the scan report. |
| `-Yes` | Skips the final confirmation prompt. |

## Categories scanned

The script builds its numbered list from the categories configured in `Clean-Windows.ps1`. The list below describes the categories currently defined in the script:

1. Temporary files and crash dumps
2. Windows error reports and DirectX shader cache
3. Google Chrome cache
4. Microsoft Edge cache
5. Mozilla Firefox cache
6. Other browser caches (Brave, Opera, Vivaldi)
7. Temporary Internet Files and Java cache
8. Windows and IIS log files (including CBS, DISM, and setup-related locations)
9. Windows Update download cache
10. Delivery Optimization cache
11. Thumbnail and icon cache
12. Prefetch
13. Windows Defender scan history and support logs
14. Microsoft Store and app package caches
15. Microsoft Office and Teams caches
16. Selected app caches (Discord, Slack, Spotify, VS Code, Zoom)
17. Developer package caches (npm, Yarn, pip, NuGet)
18. Windows Event Logs (`.evtx`)
19. Recycle Bin (all detected filesystem drives)

Category numbers depend on the order of `$categories` in the script. If you edit or reorder that array, check the displayed list before using `-Select`.

## Recommended workflow

1. **Preview:** Run `.\Clean-Windows.ps1 -DryRun -Detail`.
2. **Review:** Check the category numbers, folder paths, and estimated sizes.
3. **Choose:** Run the script with `-Select "..."` for the categories you want to clean.
4. **Confirm:** Review the “Will clean” list and type `YES` only if you want to proceed.
5. **Verify:** Read the final “Total freed” estimate.

The reported size is an estimate. Files may be locked, inaccessible, or changed between scanning and cleaning, so the amount actually freed can differ from the preview.

## Important safety notes

- **Permanent deletion:** The script uses file deletion commands; it does not move ordinary deleted files to the Recycle Bin.
- **Windows Event Logs:** Selecting this category clears event logs. This may remove troubleshooting, audit, and diagnostic history. Leave it unselected unless you intentionally want to clear those logs.
- **Windows and IIS logs:** These may be useful for diagnosing update, setup, application, or server problems. Consider preserving them if you are investigating an issue.
- **Windows Update cache:** The script stops and restarts the Windows Update (`wuauserv`) and Background Intelligent Transfer Service (`BITS`) services around this cleanup. Running as Administrator is recommended.
- **Caches:** Many caches are recreated automatically, but the first launch or use of an application after cleanup may be slower while caches rebuild.
- **Prefetch:** Windows normally manages this folder itself. Clearing it may temporarily affect application startup performance; it is not usually necessary for routine cleanup.
- **Defender history/support data:** Removing this data can reduce the diagnostic history available for security troubleshooting.
- **Recycle Bin:** Cleaning this category empties the Recycle Bin for the detected drives; review its contents first if you may need to restore files.
- **Open applications:** Close browsers and apps before cleaning their caches where possible. Files currently in use may be skipped.
- **Review before running:** Use `-DryRun` first and avoid `-All` unless you understand every category.

## Troubleshooting

### Some files were not deleted

Some files may be in use, protected, or inaccessible. Close related applications and rerun the script from an elevated PowerShell session if appropriate.

### The estimated space differs from the space freed

The scan is a point-in-time estimate. Files can be locked, deleted, or created between the scan and cleanup. The script rescans each category to estimate what was actually removed.

### System locations appear missing or smaller than expected

Run PowerShell as Administrator. Access restrictions can cause system folders to be skipped or undercounted.

### PowerShell does not allow the script to run

If execution policy blocks the script, inspect your organization's policy and PowerShell execution-policy settings before changing anything. If appropriate for your environment, you can run it for the current process only:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\Clean-Windows.ps1 -DryRun
```

Only run scripts you trust and have reviewed.

## Customization

The cleanup categories are defined in the `$categories` array in `Clean-Windows.ps1`. Each category specifies a name, a type (`Files`, `EventLogs`, or `RecycleBin`), and one or more paths. Some categories also define pre- and post-cleanup actions.

Review any path or behavior changes carefully. Avoid adding folders that contain personal files, application data, or information you may need later.

## License

No license is specified in the provided script. Add a license file if you intend to distribute this project publicly.
