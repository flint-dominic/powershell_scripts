<#
.SYNOPSIS
Utility scripts for ASD AD to AAD migration project.

.DESCRIPTION
These need to have AD and Az modules installed and be logged into and authorized to both Azure and local AD.
TO start, use dot notion from powershell '. .\utility.ps1'
Connect-AzureAD
Connect-AzAccount
TODO: add initializtion script.

.PARAMETER DCName
The AD DC to target.

.PARAMETER ClientRGname
The Resouce Group Name to create and work with.

.EXAMPLE
Get-ActiveUG -DCName MyPDC
#>

Param
(
    [Parameter()][string]$DCName='',
    [Parameter()][string]$ClientRGName='',
    [Parameter()][string]$DSRGName='',
    [Parameter()][string]$ASDLocation='',
    [Parameter()][string]$OnpremGWIP='',
    [Parameter()][string[]]$OnpremPrefix=@(),
    [Parameter()][string]$ClientVNName='',
    [Parameter()][string]$DSVNName='',
    [Parameter()][string]$ClientPeerName='',
    [Parameter()][string]$DSPeerName='',
    [Parameter()][string]$ClientPre='',
    [Parameter()][string]$DSSubName='',
    [Parameter()][string]$DSSubPre='',
    [Parameter()][string]$WorkloadSubName='',
    [Parameter()][string]$WorkloadSubPre='',
    [Parameter()][string]$FESubnetName='',
    [Parameter()][string]$FESubnetPrefix='',
    [Parameter()][string]$BESubnetName='',
    [Parameter()][string]$BESubnetPrefix='',
    [Parameter()][string]$GWSubnetName='',
    [Parameter()][string]$GWSubnetPrefix='',
    [Parameter()][string]$GWpip='',
    [Parameter()][string]$GWpipConfig='',
    [Parameter()][string]$GWName='',
    [Parameter()][string]$GWCliAddrPool='',
    [Parameter()][string]$AzSubId='',
    [Parameter()][string]$DomainName='',
    [Parameter()][string]$ClientSiteName='',

    [Parameter()][string]$ClientVNGConnect='',
    [Parameter()][string]$ClientRADIUSLinux='',
    [Parameter()][string]$ClientRADIUSLinuxIP='',
    [Parameter()][string]$ClientRADIUSLinuxIPnum='',
    [Parameter()][string]$ClientRADIUSLinuxNSG='',
    [Parameter()][string]$ClientRADIUSLinuxSSH='',
    [Parameter()][string]$ClientRADIUSLinuxHTTP='',
    [Parameter()][string]$ClientRADIUSLinuxNIC=''
)

# Retrieves active users from AD and AAD
function Get-ActiveUG {
    Write-Host "Retrieving active users.... "
    $ActAdUsers = Get-ADUser -Filter {Enabled -eq $True} -Server $DCName | Measure-Object
    Write-Host " Active AD users : $ActAdUsers.Count " -Space
    $AdGroups = Get-ADGroup -Filter * -Server $DCName | Measure-Object
    Write-Host " AD groups : $AdGroups.Count " -Space
    $ActAzUsers = Get-AzADUser | Measure-Object
    Write-Host " AAD users : $ActAzUsers.Count " -Space
    $AadGroups = Get-AzADGroup | Measure-Object
    Write-Host " AAD groups : $AadGroups.Count " -Space
}

# Retrieves users active in last 90 days
function Get-Active90 {
    Write-Host "Retrieving users active in last 90 days.... "
    $OutExp = @{Exp={([DateTime]::FromFileTime($_.lastlogintimestamp))};label="Last logon time stamp"}
    $GetAdd = Get-ADUser -Filter {Enabled -eq $True} -Properties Displayname, Lastlogontimestamp
    $WhrObj = $GetAdd | Where-Object {(((Get-Date) - ([DateTime]::FromFileTime($_.lastlogontimestamp))).TotalDays -gt 90)}
    $WhrObj | Select-Object DisplayName, Samaccountname, Userprincipalname, $OutExp
    Write-Host " Active last 90 days : $WhrObj "
}

