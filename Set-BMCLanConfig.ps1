<#
.SYNOPSIS
Change BMC IP's.

.DESCRIPTION
This script will udpate BMC IP's using a CSV file using input creds

.PARAMETER ipmitoolPath
location of the ipmi tool path

.PARAMETER CSVPath
location of the BMC nodes to change

.PARAMETER GatewayIP
gateway address to change too

.PARAMETER SubNetMask
subnet mask to change too

.PARAMETER $creds
this will be prompted for

.EXAMPLE
.\Set-BMCLanConfig.ps1 -ipmitoolPath 'C:\tmp\' -CSVPath 'C:\tmp\bmclist.csv' -GatewayIP '192.168.0.1' -SubNetMask '255.255.255.0'
This would use the stated variables to change the BMC addresses.

#>

param
(
    [Parameter(Mandatory=$True)]
    [string]$ipmitoolPath,

    [Parameter(Mandatory=$True)]
    [string]$CSVPath,

    [Parameter(Mandatory=$True)]
    [string]$GatewayIP,

    [Parameter(Mandatory=$True)]
    [string]$SubNetMask,

    [Parameter(Mandatory=$True)]
    [PSCredential]$creds
)

$BMCData = Import-CSV $CSVPath
$Password = $creds.GetNetworkCredential().Password
$Username = $creds.UserName

cd $ipmitoolPath

foreach ($BMCNode in $BMCData) {
    $Attempt = "Attempting LAN Configuration on {0}" -f $BMCNode.Name
    Write-Output $Attempt

    #Set New IP for Node
    $NewIPOut = .\ipmitool.exe -H $BMCNode.BMCIP -P $Password -U $Username lan set 1 ipaddr $BMCNode.NewIP
    Start-Sleep -Seconds 5

    #Update Gateway for Node (leveraging new IP)
    $GWOut = .\ipmitool.exe -H $BMCNode.NewIP -P $Password -U $Username lan set 1 defgw ipaddr $GatewayIP

    #Update Subnet Mask for Node (leveraging new IP)
    $NetMaskOut = .\ipmitool.exe -H $BMCNode.NewIP -P $Password -U $Username lan set 1 netmask $SubNetMask
    
    Write-Output $NewIPOut
    Write-Output $GWOut
    Write-Output $NetMaskOut
}
