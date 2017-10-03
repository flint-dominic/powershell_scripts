[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.TeamFoundation.Client")
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.TeamFoundation.WorkItemTracking.Client")
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.TeamFoundation.Build.Client")
Add-PSSnapin Microsoft.TeamFoundation.PowerShell

Function Get-WorkitemFieldValue([string]$TFSURL, [string]$WorkitemId, [string]$FieldName)
{
    $teamProjectCollection = [Microsoft.TeamFoundation.Client.TfsTeamProjectCollectionFactory]::GetTeamProjectCollection($TFSURL)
    $wit = $teamProjectCollection.GetService([Type]"Microsoft.TeamFoundation.WorkItemTracking.Client.WorkItemStore")
    $items = $wit.GetWorkItem($WorkitemId)
    $value = $items.Fields[$FieldName].Value
    return $value
}

Function Update-WorkitemField([string]$TFSURL, [string]$WorkitemId, [string]$FieldName, $FieldValue)
{
    $teamProjectCollection = [Microsoft.TeamFoundation.Client.TfsTeamProjectCollectionFactory]::GetTeamProjectCollection($TFSURL)
    $wit = $teamProjectCollection.GetService([Type]"Microsoft.TeamFoundation.WorkItemTracking.Client.WorkItemStore")
    $items = $wit.GetWorkItem($WorkitemId)
    Write-Host "Before change, $FieldName is $($items.Fields[$FieldName].Value)"
    $items.Fields[$FieldName].Value = $FieldValue
    $wit.BatchSave($items)
}

Function Append-WorkitemField([string]$TFSURL, [string]$WorkitemId, [string]$FieldName, [string]$TextString)
{
    $val = Get-WorkitemFieldValue $TFSURL $WorkitemId $FieldName
    $val += $TextString
    Update-WorkitemField $TFSURL $WorkitemId $FieldName $val
}

Function QueryAndBulkEdit([string]$TFSURL, [string]$FieldNameForPath, [string]$WorkItemPath, [string]$FieldName, [string]$SearchString, [string]$FieldNameForUpdate, [string]$UpdateValue)
{
    $teamProjectCollection = [Microsoft.TeamFoundation.Client.TfsTeamProjectCollectionFactory]::GetTeamProjectCollection($TFSURL)
    $wit = $teamProjectCollection.GetService([Type]"Microsoft.TeamFoundation.WorkItemTracking.Client.WorkItemStore")

$WIQL = @"
SELECT [System.Id], [System.WorkItemType], [System.State], [System.AssignedTo], [System.Title] 
FROM WorkItems 
where [System.$FieldNameForPath] = '$WorkItemPath' AND [System.$FieldName] Contains '$SearchString'
ORDER BY [System.WorkItemType], [System.Id] 
"@

    Write-Host $WIQL

    #Don't do this, it updates silently without giving a text spew
    #$collection = $wit.Query($WIQL) | % { Update-WorkitemField $TFSURL $_.Id $FieldNameForUpdate $UpdateValue }

    $collection = $wit.Query($WIQL) 

    foreach($item in $collection)
    {
        Write-Host "Update $($item.Id) $FieldNameForUpdate Field with $UpdateValue"
        Update-WorkitemField $TFSURL $item.Id $FieldNameForUpdate $UpdateValue
    }
}