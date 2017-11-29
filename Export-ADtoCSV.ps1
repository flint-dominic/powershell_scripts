<#
.SYNOPSIS
Export AD properties to CSV.

.DESCRIPTION
This script will export selected AD properties from given company to a CSV file

.PARAMETER MyCompany
filter for the specific company being exported

.PARAMETER Path
location to put output files

.PARAMETER Path2
location to put output files for a second directory if  needed

.PARAMETER OutCSV
named of csv to use

.EXAMPLE
.\Export-ADtoCSV.ps1 -OutputDirectory 'C:\tmp\'
This would change the default output directory location from the default of home directory

#>

Param
(
   	[string]$MyCompany='CompanyName',
   	[string]$Path='\\server\directory\Records\forms\dir1',
	[string]$Path2='\\server\directory\Records\forms\dir2',
    	[string]$OutCSV='.\example.csv'
)

$users = Get-ADUser -Filter {Company -eq "$MyCompany"} -Properties sn, givenName, displayName, description, Title | where {$_.Enabled -eq $true } | select Name, sn, givenName, displayName, description, Title
$dir1 = Get-ChildItem -Path "$Path" | Select-Object name
# $dir2 = Get-ChildItem -Path "$Path2" | select-object name
$outFile = @($users,$dir1)

foreach($file in $dir1)
    {
#    $noExt = $file.substring(0,$file.length-3)
    $noExt = $file.Basename
#    if(($users.Name) -match $_.file)
    if(($users.Name) -match $noExt)
        {
        $output += ($users,$file)
        }
    }
$outFile | ConvertTo-CSV | Out-File $OutCSV
