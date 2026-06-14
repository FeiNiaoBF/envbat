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