# Creates Virtual Network - #1
# TODO: seperate RG and move other subnet creation here.
function New-VirNet
{
    Write-Host " Creating Virtual Network " $ClientVNName -ForegroundColor Green
    if (Get-AzResourceGroup -Name $ClientRGName)
    {
        Write-Host " Resource Group: (" $ClientRGName ") already exists." -ForegroundColor Cyan
    }
    else
    {
        Write-Host " Creating Resource Group " $ClientRGName -ForegroundColor Green
        New-AzResourceGroup `
        -Name $ClientRGName `
        -Location $ASDLocation
    }
    $AsddsSubnet = New-AzVirtualNetworkSubnetConfig `
        -Name $DSSubName `
        -AddressPrefix $DSSubPre
    $AsdWlSubnet = New-AzVirtualNetworkSubnetConfig `
        -Name $WorkloadSubName `
        -AddressPrefix $WorkloadSubPre
    $AsdGWSubnet = New-AzVirtualNetworkSubnetConfig `
        -Name $GWSubnetName `
        -AddressPrefix $GWSubnetPrefix
    $AsdFESubnet = New-AzVirtualNetworkSubnetConfig `
        -Name $FESubnetName `
        -AddressPrefix $FESubnetPrefix
    $AsdBESubnet = New-AzVirtualNetworkSubnetConfig `
        -Name $BESubnetName `
        -AddressPrefix $BESubnetPrefix
    if (Get-AzVirtualNetwork -Name $ClientVNName)
    {
        Write-Host " Virtual Network: (" $ClientVNName ") already exists, EXITING!" -ForegroundColor Cyan
    }
    else
    {
        Write-Host " Creating Virtual Network " $ClientVNName -ForegroundColor Green
        New-AzVirtualNetwork `
        -Name $ClientVNName `
        -ResourceGroupName $ClientRGName `
        -Location $ASDLocation `
        -AddressPrefix $ClientPre `
        -Subnet $AsddsSubnet, $AsdWlSubnet, $AsdGWSubnet, $AsdFESubnet, $AsdBESubnet
    }
}

# Create Ubuntu VM for utiliy #3
function New-ASDUtilityVM {
    Write-Host " Creating RADIUS host " $ClientRADIUSLinux -ForegroundColor Green
    $virnet = Get-AzVirtualNetwork -name $ClientVNName
    $securePassword = ConvertTo-SecureString ' ' -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential ("radiuser", $securePassword)
    $pip = New-AzPublicIpAddress `
        -ResourceGroupName $ClientRGName `
        -Location $ASDLocation `
        -AllocationMethod Static `
        -IdleTimeoutInMinutes 4 `
        -Name $ClientRADIUSLinuxIP
    $nsgRuleSSH = New-AzNetworkSecurityRuleConfig `
        -Name $ClientRADIUSLinuxSSH `
        -Protocol "Tcp" `
        -Direction "Inbound" `
        -Priority 1000 `
        -SourceAddressPrefix * `
        -SourcePortRange * `
        -DestinationAddressPrefix * `
        -DestinationPortRange 22 `
        -Access "Allow"
    $nsgRuleWeb = New-AzNetworkSecurityRuleConfig `
        -Name $ClientRADIUSLinuxHTTP `
        -Protocol "Tcp" `
        -Direction "Inbound" `
        -Priority 1001 `
        -SourceAddressPrefix * `
        -SourcePortRange * `
        -DestinationAddressPrefix * `
        -DestinationPortRange 80 `
        -Access "Allow"
    $nsg = New-AzNetworkSecurityGroup `
        -ResourceGroupName $ClientRGName `
        -Location $ASDLocation `
        -Name $ClientRADIUSLinuxNSG `
        -SecurityRules $nsgRuleSSH,$nsgRuleWeb
    $nic = New-AzNetworkInterface `
        -Name $ClientRADIUSLinuxNIC `
        -ResourceGroupName $ClientRGName `
        -Location $ASDLocation `
        -SubnetId $virnet.Subnets[1].Id `
        -PublicIpAddressId $pip.Id `
        -NetworkSecurityGroupId $nsg.Id
    $vmConfig = New-AzVMConfig `
        -VMName $ClientRADIUSLinux `
        -VMSize "Standard_D2" | `
        Set-AzVMOperatingSystem `
            -Linux `
            -ComputerName $ClientRADIUSLinux `
            -Credential $cred `
            -DisablePasswordAuthentication | `
            Set-AzVMSourceImage `
                -PublisherName "Canonical" `
                -Offer "UbuntuServer" `
                -Skus "18.04-LTS" `
                -Version "latest" | `
                Add-AzVMNetworkInterface `
                    -Id $nic.Id
    $sshPublicKey = Get-Content ~/.ssh/id_rsa.pub
    Add-AzVMSshPublicKey `
        -VM $vmConfig `
        -KeyData $sshPublicKey `
        -Path "/home/radiuser/.ssh/authorized_keys"
    if (Get-AzVM -Name $ClientRADIUSLinux) {
        Write-Host " VM: (" $ClientRADIUSLinux ") already exists! EXITING!" -ForegroundColor Cyan
    }
    else
    {
        Write-Host " Creating VM " $ClientRADIUSLinux -ForegroundColor Green
        New-AzVM `
            -ResourceGroupName $ClientRGName `
            -Location $ASDLocation `
            -VM $vmConfig

    }
}

