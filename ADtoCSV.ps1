Param
(
    [string]$MyCompany='CompanyName',
    [string]$path='\\server\directory\Records\forms\dir1',
	[string]$path2='\\server\directory\Records\forms\dir2',
    [string]$outcsv='.\example.csv'
)

$users = Get-ADUser -Filter {Company -eq "$MyCompany"} -Properties sn, givenName, displayName, description, Title | where {$_.Enabled -eq $true } | select Name, sn, givenName, displayName, description, Title
$dir1 = Get-ChildItem -Path "$path" | Select-Object name
# $dir2 = Get-ChildItem -Path "$path2" | select-object name
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
$outFile | ConvertTo-CSV | Out-File $outcsv
