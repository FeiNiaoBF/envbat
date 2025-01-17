# Only for Windows
# Check if the required software is installed on the system
# Only five programming languages are checked
# But you can add more programming languages to the list

# Define the function to check if a command (programming language) is installed
function Check-Installation {
    param (
        [string]$language,
        [string]$command
    )

    # 尝试获取命令的路径，如果命令存在则返回 "Installed"
    $status = Get-Command $command -ErrorAction SilentlyContinue
    if ($status) {
        return "${language}: Installed"
    }
    else {
        return "${language}: Not Installed"
    }
}

# Define the function to check installations for multiple programming languages
function Check-AllInstallations {
    param (
        [array]$programmingLanguages
    )

    $installationStatus = @()

    foreach ($language in $programmingLanguages) {
        switch ($language) {
            "C" { $installationStatus += Check-Installation -language "C" -command "gcc" }
            "C++" { $installationStatus += Check-Installation -language "C++" -command "g++" }
            "Java" { $installationStatus += Check-Installation -language "Java" -command "java" }
            "Golang" { $installationStatus += Check-Installation -language "Golang" -command "go" }
            "Python" { $installationStatus += Check-Installation -language "Python" -command "python" }
            Default { $installationStatus += "No match found for $language" }
        }
    }

    # 返回安装状态的结果
    return $installationStatus
}
