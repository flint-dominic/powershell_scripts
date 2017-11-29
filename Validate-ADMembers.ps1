<#
.SYNOPSIS
Validate AD accounts.

.DESCRIPTION
This script will output files of list of users in CSV format for auditing from a list of AD groups.

.PARAMETER GroupList
location of list of AD groups

.PARAMETER OutputDirectory
location to put output files, home directory by default

.EXAMPLE
.\Validate-ADMembers.ps1 -OutputDirectory 'C:\tmp\'
This would change the default output directory location from the default of home directory

#>

Param
(
    	[string]$GroupList='C:\tmp\ADgroups.txt',
    	[string]$OutputDirectory=$HOME,
    	[string]$LocDomain=$env:userdomain
)

Import-Module ActiveDirectory -ea SilentlyContinue
If (-not(Get-Command Get-ADUser -ea SilentlyContinue))
    	{
    	Throw "Unable to import ActiveDirectory Powershell module"
    	}
If (-not (Test-Path $GroupList))
	{
    	Throw $GroupList + " could not be found, provide a path to valid group list"
	}
    	Else
    	{
    	Write-Host "Processing file $GroupList" -ForegroundColor Cyan
    	}
If (-not (Test-Path $OutputDirectory))
    	{
        Throw $OutputDirectory + " does not exist, provide a valid output directory"
    	}
$GL = Get-Content $GroupList
If ($GL.Count -gt 100 -or $GL.Count -lt 1)
    	{
    	Throw "Please provide a list of groups between 1 and 100"
    	}
    	Else
    	{
    	Write-Host "Processing "$GL.Count" groups" -ForegroundColor Cyan
    	}
ForEach ($ADGroup In $GL)
    	{
    	Write-Host "Processing "$ADGroup -ForegroundColor Cyan
    	Try 
        	{
        	Get-ADGroupMember -Identity $ADGroup | Get-ADUser -Properties SamAccountName, SurName, GivenName, Manager, Description | Select-Object SamAccountName, SurName, GivenName, Manager, Description | Export-CSV $OutputDirectory'\'$ADGroup'.csv' -NoTypeInformation
        	}
        	Catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
        	{
        	Write-Host "AD Group $ADGroup not found" -ForegroundColor Red
        	}
    	}
Write-Host "Output files in directory $OutputDirectory" -ForegroundColor Cyan
