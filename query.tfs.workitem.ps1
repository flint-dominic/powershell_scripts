Import-Module "C:\scripts\QueryTFSWorkItems\tfs.work.item.lib.psm1"

$TFSURL = "http://server:8080/tfs/CDM"
$FieldNameForPath = "AreaPath"
$WorkItemPath = "Root\Path"

$FieldName = "Description"
#Replace "user" with your own alias
$SearchString = "Customer: user"  
$FieldNameForUpdate = "Assigned To"
#replace "name" with your full display name in TFS"
$UpdateValue = "name"

QueryAndBulkEdit $TFSURL $FieldNameForPath $WorkItemPath $FieldName $SearchString $FieldNameForUpdate $UpdateValue
