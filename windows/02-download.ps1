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

# Download the necessary installation packages
function Download-Packages {
    param (
        [string]$installPath
    )

    $packageDir = Join-Path -Path $installPath -ChildPath "packages"

    # 检查并创建包存储目录
    if (-not (Test-Path -Path $packageDir)) {
        Write-Host "The path $packageDir does not exist, creating the path..."
        New-Item -Path $packageDir -ItemType Directory -Force
        Write-Host "Successfully created."
    }

    # 下载地址
    $downloadUrls = @{
        "msys2"  = "https://github.com/msys2/msys2-installer/releases/download/2024-12-08/msys2-x86_64-20241208.exe"
        "java"   = "https://download.oracle.com/java/21/latest/jdk-21_windows-x64_bin.zip"
        "go"     = "https://go.dev/dl/go1.23.5.windows-amd64.zip"
        "python" = "https://www.python.org/ftp/python/3.13.1/python-3.13.1-embed-amd64.zip"
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
