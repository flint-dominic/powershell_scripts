Import-Module "C:\scripts\QueryTFSWorkItems\tfs.work.item.lib.psm1"

$TFSURL = "http://<server>/<path>"
$fieldNameForPath = "<AreaPath>"
$workItemPath = "<Root\Path>"

$fieldName = "Description"
#Replace "user" with your own alias
$searchString = "Customer: <user>"  
$fieldNameForUpdate = "Assigned To"
#replace "name" with your full display name in TFS"
$updateValue = "<name>"

QueryAndBulkEdit $TFSURL $fieldNameForPath $workItemPath $fieldName $searchString $fieldNameForUpdate $updateValue
