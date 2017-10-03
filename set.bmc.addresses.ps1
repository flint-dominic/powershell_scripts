Param
(
    [Parameter(Mandatory=$false)][string]$BMCDataFile,
    [Parameter(Mandatory=$false)][string]$BMCIPAddress,
    [Parameter(Mandatory=$false)][string]$Password = "p@ssw0rd",
    [Parameter(Mandatory=$false)][string]$UserName = "Administrator",
    [Parameter(Mandatory=$false)][string]$NetId = "1",
    [Parameter(Mandatory=$false)][string]$NewIPAddress,
    [Parameter(Mandatory=$false)][string]$NetMask,
    [Parameter(Mandatory=$false)][string]$Gateway
)
[string]$ScriptPath = (Split-Path $MyInvocation.MyCommand.Path)
$IPMITool = $ScriptPath + "\ipmitool.exe "
If (-not(Test-Path $IPMITool)) { Throw "ipmitool.exe could not be found in the current directory" }

If ($BMCDataFile)
{
    $BMCData = Import-Csv $BMCDataFile
    ForEach ($BMCNode In $BMCData)
    {
        If ($BMCNode.Skip -eq "FALSE")
        {
            If ($BMCNode.Name) { Write-Output ( "NAME: " + $BMCNode.Name) }
            If ($NetMask -or $Gateway)
            {
                If ($Gateway)
                {
                    Write-Output ("    SET-GATEWAY  NEW_GW: " + $Gateway)
                    & $IPMITool -I lanplus -H $BMCNode.NewIP -P $Password -U $UserName lan set $NetId defgw ipaddr $Gateway
                }
                If ($NetMask)
                {
                    Write-Output ("    SET-NETMASK  NEW_MASK: " + $NetMask)
                    & $IPMITool -I lanplus -H $BMCNode.NewIP -P $Password -U $UserName lan set $NetId netmask $NetMask
                }
            }
            If ($BMCNode.NewIP)
            {
                Write-Output ("    SET-IP  OLD_IP: " + $BMCNode.BMCIP + "  NEW_IP: " + $BMCNode.NewIP)
                & $IPMITool -I lanplus -H $BMCNode.BMCIP -P $Password -U $UserName lan set $NetId ipaddr $BMCNode.NewIP
            }
        }
    }
}
ElseIf ($BMCIPAddress)
{
    Write-Output ("BMCIP: " + $BMCIPAddress)
    If ($NetMask -or $Gateway)
    {
        If ($Gateway)
        {
            Write-Output ("    SET-GATEWAY  NEW_GW: " + $Gateway)
            & $IPMITool -I lanplus -H $BMCIPAddress -P $Password -U $UserName lan set $NetId defgw ipaddr $Gateway
        }
        If ($NetMask)
        {
            Write-Output ("    SET-NETMASK  NEW_MASK: " + $NetMask)
            & $IPMITool -I lanplus -H $BMCIPAddress -P $Password -U $UserName lan set $NetId netmask $NetMask
        }
    }
    If ($NewIPAddress)
    {
        & $IPMITool -I lanplus -H $BMCIPAddress -P $Password -U $UserName lan set $NetId ipaddr $NewIPAddress
    }
}