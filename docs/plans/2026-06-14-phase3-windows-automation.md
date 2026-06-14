# Phase 3: Windows Automatic Installation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform `windows/setup.ps1` from a download-only script into a full interactive installer: interactive questions → download → extract/install → configure PATH → verify.

**Architecture:** Five PowerShell scripts under `windows/`. `setup.ps1` orchestrates the flow, sourcing specialized modules: `check.ps1` (detect existing), `download.ps1` (download + cache), `install.ps1` (extract/install each runtime), `config.ps1` (set persistent USER PATH + JAVA_HOME), `verify.ps1` (confirm all installed). Profile persistence mirrors the PopOS pattern: `$HOME\.config\envbat\profile.ps1`.

**Tech Stack:** PowerShell 5.1+, `Expand-Archive` (built-in zip extraction), `[Environment]::SetEnvironmentVariable` for persistent PATH, `Invoke-WebRequest` for downloads.

---

## File Structure

### Modified files

| File | What changes |
|---|---|
| `windows/setup.ps1` | Rewrite — interactive orchestrator: questions → download → install → PATH → verify |
| `windows/download.ps1` | Adapt — accept `$skipExisting` flag, skip already-downloaded files |

### New files

| File | Responsibility |
|---|---|
| `windows/install.ps1` | `Install-Go`, `Install-Java`, `Install-Python`, `Install-Msys2` — extract/install each runtime |
| `windows/config.ps1` | `Add-ToUserPath` — add dirs to persistent USER PATH, set `JAVA_HOME` |
| `windows/verify.ps1` | `Verify-Installations` — check each chosen tool, return status table |

---

## Tasks

### Task 1: Create `windows/install.ps1` — language runtime installers

**Files:**
- Create: `windows/install.ps1`

- [ ] **Step: Write Install-Go**

```powershell
# Install-Go: extract Go zip to $base\go\ and return version installed
function Install-Go {
    param(
        [string]$installBase,
        [string]$goZipPath
    )
    $goDir = Join-Path -Path $installBase -ChildPath "go"
    if (Test-Path (Join-Path -Path $goDir -ChildPath "bin\go.exe")) {
        $ver = & "$goDir\bin\go.exe" version 2>$null
        Write-Host "  [SKIP] Go 已安装: $ver"
        return
    }
    Write-Host "  解压 Go ..."
    Expand-Archive -Path $goZipPath -DestinationPath $installBase -Force
    if (Test-Path (Join-Path -Path $goDir -ChildPath "bin\go.exe")) {
        Write-Host "  [OK] Go 已安装到 $goDir"
    } else {
        Write-Host "  [FAIL] Go 解压失败"
    }
}
```

- [ ] **Step: Write Install-Java**

```powershell
# Install-Java: extract JDK zip to $base\java\jdk-21\
function Install-Java {
    param(
        [string]$installBase,
        [string]$javaZipPath
    )
    $javaDir = Join-Path -Path $installBase -ChildPath "java"
    $jdkDir = Join-Path -Path $javaDir -ChildPath "jdk-21"
    if (Test-Path (Join-Path -Path $jdkDir -ChildPath "bin\java.exe")) {
        $ver = & "$jdkDir\bin\java.exe" -version 2>&1 | Select-String "version" | ForEach-Object { $_.ToString().Trim() }
        Write-Host "  [SKIP] Java 已安装: $ver"
        return
    }
    Write-Host "  解压 JDK 21 ..."
    New-Item -Path $javaDir -ItemType Directory -Force | Out-Null
    Expand-Archive -Path $javaZipPath -DestinationPath $javaDir -Force
    # Rename extracted folder (jdk-21.0.x) to jdk-21
    $extracted = Get-ChildItem -Path $javaDir -Directory | Where-Object { $_.Name -like "jdk-21*" } | Select-Object -First 1
    if ($extracted -and $extracted.Name -ne "jdk-21") {
        if (Test-Path $jdkDir) { Remove-Item -Recurse -Force $jdkDir }
        Rename-Item -Path $extracted.FullName -NewName "jdk-21"
    }
    if (Test-Path (Join-Path -Path $jdkDir -ChildPath "bin\java.exe")) {
        Write-Host "  [OK] JDK 21 已安装到 $jdkDir"
    } else {
        Write-Host "  [FAIL] JDK 解压失败"
    }
}
```

- [ ] **Step: Write Install-Python**

