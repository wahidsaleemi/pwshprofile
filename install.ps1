

# The profile will log here
New-Item -ItemType Directory -Path "$home\Documents\PowerShell\log" -ErrorAction SilentlyContinue | Out-Null

   # Point Console and ISE to the main profile.ps1 for pwsh7
$content = Get-Content -Path .\Microsoft.PowerShell_profile.ps1

# Find the path where profiles are stored
$profilePaths = @(
    "$home\Documents\WindowsPowerShell\profile.ps1",
    "$home\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1",
    "$home\Documents\WindowsPowerShell\Microsoft.PowerShellISE_profile.ps1"
)
# In many cases the profiles are offloaded to OneDrive
if ($env:OneDrive) {
    $defaultPaths = @(
        "$env:OneDrive\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1",
        "$env:OneDrive\Documents\WindowsPowerShell\Microsoft.PowerShellISE_profile.ps1"
    )
    Write-Host "Found profile in OneDrive paths."
}
else {
    $defaultPaths = $profilePaths
    Write-Host "Found profile in default paths. Updating..." 
}

foreach ($path in $defaultPaths) {
        Write-Host "Removing old profile in $path"
        Remove-Item -Path $path -ErrorAction SilentlyContinue

       Write-Host "Updating default profile in $path"
        New-Item -ItemType File -Path $path -Force | Out-Null
        Add-Content -Value $content -Path $path
}

<#
foreach ($profilepath in $profilePaths) {
    Write-Host "Updating profile in $profilepath"
    New-Item -ItemType File -Path $profilepath -Force | Out-Null
    Add-Content -Value $content -Path $profilepath
}
#>
Copy-Item -Path ./Microsoft.PowerShell_profile.ps1 -Destination "$home\Documents\PowerShell\"