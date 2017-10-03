<#
.EXAMPLE
    
    $creds = Get-Credential

    .\SetBMCLANConfig.ps1 -ipmitoolPath "C:\Users\Administrator\Desktop\ipmitool\" -CSVPath "C:\Users\Administrator\Desktop\BMCData\r2staticIP_nonSSU.csv" `
        -GatewayIP "192.168.161.1" -SubNetMask "255.255.255.128" -creds $creds |Out-File .\r#BMCLANConfigInfo.txt

.EXAMPLE

    $Username = "user"
    $Password = "myPassword"
    $securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
    $creds = New-Object -TypeName System.Management.Automation.PSCredential -argumentlist $Username,$securePassword

    .\SetBMCLANConfig.ps1 -ipmitoolPath "C:\Users\Administrator\Desktop\ipmitool\" -CSVPath "C:\Users\Administrator\Desktop\BMCData\r2staticIP_nonSSU.csv" `
        -GatewayIP "192.168.161.1" -SubNetMask "255.255.255.128" -creds $creds |Export-Clixml .\r1BMCInfo.xml

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

$BMCData = Import-Csv $CSVPath
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