```powershell
# Install-Python: extract embeddable zip to $base\python\ + download uv.exe
function Install-Python {
    param(
        [string]$installBase,
        [string]$pythonZipPath
    )
    $pythonDir = Join-Path -Path $installBase -ChildPath "python"
    if (Test-Path (Join-Path -Path $pythonDir -ChildPath "python.exe")) {
        Write-Host "  [SKIP] Python 已安装"
        return
    }
    Write-Host "  解压 Python (embeddable) ..."
    New-Item -Path $pythonDir -ItemType Directory -Force | Out-Null
    Expand-Archive -Path $pythonZipPath -DestinationPath $pythonDir -Force

    # Download uv.exe alongside python.exe
    $uvPath = Join-Path -Path $pythonDir -ChildPath "uv.exe"
    if (-not (Test-Path $uvPath)) {
        Write-Host "  下载 uv (Python 包管理器) ..."
        try {
            $uvUrl = "https://astral.sh/uv/install.ps1"
            # uv install script detects arch and downloads the right exe
            Invoke-WebRequest -Uri $uvUrl -OutFile "$env:TEMP\uv-install.ps1" -UseBasicParsing
            # Run install script with custom install dir
            $env:UV_INSTALL_DIR = $pythonDir
            & "$env:TEMP\uv-install.ps1" 2>$null | Out-Null
            # uv-install.ps1 puts uv.exe in $UV_INSTALL_DIR\uv.exe
            if (-not (Test-Path $uvPath)) {
                # fallback: download directly
                $uvExeUrl = "https://github.com/astral-sh/uv/releases/latest/download/uv-x86_64-pc-windows-msvc.zip"
                $uvZip = "$env:TEMP\uv.zip"
                Invoke-WebRequest -Uri $uvExeUrl -OutFile $uvZip -UseBasicParsing
                Expand-Archive -Path $uvZip -DestinationPath $pythonDir -Force
                Remove-Item $uvZip -Force
            }
        } catch {
            Write-Warning "  [WARN] uv 下载失败: $_"
        }
    } else {
        Write-Host "  [SKIP] uv 已存在"
    }

    # Check python and uv
    if (Test-Path (Join-Path -Path $pythonDir -ChildPath "python.exe")) {
        Write-Host "  [OK] Python 已安装到 $pythonDir"
    }
    if (Test-Path (Join-Path -Path $pythonDir -ChildPath "uv.exe")) {
        Write-Host "  [OK] uv 已安装到 $pythonDir"
    }
}
```

- [ ] **Step: Write Install-Msys2**