function New-ASDUsersGW
{
    Write-Host " Creating ASD User Gateway " $GWName -ForegroundColor Green
    $vnet = Get-AzVirtualNetwork `
        -Name $ClientVNName `
        -ResourceGroupName $ClientRGName
    $subnet = Get-AzVirtualNetworkSubnetConfig `
        -Name $GWSubnetName `
        -VirtualNetwork $vnet
    Write-Host " Got subnet: " $subnet.Name -ForegroundColor Cyan
    if (Get-AzPublicIpAddress -Name $GWpip)
    {
        Write-Host " PIP exists! Using: " $GWpip -ForegroundColor Cyan
        $pip = Get-AzPublicIpAddress -Name $GWpip
    }
    Else
    {
        Write-Host " Creating new PIP: " $GWpip -ForegroundColor Green
        $pip = New-AzPublicIpAddress `
            -Name $GWpip `
            -ResourceGroupName $ClientRGName `
            -Location $ASDLocation `
            -AllocationMethod Dynamic
    }
    Write-Host " Got PIP: " $pip.Name -ForegroundColor Cyan
    $ipconf = New-AzVirtualNetworkGatewayIpConfig `
        -Name $GWpipConfig `
        -Subnet $subnet `
        -PublicIpAddress $pip
    Write-Host " Got IP config: " $ipconf.Name -ForegroundColor Cyan
    if (Get-AzVirtualNetworkGateway -Name $GWName) {
        Write-Host " Gateway: (" $GWName ") already exists! EXITING!" -ForegroundColor Cyan
    }
    else
    {
        Write-Host " Creating Gateway " $GWName -ForegroundColor Green
        New-AzVirtualNetworkGateway `
            -Name $GWName `
            -ResourceGroupName $ClientRGName `
            -Location $ASDLocation `
            -IpConfigurations $ipconf `
            -GatewayType Vpn `
            -VpnType RouteBased `
            -EnableBgp $false `
            -GatewaySku VpnGw1
    }
}

# Creats P2S VPN #4
function New-ASDP2S {
    Write-Host " Creating P2S VPN on: " $GWName -ForegroundColor Cyan
    $Secure_Secret=Read-Host -AsSecureString -Prompt "RadiusSecret"
    $Gateway = Get-AzVirtualNetworkGateway `
        -ResourceGroupName $ClientRGName `
        -Name $GWName
    Write-Host " Adding P2S to Gateway: " $Gateway.Name -ForegroundColor Green
    Set-AzVirtualNetworkGateway `
        -VirtualNetworkGateway $Gateway `
        -VpnClientAddressPool $GWCliAddrPool `
        -VpnClientProtocol @( "SSTP", "IkeV2" ) `
        -RadiusServerAddress $ClientRADIUSLinuxIPnum `
        -RadiusServerSecret $Secure_Secret
}

# Creates S2S VPN #4
# TODO: setup onprem side with IP address 65.156.61.202
function New-ASDS2S {
    Write-Host " Creating S2S VPN for " $GWName -ForegroundColor Cyan
    # $vnet = Get-AzVirtualNetwork -ResourceGroupName $ClientRGName -Name $ClientVNName
    $subnet = Get-AzVirtualNetworkSubnetConfig -Name $GWSubnetName -VirtualNetwork $ClientVNName
    $gwpip = Get-AzPublicIpAddress -Name $ClientGWIPName -ResourceGroupName $ClientRGName
    $gwipconfig = New-AzVirtualNetworkGatewayIpConfig -Name $ClientGWIPConfig -SubnetId $subnet.Id -PublicIpAddressId $gwpip.Id
    # Add-AzVirtualNetworkSubnetConfig -Name $GWSubnetName -AddressPrefix $GWSubnetPrefix -VirtualNetwork $vnet
    # Set-AzVirtualNetwork -VirtualNetwork $vnet
    $securePassword = ConvertTo-SecureString ' ' -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential ("shared secret", $securePassword)
    if (Get-AzLocalNetworkGateway -Name $ClientSiteName -ResourceGroupName $ClientRGName)
    {
        Write-Host " Using existing local GW " $ClientSiteName -ForegroundColor Cyan
        $local = Get-AzLocalNetworkGateway `
            -Name $ClientSiteName `
            -ResourceGroupName $ClientRGName
    }
    else
    {
        Write-Host " Creating new local GW " $ClientSiteName -ForegroundColor Green
        $local = New-AzLocalNetworkGateway `
            -Name $ClientSiteName `
            -ResourceGroupName $ClientRGName `
            -Location $ASDLocation `
            -GatewayIpAddress $OnpremGWIP `
            -AddressPrefix $OnpremPrefix
    }
    if (Get-AzVirtualNetworkGateway -Name $GWName -ResourceGroupName $ClientRGName)
    {
        Write-Host " Using existing VN Gateway " $GWName -ForegroundColor Cyan
        $gateway1 = Get-AzVirtualNetworkGateway `
            -Name $GWName `
            -ResourceGroupName $ClientRGName
    }
    else
    {
        Write-Host " Creating new VN Gateway " $GWName -ForegroundColor Green
        $gateway1 = New-AzVirtualNetworkGateway `
            -Name $GWName `
            -ResourceGroupName $ClientRGName `
            -Location $ASDLocation `
            -IpConfigurations $gwipconfig `
            -GatewayType Vpn `
            -VpnType RouteBased `
            -GatewaySku VpnGw1
    }
    New-AzVirtualNetworkGatewayConnection `
        -Name $ClientVNGConnect `
        -ResourceGroupName $ClientRGName `
        -Location $ASDLocation `
        -VirtualNetworkGateway1 $gateway1 `
        -LocalNetworkGateway2 $local `
        -ConnectionType IPsec `
        -RoutingWeight 10 `
        -SharedKey $cred
}

    # Create Peering between Client and DS VN's
