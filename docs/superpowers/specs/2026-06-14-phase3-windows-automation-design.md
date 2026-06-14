# Phase 3: Windows Automatic Installation Design

## Overview

Transform `windows/setup.ps1` from a download-only orchestrator into a full interactive installer: download → extract/install → configure PATH → verify.

## Architecture

Three PowerShell scripts: `setup.ps1` (interactive orchestrator), `install.ps1` (installation functions per language), `config.ps1` (PATH + env var configuration). Keep `01-check.ps1` and `02-download.ps1` mostly intact but called as sub-steps.

## Design Decisions (from grill)

- **Install base**: `$HOME\local\envs`
- **Go**: zip from go.dev (dynamic version via API)
- **Java**: Oracle JDK 21 zip
- **Python**: embeddable zip + `uv` for venv management
- **msys2**: exe silenc install (`--quiet --root`)
- **Download packages**: kept in `$installPath\packages\` for caching
- **PATH**: add `$installPath\go\bin`, `$installPath\java\jdk-21\bin`, `$installPath\python`, `$installPath\msys2\usr\bin` to USER PATH
- **uv**: download `uv.exe` to `$installPath\python\` and add to PATH

## File Structure

### Modified files

| File | What changes |
|---|---|
| `windows/setup.ps1` | Rewrite — interactive questions → download → install → PATH → verify |
| `windows/02-download.ps1` | Adapt — return download paths, accept cache reuse flag |

### New files

| File | Responsibility |
|---|---|
| `windows/install.ps1` | `Install-Msys2`, `Install-Go`, `Install-Java`, `Install-Python` — each handles extraction/silent install |
| `windows/config.ps1` | `Set-EnvPath` — add tool bin dirs to user PATH, set `JAVA_HOME` |
| `windows/verify.ps1` | `Verify-Installation` — check all chosen tools exist and report |
| `docs/plans/2026-06-14-phase3-windows-automation.md` | Implementation plan |

## Design

### setup.ps1 orchestration flow

```
setup.ps1 (Run as Administrator recommended)
├── [0] Check Admin → warn if not
├── [1] Interactive questions (if no profile)
│   ├── Install base path (default: $HOME\local\envs)
│   ├── Install Go? (Y/n)
│   ├── Install Java JDK 21? (Y/n)
│   ├── Install Python (embeddable + uv)? (Y/n)
│   ├── Install msys2 (C/C++)? (Y/n)
│   └── Save answers to $HOME\.config\envbat\profile.ps1
├── [2] Run 01-check.ps1 (detect existing installations)
├── [3] Run 02-download.ps1 (download to packages\ dir, reuse cache)
├── [4] Run install.ps1
│   ├── For each chosen language:
│   │   ├── If install dir exists → skip
│   │   ├── Go → unzip to $base\go\
│   │   ├── Java → unzip to $base\java\jdk-21\
│   │   ├── Python → unzip to $base\python\ + download uv.exe
│   │   └── msys2 → run exe --quiet --root $base\msys64
│   │   └── Each: symlink .exe to $base\bin\ (or add to PATH)
├── [5] Run config.ps1
│   ├── For each installed tool: add bin dir to USER PATH
│   ├── Set JAVA_HOME
│   └── Reload PATH in current session (or hint to log out)
├── [6] Run verify.ps1 (check go, java, python, uv, gcc)
└── [7] Summary
```

### PATH strategy

Add to USER environment variable `PATH` (persistent):
```
$HOME\local\envs\bin\                       ← symlinks hub (optional)
$HOME\local\envs\go\bin\
$HOME\local\envs\java\jdk-21\bin\
$HOME\local\envs\python\
$HOME\local\envs\msys64\usr\bin\            ← gcc, g++
```

Alternatively, create a `$base\bin\` directory with `.bat` wrappers that forward to each tool. This keeps PATH minimal (only one entry) and avoids accumulating stale PATH entries when versions change. But for simplicity, direct PATH entries are fine for now.