```powershell
# Install-Msys2: silent install msys2 exe to $base\msys64\
function Install-Msys2 {
    param(
        [string]$installBase,
        [string]$msys2ExePath
    )
    $msysDir = Join-Path -Path $installBase -ChildPath "msys64"
    if (Test-Path (Join-Path -Path $msysDir -ChildPath "usr\bin\gcc.exe")) {
        Write-Host "  [SKIP] MSYS2 已安装 (gcc 可用)"
        return
    }
    Write-Host "  安装 MSYS2 (静默模式) ..."
    $args = "--quiet --root", "`"$msysDir`""
    try {
        Start-Process -FilePath $msys2ExePath -ArgumentList "--quiet --root `"$msysDir`"" -Wait -NoNewWindow
        # After install, update pacman and install base-devel (gcc, g++, make)
        $pacmanPath = Join-Path -Path $msysDir -ChildPath "usr\bin\pacman.exe"
        if (Test-Path $pacmanPath) {
            Write-Host "  更新 pacman 并安装 mingw-w64 gcc ..."
            & $pacmanPath --noconfirm -Sy 2>$null | Out-Null
            & $pacmanPath --noconfirm -S mingw-w64-x86_64-gcc mingw-w64-x86_64-gdb 2>$null | Out-Null
            Write-Host "  [OK] MSYS2 + GCC 已安装"
        } else {
            Write-Host "  [WARN] MSYS2 基础安装完成，但 pacman 未找到"
        }
    } catch {
        Write-Host "  [FAIL] MSYS2 安装失败: $_"
    }
}
```

- [ ] **Step: Write dispatch function**

```powershell
# Dispatch: install all chosen languages
function Install-All {
    param(
        [string]$installBase,
        [hashtable]$choices,
        [hashtable]$packageFiles   # @{ "go" = "path\to\go.zip"; "java" = ... }
    )
    if ($choices["go"])    { Install-Go    -installBase $installBase -goZipPath $packageFiles["go"] }
    if ($choices["java"])  { Install-Java  -installBase $installBase -javaZipPath $packageFiles["java"] }
    if ($choices["python"]){ Install-Python -installBase $installBase -pythonZipPath $packageFiles["python"] }
    if ($choices["msys2"]) { Install-Msys2 -installBase $installBase -msys2ExePath $packageFiles["msys2"] }
}
```

- [ ] **Step: Verify syntax**

Run: `powershell -NoProfile -Command "Set-StrictMode -Version Latest; . .\windows\install.ps1; Write-Host 'LOAD OK'"` — expected: "LOAD OK", no errors.

---

### Task 2: Adapt `windows/download.ps1` — add cache reuse + return paths

**Files:**
- Modify: `windows/download.ps1`

- [ ] **Step: Edit download.ps1 to accept -skipExisting flag**

Replace the `Download-Packages` function to accept `-skipExisting`, and return a hashtable of downloaded file paths instead of just writing to console.

```powershell
# Download-Packages: download all chosen language packages, reuse cache
# Returns: hashtable @{ "go" = "path\to\go.zip"; "java" = ...; "python" = ...; "msys2" = ... }
function Download-Packages {
    param(
        [string]$installPath,
        [hashtable]$choices,          # @{ "go" = $true; "java" = $true; ... }
        [switch]$skipExisting
    )

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $packageDir = Join-Path -Path $installPath -ChildPath "packages"
    if (-not (Test-Path -Path $packageDir)) {
        New-Item -Path $packageDir -ItemType Directory -Force | Out-Null
    }

    # Define URLs for each chosen language
    $urls = @{}
    if ($choices["go"])     { $urls["go"]     = Get-GoLatestUrl }
    if ($choices["java"])   { $urls["java"]   = "https://download.oracle.com/java/21/latest/jdk-21_windows-x64_bin.zip" }
    if ($choices["python"]) { $urls["python"] = Get-PythonLatestUrl }
    if ($choices["msys2"])  { $urls["msys2"]  = Get-Msys2LatestUrl }

    $result = @{}
    foreach ($entry in $urls.GetEnumerator()) {
        $fileName = Split-Path -Path $entry.Value -Leaf
        $filePath = Join-Path -Path $packageDir -ChildPath $fileName

        if ($skipExisting -and (Test-Path $filePath)) {
            Write-Host "  [CACHE] $fileName (已存在，跳过下载)"
        } else {
            Write-Host "  下载 $fileName ..."
            try {
                Invoke-WebRequest -Uri $entry.Value -OutFile $filePath -UseBasicParsing
                Write-Host "  [OK] $fileName"
            } catch {
                Write-Warning "  [FAIL] 下载失败: $fileName - $_"
                continue
            }
        }
        $result[$entry.Key] = $filePath
    }
    return $result
}
```

- [ ] **Step: Verify syntax**

Run: `powershell -NoProfile -Command "Set-StrictMode -Version Latest; . .\windows\download.ps1; Write-Host 'LOAD OK'"` — expected: "LOAD OK".

---

### Task 3: Create `windows/config.ps1` — PATH + JAVA_HOME

**Files:**
- Create: `windows/config.ps1`

- [ ] **Step: Write config.ps1**

```powershell
# === Windows: PATH and Environment Variable Configuration ===
# Adds tool bin directories to persistent USER PATH.
# Sets JAVA_HOME.

function Add-ToUserPath {
    param(
        [string]$installBase,
        [hashtable]$choices
    )
    $pathsToAdd = @()
    # Build list of bin dirs for chosen tools
    if ($choices["go"]) {
        $pathsToAdd += Join-Path -Path $installBase -ChildPath "go\bin"
    }
    if ($choices["java"]) {
        $jdkDir = Join-Path -Path $installBase -ChildPath "java\jdk-21\bin"
        if (Test-Path $jdkDir) { $pathsToAdd += $jdkDir }
    }
    if ($choices["python"]) {
        $pathsToAdd += Join-Path -Path $installBase -ChildPath "python"
    }
    if ($choices["msys2"]) {
        $msysBin = Join-Path -Path $installBase -ChildPath "msys64\usr\bin"
        if (Test-Path $msysBin) { $pathsToAdd += $msysBin }
    }

    # Get current USER PATH
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $pathParts = $currentPath -split ";" | Where-Object { $_ -ne "" }

    $added = 0
    foreach ($dir in $pathsToAdd) {
        if ($pathParts -contains $dir) {
            Write-Host "  [SKIP] PATH 中已存在: $dir"
        } else {
            $newPath = $currentPath.TrimEnd(";") + ";" + $dir
            [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
            $currentPath = $newPath
            Write-Host "  [OK]  已添加 PATH: $dir"
            $added++
        }
    }
    if ($added -eq 0) { Write-Host "  [OK]  PATH 无需更改" }
}

function Set-JavaHome {
    param(
        [string]$installBase
    )
    $jdkDir = Join-Path -Path $installBase -ChildPath "java\jdk-21"
    if (Test-Path (Join-Path -Path $jdkDir -ChildPath "bin\java.exe")) {
        [Environment]::SetEnvironmentVariable("JAVA_HOME", $jdkDir, "User")
        Write-Host "  [OK]  JAVA_HOME = $jdkDir"
    } else {
        Write-Host "  [SKIP] JDK 未安装，跳过 JAVA_HOME"
    }
}
```

- [ ] **Step: Verify syntax**

Run: `powershell -NoProfile -Command "Set-StrictMode -Version Latest; . .\windows\config.ps1; Write-Host 'LOAD OK'"` — expected: "LOAD OK".

---

### Task 4: Create `windows/verify.ps1` — installation verification

**Files:**
- Create: `windows/verify.ps1`

- [ ] **Step: Write verify.ps1**

```powershell
# === Windows: Verify Installations ===
# Checks each chosen tool exists and prints version info.

function Verify-Installations {
    param(
        [string]$installBase,
        [hashtable]$choices
    )
    Write-Host "`n--- 验证安装 ---`n"

    $results = @()

    # Go
    if ($choices["go"]) {
        $goBin = Join-Path -Path $installBase -ChildPath "go\bin\go.exe"
        if (Test-Path $goBin) {
            $ver = & $goBin version 2>$null
            Write-Host "  [OK]  Go: $ver"
            $results += "Go: OK"
        } else {
            Write-Host "  [MISS] Go"
            $results += "Go: MISS"
        }
    }

    # Java
    if ($choices["java"]) {
        $javaBin = Join-Path -Path $installBase -ChildPath "java\jdk-21\bin\java.exe"
        if (Test-Path $javaBin) {
            $ver = & $javaBin -version 2>&1 | Select-String "version" | ForEach-Object { $_.ToString().Trim() }
            Write-Host "  [OK]  Java: $ver"
            $results += "Java: OK"
        } else {
            Write-Host "  [MISS] Java"
            $results += "Java: MISS"
        }
    }

    # Python
    if ($choices["python"]) {
        $pythonBin = Join-Path -Path $installBase -ChildPath "python\python.exe"
        if (Test-Path $pythonBin) {
            $ver = & $pythonBin --version 2>$null
            Write-Host "  [OK]  Python: $ver"
            $results += "Python: OK"
        } else {
            Write-Host "  [MISS] Python"
            $results += "Python: MISS"
        }
        $uvBin = Join-Path -Path $installBase -ChildPath "python\uv.exe"
        if (Test-Path $uvBin) {
            $ver = & $uvBin --version 2>$null
            Write-Host "  [OK]  uv: $ver"
        } else {
            Write-Host "  [MISS] uv (可选)"
        }
    }

    # MSYS2 (gcc)
    if ($choices["msys2"]) {
        $gccBin = Join-Path -Path $installBase -ChildPath "msys64\usr\bin\gcc.exe"
        if (Test-Path $gccBin) {
            $ver = & $gccBin --version 2>$null | Select-Object -First 1
            Write-Host "  [OK]  GCC: $ver"
            $results += "MSYS2/GCC: OK"
        } else {
            Write-Host "  [MISS] MSYS2/GCC"
            $results += "MSYS2/GCC: MISS"
        }
    }

    Write-Host "`n--- 摘要 ---"
    $results | ForEach-Object { Write-Host "  $_" }
    return $results
}
```

- [ ] **Step: Verify syntax**

Run: `powershell -NoProfile -Command "Set-StrictMode -Version Latest; . .\windows\verify.ps1; Write-Host 'LOAD OK'"` — expected: "LOAD OK".

---

### Task 5: Rewrite `windows/setup.ps1` — interactive orchestrator

**Files:**
- Modify: `windows/setup.ps1`

- [ ] **Step: Write the new setup.ps1**

```powershell
# === Windows: 开发环境交互式一键配置 ===
# 首次运行：一问一答引导式，保存配置后自动安装。
# 再次运行：检测到已有配置跳过问答。
#
# 管理员身份推荐（安装 msys2 时需要写入权限）。
# ============================================================

