#Point Console and ISE to the main profile.ps1
$content = '$profile="$home\Documents\WindowsPowerShell\profile.ps1"'

$pwshConsole = "$home\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
$pwshISE = "$home\Documents\WindowsPowerShell\Microsoft.PowerShellISE_profile.ps1"

New-Item -ItemType Directory -Path "$home\Documents\WindowsPowerShell\log"

Remove-Item -Path $pwshConsole
Remove-Item -Path $pwshISE
Write-Verbose "Updating Console and ISE profiles..."
Add-Content -Value $content -Path $pwshConsole
Add-Content -Value $content -Path $pwshISE

Copy-Item -Path ./profile.ps1 -Destination "$home\Documents\WindowsPowerShell\"