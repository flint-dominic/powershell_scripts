<#
.SYNOPSIS
Used to update BMC IP addresses from CSV file.

.DESCRIPTION
This script will use a list of old/new IP address to update BMC IP addresses using the ipmi tool.

.PARAMETER BMCDataFile
location of CSV list

.PARAMETER BMCIPAddress
old IP address to change, not used if CSV given

.PARAMETER Password
BMC password to use

.PARAMETER UserName
BMC username to use

.PARAMETER NetID
the vlan to use

.PARAMETER NewIPAddress
new IP address to change, not used if CSV given

.PARAMETER NetMask
which network mask to use

.PARAMETER Gateway
which gateway to use

.EXAMPLE
.\Set-BMCAddresses -BMCDataFile 'C:\tmp\listofchanges.csv'
This would update the BMC IP addresses using the stated list.

#>

Param
(
    [Parameter(Mandatory=$false)][string]$BMCDataFile,
    [Parameter(Mandatory=$false)][string]$BMCIPAddress,
    [Parameter(Mandatory=$false)][string]$Password = "<password>",
    [Parameter(Mandatory=$false)][string]$UserName = "<username>",
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
    $BMCData = Import-CSV $BMCDataFile
    ForEach ($BMCNode In $BMCData)
    {
        If ($BMCNode.Skip -eq "FALSE")
        {
            If ($BMCNode.Name) { Write-Output ( "Name: " + $BMCNode.Name) }
            If ($NetMask -or $Gateway)
            {
                If ($Gateway)
                {
                    Write-Output ("    Set-Gateway  NEW_GW: " + $Gateway)
                    & $IPMITool -I lanplus -H $BMCNode.NewIP -P $Password -U $UserName lan set $NetId defgw ipaddr $Gateway
                }
                If ($NetMask)
                {
                    Write-Output ("    Set-Netmask  NEW_MASK: " + $NetMask)
                    & $IPMITool -I lanplus -H $BMCNode.NewIP -P $Password -U $UserName lan set $NetId netmask $NetMask
                }
            }
            If ($BMCNode.NewIP)
            {
                Write-Output ("    Set-IP  OLD_IP: " + $BMCNode.BMCIP + "  NEW_IP: " + $BMCNode.NewIP)
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
            Write-Output ("    Set-Gateway  NEW_GW: " + $Gateway)
            & $IPMITool -I lanplus -H $BMCIPAddress -P $Password -U $UserName lan set $NetId defgw ipaddr $Gateway
        }
        If ($NetMask)
        {
            Write-Output ("    Set-Netmask  NEW_MASK: " + $NetMask)
            & $IPMITool -I lanplus -H $BMCIPAddress -P $Password -U $UserName lan set $NetId netmask $NetMask
        }
    }
    If ($NewIPAddress)
    {
        & $IPMITool -I lanplus -H $BMCIPAddress -P $Password -U $UserName lan set $NetId ipaddr $NewIPAddress
    }
}
