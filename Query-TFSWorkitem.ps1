<#
.SYNOPSIS
Get work item from TFS

.DESCRIPTION
This script will retrieve a work item from specified TFC User using QueryAndBulkEdit and imported lib.

.PARAMETER TFSLibLoc
location of TFS access library

.PARAMETER TFSURL
internet path to TFS server

.PARAMETER WorkItemPath
work item path on the TFS server

.PARAMETER SearchString
alias to filter with, usually your own

.PARAMETER UpdateValue
full display name in TFS

.EXAMPLE
.\Query-TFSWorkitem.ps1 -UpdateValue 'matt houston'
This will use all the defaults, but update the TFS full dislay name

#>

Param
(
    	[string]$TFSLibLoc='C:\scripts\QueryTFSWorkItems\tfs.work.item.lib.psm1',
    	[string]$TFSURL="http://<server>/<path>",
    	[string]$WorkItemPath="<Root\Path>",
        [string]$SearchString = "Customer: <user>",
        [string]$UpdateValue = "<name>"
)

Import-Module $TFSLibLoc

$FieldName = "Description"
$FieldNameForUpdate = "Assigned To"

QueryAndBulkEdit $TFSURL $fieldNameForPath $WorkItemPath $FieldName $SearchString $FieldNameForUpdate $UpdateValue