# Source modules
. "$PSScriptRoot\check.ps1"
. "$PSScriptRoot\download.ps1"
. "$PSScriptRoot\install.ps1"
. "$PSScriptRoot\config.ps1"
. "$PSScriptRoot\verify.ps1"

# Profile path (mirror PopOS style)
$ProfileDir = "$HOME\.config\envbat"
$ProfileFile = "$ProfileDir\profile.ps1"

# ---- Prompt helpers ----
function Ask-YesNo {
    param([string]$prompt, [string]$default = "Y")
    while ($true) {
        $hint = if ($default -eq "Y") { "Y/n" } else { "y/N" }
        $answer = Read-Host "$prompt ($hint)"
        if ($answer -eq "") { $answer = $default }
        switch -regex ($answer) {
            "^[Yy]" { return $true }
            "^[Nn]" { return $false }
            default { Write-Host "  请输入 y 或 n" }
        }
    }
}

function Ask-Input {
    param([string]$prompt, [string]$default, [string]$varName)
    $hint = if ($default) { " (默认: $default)" } else { "" }
    $input = Read-Host "$prompt$hint"
    if ($input -eq "") { $input = $default }
    Set-Variable -Name $varName -Value $input -Scope 1
}

# ---- Load / Save profile ----
function Load-Profile {
    if (Test-Path $ProfileFile) {
        . $ProfileFile
        Write-Host "  [OK] 已加载配置: $ProfileFile"
        return $true
    }
    return $false
}

