Write-Host "$(Get-Date -Format "HH:mm:ss"): Loading profile..." -ForegroundColor Cyan

#region Start AzSubscription Helper
$PowerShell = [powershell]::Create()
$Runspace = [runspacefactory]::CreateRunspace() # Create the runspace
$Runspace.Open()
$PowerShell.Runspace = $Runspace #Associate Runspace with PowerShell script manager
[void]$PowerShell.AddScript({
    Get-AzSubscription -TenantId microsoft.onmicrosoft.com -WarningAction SilentlyContinue -ErrorAction SilentlyContinue | Select-Object -ExpandProperty name
})
# It is very important to save the output of this to a variable so you have a way to end the runspace when it has completed
$asyncResult = $PowerShell.BeginInvoke()
#endregion

#region Logging
$PSLogPath = ("{0}{1}\Documents\WindowsPowerShell\log\{2:yyyyMMdd}-{3}.log" -f $env:HOMEDRIVE, $env:HOMEPATH,  (Get-Date), $PID)
Add-Content -Value "# $(Get-Date) $env:username $env:computername" -Path $PSLogPath -erroraction SilentlyContinue
Add-Content -Value "# $(Get-Location)" -Path $PSLogPath -erroraction SilentlyContinue
#endregion

#region Modules
Import-Module Posh-Git -SkipEditionCheck -DisableNameChecking
Import-Module -Name oh-my-posh -MinimumVersion 3.0.0 -DisableNameChecking
Import-Module PSReadLine -SkipEditionCheck -DisableNameChecking
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
Set-PSReadlineKeyHandler -Chord Ctrl+g -ScriptBlock {
		$message = Read-Host "Please enter a commit message"
		/usr/bin/git commit -m "$message" | Write-Host
		$branch = (/usr/bin/git rev-parse --abbrev-ref HEAD)
		Write-Host "Pushing ${branch} to remote"
		/usr/bin/git push origin $branch | Write-Host
}
#endregion

#region Functions
function Update-AzCompletion {
	## Source: https://millerb.co.uk/2019/09/11/Tab-Completion-Azure-Subscriptions.html
## Source for runspace: https://trevorsullivan.net/2020/10/02/optimize-powershell-startup-profile-script/
	#Get-AzSubscription -AsJob -WarningAction SilentlyContinue -ErrorAction SilentlyContinue | Out-Null
	Register-ArgumentCompleter -CommandName Set-AzContext -ParameterName Subscription -ScriptBlock {
		  # If the job exists from the command Get-AzSubscription, receive the results & remove the job
		  if ($job = Get-job -Command Get-AzSubscription | Wait-Job) 
			  {
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
  }
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
if ((Get-module -Name Oh-my-posh).Version.Major -lt 3)
	{
		Set-Theme Paradox
	}
else {
	Set-PoshPrompt -Theme agnosterplus
}

Set-Location $env:userprofile\Code
#endregion


#region Az Subscription Helper Finish
$null = Register-ObjectEvent -InputObject $PowerShell -EventName "InvocationStateChanged" -Action {
	param([System.Management.Automation.PowerShell] $ps)
	$state = $EventArgs.InvocationStateInfo.State

	Write-Host "Invocation state: $state"
	if ($state -in 'Completed', 'Failed') {
		# Dispose of the runspace.
		Write-Host "$(Get-Date -Format "HH:mm:ss"): Disposing of runspace." -ForegroundColor Cyan
		$ps.Runspace.Dispose()
		# Speed up resource release by calling the garbage collector explicitly.
		# Note that this will pause *all* threads briefly.
		[GC]::Collect()
	}
	$Global:azsubs = $PowerShell.EndInvoke($asyncResult)
	Register-ArgumentCompleter -CommandName Set-AzContext -ParameterName Subscription -ScriptBlock {
		# Add the completion results for the parameter 
		$global:azSubs | Foreach-Object {
			[System.Management.Automation.CompletionResult]::new($_)
		}
	}
}
#endregion
Write-Host "$(Get-Date -Format "HH:mm:ss"): Profile loaded." -ForegroundColor Cyan