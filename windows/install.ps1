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