function Save-Profile {
    if (-not (Test-Path $ProfileDir)) { New-Item -Path $ProfileDir -ItemType Directory -Force | Out-Null }
    @"
# === envbat Windows profile ===
# Generated by setup.ps1 $(Get-Date -Format 'yyyy-MM-dd')
# Delete this file to re-run interactive setup.

`$global:INSTALL_BASE = "$INSTALL_BASE"
`$global:INSTALL_GO = `$$INSTALL_GO
`$global:INSTALL_JAVA = `$$INSTALL_JAVA
`$global:INSTALL_PYTHON = `$$INSTALL_PYTHON
`$global:INSTALL_MSYS2 = `$$INSTALL_MSYS2
"@ | Out-File -FilePath $ProfileFile -Encoding utf8
    Write-Host "  [OK] 配置已保存: $ProfileFile"
}

# ---- Interactive questions ----
function Ask-Questions {
    Write-Host "`n== 安装基础路径 =="
    $defaultBase = "$HOME\local\envs"
    Ask-Input -prompt "请输入安装基础目录" -default $defaultBase -varName "inputBase"
    $script:INSTALL_BASE = $inputBase
    Write-Host "  安装基础: $INSTALL_BASE"

    Write-Host "`n== 开发语言 =="
    $script:INSTALL_GO     = if (Ask-YesNo -prompt "安装 Go 语言?"                 -default "Y") { $true } else { $false }
    $script:INSTALL_JAVA   = if (Ask-YesNo -prompt "安装 Java JDK 21?"              -default "Y") { $true } else { $false }
    $script:INSTALL_PYTHON = if (Ask-YesNo -prompt "安装 Python (embeddable + uv)?" -default "Y") { $true } else { $false }
    $script:INSTALL_MSYS2  = if (Ask-YesNo -prompt "安装 MSYS2 (C/C++ 编译环境)?"   -default "Y") { $true } else { $false }
}

# ============================================================
# Main
# ============================================================
Write-Host @"

################################################
#  envbat Windows — 交互式环境配置               #
################################################
"@

# Admin check
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "  未以管理员身份运行，MSYS2 安装可能需要权限"
    if (-not (Ask-YesNo -prompt "是否继续?" -default "N")) { exit }
}

# Profile
if (Load-Profile) {
    if (-not (Ask-YesNo -prompt "检测到已有配置，是否重新配置?" -default "N")) {
        Write-Host "  使用现有配置继续安装"
    } else {
        Ask-Questions
        Save-Profile
    }
} else {
    Ask-Questions
    Save-Profile
}