# TODO: may need to block virtual network access.
# TODO: automate DNS changes to ASD user VN
function New-ASDPeer {
    Write-Host " Creating Peering between" $ClientVNName "and" $DSVNName -ForegroundColor Cyan
    $vnet1 = Get-AzVirtualNetwork `
        -ResourceGroupName $ClientRGName `
        -Name $ClientVNName
    Add-AzVirtualNetworkPeering `
        -Name $ClientPeerName `
        -VirtualNetwork $vnet1 `
        -RemoteVirtualNetworkId "/subscriptions/$AzSubId/resourceGroups/$DSRGName/providers/Microsoft.Network/virtualNetworks/$DSVNName" `
        -AllowGatewayTransit

    $vnet2 = Get-AzVirtualNetwork `
        -ResourceGroupName $DSRGName `
        -Name $DSVNName
    Add-AzVirtualNetworkPeering `
        -Name $DSPeerName `
        -VirtualNetwork $vnet2 `
        -RemoteVirtualNetworkId "/subscriptions/$AzSubId/resourceGroups/$ClientRGName/providers/Microsoft.Network/virtualNetworks/$ClientVNName" `
        -UseRemoteGateways

<#
    $peer = Get-AzVirtualNetworkPeering `
        -VirtualNetworkName $DSVNName `
        -ResourceGroupName $DSRGName `
        -Name $DSPeerName
    $peer.AllowVirtualNetworkAccess = $false
    Set-AzVirtualNetworkPeering -VirtualNetworkPeering $peer
#>
}

# Creates AAD DS instance, need global administrator to enable AAD DS, need contributor to create #2
# Not a vaiable option, can only deploy one DS, looking into peering.
# TODO: change dns settings on VN to point to DS, select DNS in DS tab to autoconfigure.
# TODO: create NSG to restrict traffic in VN, select overview, will be autoprompted to create.
# TODO: enable password sync.
function New-ASDDS {
    Write-Host " Creating AAD DS for Virtual Network " $ClientVNName
    New-AzResource `
        -ResourceId "/subscriptions/$AzSubId/resourceGroups/$ClientRGName/providers/Microsoft.AAD/DomainServices/$DomainName" `
        -Location $ASDLocation `
        -Properties @{"DomainName"=$DomainName; `
            "SubnetId"="/subscriptions/$AzSubId/resourceGroups/$ClientRGName/providers/Microsoft.Network/virtualNetworks/$ClientVNName/subnets/$DSSubName"} `
        -Force -Verbose

}

# Migrate target ip addresses
function Move-IPAddr {
    $nicname = 'prod-asdusers-vm01-nif'
    $vmname = 'prod-asdusers-vm01'
    $rgname = 'prod-asdusers'
    $vnetname = 'prod-asdusers-vnet'
    $subnet2name = 'asdvpnfesn'
    $vm = Get-AzVM -ResourceGroupName $rgname -Name $vmname
    $VirtualMachine.AvailabilitySetReference

    $nic = Get-AzNetworkInterface -Name $nicname -ResourceGroupName $rgname
    $nic.IpConfigurations[0].PrivateIpAddress

    $vnet = Get-AzVirtualNetwork -Name $vnetname -ResourceGroupName $rgname
    $subnet2 = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $subnet2name

    $nic.IpConfigurations[0].SubnetId = $subnet2.Id

    Set-AzNetworkInterface -NetworkInterface $nic
}
