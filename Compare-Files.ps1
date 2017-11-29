<#
.SYNOPSIS
Compares 2 lists of computers and outputs differences to text file.

.DESCRIPTION
This script will save a XML file containing installed patches/updates, firmware/driver versions, and various software versions.
It is intended to be used for validation of a small set of values and not a global inventory report.
The P&U tool creates inventory reports that can be used for broader coverage.

.PARAMETER SCCMFile
location of SCCM computer list

.PARAMETER SnagItFile
location of SnagIt computer list

.PARAMETER CompWOSCCM
location of output file

.EXAMPLE
.\Compare-Files.ps1 -SCCMFile 'C:\Temp\other.sccm.file.txt'
This would change the default SCCM file location

#>

Param
(
    	[string]$SCCMFile='C:\Temp\SCCMComputers.txt',
    	[string]$SnagItFile='C:\Temp\ComputersWithSnagIt.txt',
	[string]$CompWOSCCM='C:\Temp\CompWOSCCM.txt'
)

If (-not (Test-Path $SCCMFile))
	{
    	Throw $SCCMFile + " could not be found"
	}
$SC = Get-Content $SCCMFile
Write-Host ("SCCM computers from: " + $SCCMFile) -ForegroundColor Cyan
$SF = Get-Content 'C:\tmp\ComputersWithSnagIt.txt'
Write-Host ("SnagIt computers from: " + $SnagItFile) -ForegroundColor Cyan
# Compare-Object $SC $SF | Out-File $CompWOSCCM
$SCCMFile | Where{$SnagItFile -notcontains $_}
Write-Host ("Files output at: " + $CompWOSCCM) -ForegroundColor Green