# Choices hashtable for passing to modules
$choices = @{
    "go"     = $INSTALL_GO
    "java"   = $INSTALL_JAVA
    "python" = $INSTALL_PYTHON
    "msys2"  = $INSTALL_MSYS2
}

# Check existing
Write-Host "`n--- 检查已有安装 ---"
$languages = @()
if ($INSTALL_GO)     { $languages += "Golang" }
if ($INSTALL_JAVA)   { $languages += "Java" }
if ($INSTALL_PYTHON) { $languages += "Python" }
if ($INSTALL_MSYS2)  { $languages += "C"; $languages += "C++" }
if ($languages.Count -gt 0) {
    $existing = Check-AllInstallations -programmingLanguages $languages
    $existing | ForEach-Object { Write-Host "  $_" }
}

# Download (skip existing cached files)
Write-Host "`n--- 下载安装包 ---"
$packageFiles = Download-Packages -installPath $INSTALL_BASE -choices $choices -skipExisting

# Install
Write-Host "`n--- 安装 ---"
Install-All -installBase $INSTALL_BASE -choices $choices -packageFiles $packageFiles

# PATH configuration
Write-Host "`n--- 配置环境变量 ---"
Add-ToUserPath -installBase $INSTALL_BASE -choices $choices
Set-JavaHome -installBase $INSTALL_BASE
Write-Host "  [HINT] 需要重新打开终端或重启后 PATH 才会完全生效"

# Verify
Verify-Installations -installBase $INSTALL_BASE -choices $choices

# Done
Write-Host @"

========================================
 ✅ Windows 环境配置完成！

  重新打开终端后，工具将可用。
  使用 'uv venv' 创建 Python 虚拟环境。
========================================
"@
```

- [ ] **Step: Verify syntax**

Run: `powershell -NoProfile -Command "Set-StrictMode -Version Latest; . .\windows\setup.ps1; Write-Host 'LOAD OK'"` — expected: "LOAD OK".

---

### Task 6: Add Windows backup/restore section to README.md

**Files:**
- Modify: `README.md`

- [ ] **Step: Update README.md with new Windows flow**

Edit the README to update the Windows directory description and add the new install flow:

```markdown
├── windows/              # Windows 环境配置
│   ├── setup.ps1         # ── 入口：交互式安装编排器
│   ├── check.ps1         # 检测已安装的编程语言环境
│   ├── download.ps1      # 下载选取的编程语言安装包
│   ├── install.ps1       # 自动安装/解压各语言运行时
│   ├── config.ps1        # 配置 PATH / JAVA_HOME
│   └── verify.ps1        # 验证安装结果
```

- [ ] **Step: Commit all changes**

```powershell
git add windows/setup.ps1 windows/download.ps1 windows/install.ps1 windows/config.ps1 windows/verify.ps1 README.md
git commit -m "feat: Phase 3 - Windows automatic installation

- Interactive guided installer with profile persistence
- Go: zip from go.dev with dynamic version detection
- Java: Oracle JDK 21 zip extraction
- Python: embeddable zip + uv package manager
- MSYS2: silent exe install + pacman gcc setup
- Persistent USER PATH configuration
- JAVA_HOME environment variable
- Download cache reuse (packages/ directory)
- Installation verification per tool
- Module separation: setup/install/config/verify"
```

---

## Self-Review

**Spec coverage:**
- Interactive questions — Task 5 (setup.ps1) Ask-Questions + Load-Profile
- Profile persistence — Task 5 (setup.ps1) Load-Profile / Save-Profile
- Go installer — Task 1 (install.ps1) Install-Go
- Java installer — Task 1 (install.ps1) Install-Java
- Python + uv installer — Task 1 (install.ps1) Install-Python
- MSYS2 silent installer — Task 1 (install.ps1) Install-Msys2
- Download cache reuse — Task 2 (download.ps1) -skipExisting flag
- PATH config — Task 3 (config.ps1) Add-ToUserPath
- JAVA_HOME — Task 3 (config.ps1) Set-JavaHome
- Verification — Task 4 (verify.ps1) Verify-Installations
- README update — Task 6

**Placeholder scan:** All code blocks contain complete, runnable implementations. No TBD/TODO.

**Type consistency:** `$choices` hashtable uses consistent keys `"go"`, `"java"`, `"python"`, `"msys2"` across all modules. `$installBase` parameter name consistent. Profile variable naming matches between Ask-Questions, Save-Profile, and Load-Profile.
