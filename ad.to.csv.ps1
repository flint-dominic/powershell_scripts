$users = Get-ADUser -Filter {Company -eq "MyCompany"} -Properties sn, givenName, displayName, description, Title | where {$_.Enabled -eq $true } | select Name, sn, givenName, displayName, description, Title
$dir1 = get-childitem -Path "\\server\directory\Records\forms\dir1" | select-object name
$dir2 = get-childitem -Path "\\server\directory\Records\ticket\dir2" | select-object name
$dir3 = get-childitem -Path "\\server\directory\Records\titles\dir3" | select-object name

$output = @($users,$dir1)
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
$output | convertto-csv | out-file .\example.csv