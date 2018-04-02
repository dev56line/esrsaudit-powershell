# Initial Scripted by H.Wakabayashi
# Description :
#   - This file would be executed by Windows Startup-Script

# Set flagfile name
$FLAG1 = ".\Flagfile_Gateway1.flg"
$FLAG2 = ".\Flagfile_Gateway2.flg"

# Set execution directory
cd C:\<path_to_workingdir>

# Remove flagfile for ESRS#1 if exist
if ((Test-Path -Path $FLAG1) -eq $true) {
        Remove-Item $FLAG1
    }else{
        echo "No flags"
    }

# Remove flagfile for ESRS#2 if exist
if ((Test-Path -Path $FLAG2) -eq $true) {
        Remove-Item $FLAG2
    }else{
        echo "No flags"
    }

# kick the main script as background process
Start-Process -FilePath "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" `
    -ArgumentList "C:\<path_to_workingdir>\MainScript.ps1" `
    -WindowStyle Hidden
