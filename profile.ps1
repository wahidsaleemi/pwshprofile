#region Logging
$PSLogPath = ("{0}{1}\Documents\WindowsPowerShell\log\{2:yyyyMMdd}-{3}.log" -f $env:HOMEDRIVE, $env:HOMEPATH,  (Get-Date), $PID)
Add-Content -Value "# $(Get-Date) $env:username $env:computername" -Path $PSLogPath -erroraction SilentlyContinue
Add-Content -Value "# $(Get-Location)" -Path $PSLogPath -erroraction SilentlyContinue
#endregion

#Optimize profile load
$MyScript = [powershell]::Create()


#region Modules
## Modules needed for Powerline (Git info): https://docs.microsoft.com/en-us/windows/terminal/tutorials/powerline-setup
Import-Module -Name Posh-Git -SkipEditionCheck -DisableNameChecking
Import-Module -Name  Oh-My-Posh -MinimumVersion 3.0.0 -SkipEditionCheck -DisableNameChecking

## Autocomplete
Import-Module -Name PSReadLine -SkipEditionCheck -DisableNameChecking
#endregion

#region PSReadLine Settings
## Set text prediction https://devblogs.microsoft.com/powershell/announcing-psreadline-2-1-with-predictive-intellisense/
Set-PSReadLineOption -PredictionSource History

## Other options
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadlineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadlineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadlineOption -BellStyle None #Disable ding on typing error
Set-PSReadlineOption -EditMode Emacs #Make TAB key show parameter options
Set-PSReadlineKeyHandler -Key Ctrl+i -ScriptBlock { Start-Process "${env:ProgramFiles}\vivaldi\Application\vivaldi.exe" -ArgumentList "https://www.bing.com" } #KEY: Load Browsers using key "C:\Program Files\Vivaldi\Application\vivaldi.exe"
 
#KEY: Git, press Ctrl+Shift+G (case sensitive)
Set-PSReadlineKeyHandler -Chord Ctrl+G -ScriptBlock {
		$message = Read-Host "Please enter a commit message"
		/usr/bin/git commit -m "$message" | Write-Host
		$branch = (/usr/bin/git rev-parse --abbrev-ref HEAD)
		Write-Host "Pushing ${branch} to remote"
		/usr/bin/git push origin $branch | Write-Host
}
#endregion

#region Functions
function Get-DirectorySize($Path='.',$InType="MB")
{
	$colItems = (Get-ChildItem $Path -recurse | Measure-Object -property length -sum)
	switch ($InType) {
		"GB" { $ret = "{0:N2}" -f ($colItems.sum / 1GB) + " GB" }
		"MB" { $ret = "{0:N2}" -f ($colItems.sum / 1MB) + " MB" }
		"KB" { $ret = "{0:N2}" -f ($colItems.sum / 1KB) + " KB"}
		"B" { $ret = "{0:N2}" -f ($colItems.sum) + " B"}
		Default { $ret = "{0:N2}" -f ($colItems.sum) + " B" }
	}
	Return $ret
}
function Test-IsAdmin {
([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
}
#endregion

#region Az Subscription Helper
## Source: https://millerb.co.uk/2019/09/11/Tab-Completion-Azure-Subscriptions.html
# Get all azure subscriptions as a background job
Get-AzSubscription -AsJob -WarningAction SilentlyContinue -ErrorAction SilentlyContinue | Out-Null

Register-ArgumentCompleter -CommandName Set-AzContext -ParameterName Subscription -ScriptBlock {
    # If the job exists from the command Get-AzSubscription, receive the results & remove the job
    if ($job = Get-job -Command Get-AzSubscription | Wait-Job) {
        $global:azSubscriptions = Receive-Job -Id $job.Id | Select-Object -ExpandProperty name
        Remove-Job -Id $job.Id
    }
    # Add the completion results for the parameter
    $global:azSubscriptions | foreach-object {
        [System.Management.Automation.CompletionResult]::new(
            $_
        )
    }
}
#endregion

#region Prompt
function global:prompt {
	#Put the full path in the title bar
 
	$console = $host.ui.RawUI
	$console.ForegroundColor = "gray"
	$host.UI.RawUI.WindowTitle = Get-Location
 
	#Set text color based on admin
	if (Test-IsAdmin) {
		$userColor = 'Red'
	}
	else {
		$userColor = 'White'
	}
 
	#Setup command line numbers
	$LastCmd = Get-History -Count 1
	if($LastCmd)
	{
		$lastId = $LastCmd.Id
 
		Add-Content -Value "# $($LastCmd.StartExecutionTime)" -Path $PSLogPath
		Add-Content -Value "$($LastCmd.CommandLine)" -Path $PSLogPath
		Add-Content -Value "" -Path $PSLogPath
	}
 
	$nextCommand = $lastId + 1
 
	Write-Host "[$($pwd)]" -ForegroundColor "Cyan"
	Write-Host -NoNewline '[' -ForegroundColor "Gray"
	Write-Host -NoNewline "$([System.Environment]::UserName)" -ForegroundColor $userColor
	Write-Host -NoNewline '@'
	Write-Host -NoNewline "$([System.Environment]::MachineName)  $nextCommand" -ForegroundColor $userColor
	Write-Host -NoNewline ']' -ForegroundColor "Gray"
	#Use $host.EnterNestedPrompt() to test a nested prompt.
	Write-Host -NoNewline " PS$('>' * ($nestedPromptLevel + 1)) " -ForegroundColor $userColor
	Return " "
}

#Oh-my-posh settings
if ((get-module -Name Oh-my-posh).Version.Major -lt 3)
	{
		Set-Theme Paradox
	}
else {
	Set-PoshPrompt -Theme agnosterplus
}
Set-Location $env:userprofile\Code
#endregion