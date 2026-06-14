# Import the required scripts
. "$PSScriptRoot\check.ps1"
. "$PSScriptRoot\download.ps1"

# Main function to coordinate the process
function Main {
    # Step 0: Check for Administrator privileges
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Warning "当前未以管理员身份运行，部分安装可能失败！"
        $choice = Read-Host "是否继续？(y/N)"
        if ($choice -ne "y") {
            Write-Host "已取消。请以管理员身份重新运行。"
            exit
        }
    }

    # Step 1: Check existing installations
    $programmingLanguages = @("C", "C++", "Java", "Golang", "Python")
    $installationStatus = Check-AllInstallations -programmingLanguages $programmingLanguages

    # 输出检查结果
    $installationStatus | ForEach-Object {
        Write-Host $_
    }

    # Step 2: Ask user for installation path
    $installPath = Read-Host "Enter the installation path (default: $HOME\local\envs)"
    if ($installPath -eq "") {
        $installPath = "$HOME\local\envs"
    }

    # Step 3: Create directories for the environment and packages
    $installPath = Create-Install-Directories -installPath $installPath

    # Step 4: Download the necessary installation packages
    Download-Packages -installPath $installPath
}

# Execute the main function
Main
