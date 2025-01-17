# Import the required scripts
. "$PSScriptRoot\scipts\check.ps1"
. "$PSScriptRoot\scipts\create-download.ps1"

# Main function to coordinate the process
function Main {
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
