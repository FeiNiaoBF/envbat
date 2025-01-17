# 提示用户输入安装路径
$installPath = Read-Host "Enter the installation path (default: $HOME\local\envs)"
if ($installPath -eq "") {
    $installPath = "$HOME\local\envs"
}

# 检查是否存在自定义环境目录
if (Test-Path -Path $installPath) {
    Write-Host "The path $installPath already exists."
}
else {
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
    }
    else {
        Write-Host "The path $languagePath does not exist, creating the path..."
        New-Item -Path $languagePath -ItemType Directory -Force
        Write-Host "Successfully created."
    }

    Write-Host "Language: $languageName"
    Write-Host "Path: $languagePath"
}

Write-Host "Custom environment directories created successfully."

# 包存放路径
$packageDir = Join-Path -Path $installPath -ChildPath "packages"

# 检查并创建包存储目录
if (-not (Test-Path -Path $packageDir)) {
    Write-Host "The path $packageDir does not exist, creating the path..."
    New-Item -Path $packageDir -ItemType Directory -Force
    Write-Host "Successfully created."
}

# 下载地址
$downloadUrls = @{
    # 下载msys2二进制文件
    "msys2"  = "https://github.com/msys2/msys2-installer/releases/download/2024-12-08/msys2-x86_64-20241208.exe"
    # java 21
    "java"   = "https://download.oracle.com/java/21/latest/jdk-21_windows-x64_bin.zip"
    # go 1.23.5
    "go"     = "https://go.dev/dl/go1.23.5.windows-amd64.zip"
    # python 3.13.*
    "python" = "https://www.python.org/ftp/python/3.13.1/python-3.13.1-embed-amd64.zip"
}

# 遍历哈希表，下载安装包
foreach ($language in $programmingLanguages.GetEnumerator()) {
    $languageName = $language.Key
    $languageDir = $language.Value
    $downloadUrl = $downloadUrls[$languageDir]
    # 从URL中提取文件名
    $fileName = Split-Path -Path $downloadUrl -Leaf
    $downloadFilePath = Join-Path -Path $packageDir -ChildPath $fileName

    Write-Host "Downloading $languageName..."

    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadFilePath
        Write-Host "Downloaded successfully."
        Write-Host "Download file name: $fileName"
        Write-Host "Download file path: $downloadFilePath"
    }
    catch {
        Write-Host "Failed to download $languageName. Error: $_"
    }
}

Write-Host "All downloads completed."
