# Only for Windows
# Check if the required software is installed on the system
# Only five programming languages are checked
# But you can add more programming languages to the list
$programmingLanguages = @("C", "C++", "Java", "Golang", "Python")
# Hash table to store the installation status of the programming languages
$installationStatus = @{}

foreach ($language in $programmingLanguages) {
    switch ($language) {
        "C" {
            # 尝试找到命令的路径。如果找不到命令，则会返回 null
            $status = Get-Command gcc -ErrorAction SilentlyContinue
            $installationStatus["C"] = if ($status) { "Installed" } else { "Not Installed" }
        }
        "C++" {
            $status = Get-Command g++ -ErrorAction SilentlyContinue
            $installationStatus["C++"] = if ($status) { "Installed" } else { "Not Installed" }
        }
        "Java" {
            $status = Get-Command java -ErrorAction SilentlyContinue
            $installationStatus["Java"] = if ($status) { "Installed" } else { "Not Installed" }
        }
        "Golang" {
            $status = Get-Command go -ErrorAction SilentlyContinue
            $installationStatus["Golang"] = if ($status) { "Installed" } else { "Not Installed" }
        }
        "Python" {
            $status = Get-Command python -ErrorAction SilentlyContinue
            $installationStatus["Python"] = if ($status) { "Installed" } else { "Not Installed" }
        }
        Default {
            # 如果没有找到任何匹配项，则执行此代码块
            Write-Output "No match found for $language"
        }
    }
}

$installationStatus.GetEnumerator() | ForEach-Object {
    Write-Output "$($_.Key): $($_.Value)"
}
