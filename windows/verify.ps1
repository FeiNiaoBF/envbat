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
