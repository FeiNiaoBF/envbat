# Create directories for languages and package storage
function Create-Install-Directories {
    param (
        [string]$installPath
    )

    # 检查并创建安装路径
    if (Test-Path -Path $installPath) {
        Write-Host "The path $installPath already exists."
    } else {
        Write-Host "The path $installPath does not exist, creating the path..."
        New-Item -Path $installPath -ItemType Directory -Force
        Write-Host "Successfully created."
    }

    Write-Host "Installation path: $installPath"

    # 创建语言环境目录哈希表
    $programmingLanguages = @{
        "C/C++"  = "msys2" # MSYS2 包含 GCC 和 G++ 在 Windows 中
        "Java"   = "java"
        "Golang" = "go"
        "Python" = "python"
    }

    # 遍历哈希表，创建语言环境子目录
    foreach ($language in $programmingLanguages.GetEnumerator()) {
        $languageName = $language.Key
        $languageDir = $language.Value
        $languagePath = Join-Path -Path $installPath -ChildPath $languageDir

        if (Test-Path -Path $languagePath) {
            Write-Host "The path $languagePath already exists."
        } else {
            Write-Host "The path $languagePath does not exist, creating the path..."
            New-Item -Path $languagePath -ItemType Directory -Force
            Write-Host "Successfully created."
        }

        Write-Host "Language: $languageName"
        Write-Host "Path: $languagePath"
    }

    Write-Host "Custom environment directories created successfully."

    return $installPath
}

# Dynamic version helpers

function Get-Msys2LatestUrl {
    try {
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/msys2/msys2-installer/releases/latest"
        $tag = $release.tag_name
        $url = "https://github.com/msys2/msys2-installer/releases/download/$tag/msys2-x86_64-$tag.exe"
        Write-Host "  [INFO] msys2 latest: $tag"
        return $url
    }
    catch {
        Write-Warning "  [WARN] 获取 msys2 最新版本失败，使用备用版本"
        return "https://github.com/msys2/msys2-installer/releases/download/2024-12-08/msys2-x86_64-20241208.exe"
    }
}

function Get-GoLatestUrl {
    try {
        $resp = Invoke-RestMethod -Uri "https://go.dev/dl/?mode=json"
        $latest = $resp[0].version  # e.g. "go1.23.5"
        $url = "https://go.dev/dl/${latest}.windows-amd64.zip"
        Write-Host "  [INFO] Go latest: $latest"
        return $url
    }
    catch {
        Write-Warning "  [WARN] 获取 Go 最新版本失败，使用备用版本"
        return "https://go.dev/dl/go1.23.5.windows-amd64.zip"
    }
}

function Get-PythonLatestUrl {
    try {
        $resp = Invoke-RestMethod -Uri "https://www.python.org/api/v2/downloads/release/?subdir=embed"
        $latestRelease = $resp | Sort-Object -Property name -Descending | Select-Object -First 1
        $ver = $latestRelease.name  # e.g. "3.13.1"
        $url = "https://www.python.org/ftp/python/$ver/python-${ver}-embed-amd64.zip"
        Write-Host "  [INFO] Python latest: $ver"
        return $url
    }
    catch {
        Write-Warning "  [WARN] 获取 Python 最新版本失败，使用备用版本"
        return "https://www.python.org/ftp/python/3.13.1/python-3.13.1-embed-amd64.zip"
    }
}

# Download the necessary installation packages
function Download-Packages {
    param (
        [string]$installPath
    )

    # 设置 TLS 1.2 (部分下载源需要)
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $packageDir = Join-Path -Path $installPath -ChildPath "packages"

    # 检查并创建包存储目录
    if (-not (Test-Path -Path $packageDir)) {
        Write-Host "The path $packageDir does not exist, creating the path..."
        New-Item -Path $packageDir -ItemType Directory -Force
        Write-Host "Successfully created."
    }

    # 下载地址（含动态版本获取）
    $downloadUrls = @{
        "msys2"  = Get-Msys2LatestUrl
        "java"   = "https://download.oracle.com/java/21/latest/jdk-21_windows-x64_bin.zip"
        "go"     = Get-GoLatestUrl
        "python" = Get-PythonLatestUrl
    }

    # 遍历哈希表，下载安装包
    foreach ($language in $downloadUrls.GetEnumerator()) {
        $fileName = Split-Path -Path $language.Value -Leaf
        $downloadFilePath = Join-Path -Path $packageDir -ChildPath $fileName

        Write-Host "Downloading $fileName..."

        try {
            Invoke-WebRequest -Uri $language.Value -OutFile $downloadFilePath
            Write-Host "Downloaded successfully."
            Write-Host "Download file name: $fileName"
            Write-Host "Download file path: $downloadFilePath"
        }
        catch {
            Write-Host "Failed to download $fileName. Error: $_"
        }
    }

    Write-Host "All downloads completed."
}
