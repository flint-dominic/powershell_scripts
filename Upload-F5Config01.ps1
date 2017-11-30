<#
.SYNOPSIS
Upload F5 config file and reboot.

.DESCRIPTION
This script will update the config file on F5 load balancer using iControl snappin.

.PARAMETER manifest1ConfigFilename
location of the xml configuration file

.PARAMETER f5DevDesiredAdminPassword
F5 new Admin password

.PARAMETER f5DevDesiredRootPassword
F5 new Root password

.PARAMETER f5Dev1IP
IP address of the primary F5 load balancer

.PARAMETER f5Dev2IP
IP address of the secondary F5 load balancer

.PARAMETER f5CurrentAdminPassword
F5 current Admin password

.PARAMETER f5CurrentRootPassword
F5 current Root password

.EXAMPLE
.\Upload-F5Config01.ps1

#>

param ( 
	[Parameter(Mandatory=$true)]
	[string] $manifest1ConfigFilename,
	[Parameter(Mandatory=$true)]
	[string] $f5DevDesiredAdminPassword,
	[Parameter(Mandatory=$true)]
	[string] $f5DevDesiredRootPassword,
	[Parameter(Mandatory=$false)]
	[string] $f5Dev1IP,
	[Parameter(Mandatory=$false)]
	[string] $f5Dev2IP,
	[Parameter(Mandatory=$false)]
	[string] $f5CurrentAdminPassword,
	[Parameter(Mandatory=$false)]
	[string] $f5CurrentRootPassword
)
	
Write-host "parameter values are manifest1ConfigFilename " $manifest1ConfigFilename
Write-host "parameter values are f5Dev1AdminPassword " $f5DevDesiredAdminPassword
Write-host "parameter values are f5DevDesiredRootPassword " $f5DevDesiredRootPassword
	
$ErrorActionPreference = "Stop"
$manifest = Get-Content -Path $manifest1ConfigFilename
$rack1Config = [xml] ($manifest.Trim())
$F5DevicesNode1 = $rack1Config.CustomerConfiguration.Configurator.LoadBalancerConfig.F5Devices.F5Device[0]
$F5DevicesNode2 = $rack1Config.CustomerConfiguration.Configurator.LoadBalancerConfig.F5Devices.F5Device[1]
$SnmpCommunityString = $rack1Config.CustomerConfiguration.Configurator.NetworkManagement.SNMPCommunityString.Trim()
$F5_HOSTNAME = ($F5DevicesNode1.Name.Trim(), $F5DevicesNode2.Name.Trim())
$F5_PASSWD_ROOT = ($f5DevDesiredRootPassword.Trim(), $f5DevDesiredRootPassword.Trim())
$F5_PASSWD_ADMIN = ($f5DevDesiredAdminPassword.Trim(), $f5DevDesiredAdminPassword.Trim())
$F5_configsyncip = ($F5DevicesNode1.ConfigSyncIP.Trim(), $F5DevicesNode2.ConfigSyncIP.Trim())
$F5_KEYS = (("<f5 key1>"), ("<f5 key2>"));
$racknetworks = @{}

foreach ($n in $rack1Config.CustomerConfiguration.ManagementGuest.LogicalNetworks.Network)
{
	$racknetworks.Add($n.Name, $n)
}

$DNS_SERVER_LIST = $racknetworks["Infrastructure"].DNSServer.IPV4Addresses.Address
$EXTERNAL_SU1_GATEWAY = $racknetworks["External"].GatewayServer.IPV4Addresses.Address.Trim()
	
if([string]::IsNullOrEmpty($EXTERNAL_SU1_GATEWAY))
{
	Throw "Manifest file: External network's GatewayServer.IPV4Addresses.Address node should not be empty."
}

function F5_get_Network_values()
{
	param($racknetworks, $lnName, $checkLB = $True);
        $ret = @{}
        $dip = @(0,0)
        foreach ($a in $racknetworks[$lnName].AssignedIPAddresses.AssignedIPAddress)
        {
            if ($a.Type -eq "LoadBalancer-Float")
            {
                $ret.VIP = $a.IPAddress.Trim();
            }
            elseif ($a.Type -eq "LoadBalancer-Static1")
            {
                $dip[0] = $a.IPAddress.Trim();
            }
            elseif ($a.Type -eq "LoadBalancer-Static2")
            {
                $dip[1] = $a.IPAddress.Trim();
            }
        }	
	if($checkLB -eq $True)
        {
            if([string]::IsNullOrEmpty($ret.VIP))
            {
                throw "Customer Manifest file: Network ($lnName) doesn't define [AssignedIPAddresses] for LoadBalancer-Float"
            }
            if(($dip[0] -eq 0) -or [string]::IsNullOrEmpty($dip[0]))
            {
                throw "Customer Manifest file: Network ($lnName) doesn't define [AssignedIPAddresses] for LoadBalancer-Static1"
            }
            if(($dip[1] -eq 0) -or [string]::IsNullOrEmpty($dip[1]))
            {
                throw "Customer Manifest file: Network ($lnName) doesn't define [AssignedIPAddresses] for LoadBalancer-Static2"
            }
        }
        $ret.DIP = $dip;
        $ret.PrefixLen = $racknetworks[$lnName].IPV4Subnet.Split('/')[1]
        $ret
}

$LN_INFRA_SU01_FLOAT_IP = $rack1Config.CustomerConfiguration.Configurator.LoadBalancerConfig.InfrastructureVIP.Trim()
$LN_INFRA_SU01_NONFLOAT_IP = ($F5DevicesNode1.InfrastructureDIP, $F5DevicesNode2.InfrastructureDIP).Trim()
$r = F5_get_Network_values -racknetworks $racknetworks -lnName "Infrastructure" -checkLB $False
$LN_INFRA_SU01_PREFIX_LENGTH =  $r.PrefixLen
$r = F5_get_Network_values -racknetworks $racknetworks -lnName "External"
$LN_EXT_SU01_FLOAT_IP = $r.VIP
$LN_EXT_SU01_NONFLOAT_IP = $r.DIP
$LN_EXT_SU01_PREFIX_LENGTH = $r.PrefixLen
$r = F5_get_Network_values -racknetworks $racknetworks -lnName "Load Balancer"
$LN_LB_SU01_FLOAT_IP =  $r.VIP
$LN_LB_SU01_NONFLOAT_IP = $r.DIP
$LN_LB_SU01_PREFIX_LENGTH = $r.PrefixLen
$r = F5_get_Network_values -racknetworks $racknetworks -lnName "Services"
$LN_SVC_SU01_FLOAT_IP =  $r.VIP
$LN_SVC_SU01_NONFLOAT_IP = $r.DIP
$LN_SVC_SU01_PREFIX_LENGTH = $r.PrefixLen
$MANAGEMENT_IP = ($F5DevicesNode1.BmcIP.Trim(), $F5DevicesNode2.BmcIP.Trim())

if( [string]::IsNullOrEmpty($MANAGEMENT_IP[0]) -or [string]::IsNullOrEmpty($MANAGEMENT_IP[1]) )
{
	Throw "Manifest file: CustomerConfiguration.Configurator.LoadBalancerConfig.F5Devices.F5Device should have valid values for the two BmcIP nodes"
}
	
$MANAGEMENT_IP_PREFIX_LENGTH = ($F5DevicesNode1.BmcSubnetPrefixLength, $F5DevicesNode2.BmcSubnetPrefixLength)

if( [string]::IsNullOrEmpty($MANAGEMENT_IP_PREFIX_LENGTH[0]) -or [string]::IsNullOrEmpty($MANAGEMENT_IP_PREFIX_LENGTH[1]) )
{
	Throw "Manifest file: CustomerConfiguration.Configurator.LoadBalancerConfig.F5Devices.F5Device should have valid values for the two BmcSubnetPrefixLength nodes"
}

$MANAGEMENT_ROUTE_GATEWAY = ($F5DevicesNode1.BmcGatewayAddress.Trim(), $F5DevicesNode2.BmcGatewayAddress.Trim() )

if( [string]::IsNullOrEmpty($MANAGEMENT_ROUTE_GATEWAY[0]) -or [string]::IsNullOrEmpty($MANAGEMENT_ROUTE_GATEWAY[1]) )
{
	Throw "Manifest file: CustomerConfiguration.Configurator.LoadBalancerConfig.F5Devices.F5Device should have valid values for the two BmcGatewayAddress nodes"
}

$DNS_SERVER_LIST_BLANK_SEPARATED = ""

if( $DNS_SERVER_LIST -ne $null -and $DNS_SERVER_LIST.Count -gt 0 )
{
	$DNS_SERVER_LIST_BLANK_SEPARATED = $DNS_SERVER_LIST[0]
	for($ndx=1; $ndx -lt $DNS_SERVER_LIST.Count; $ndx++)
	{
	$DNS_SERVER_LIST_BLANK_SEPARATED += " " + $DNS_SERVER_LIST[$ndx]
	}
}

$F5_DEFAULT_IP = ("<default IP1>", "<default IP2>")
if($f5Dev1IP)
{
	$F5_DEFAULT_IP[0] = $f5Dev1IP.Trim()
}
if($f5Dev2IP)
{
        $F5_DEFAULT_IP[1] = $f5Dev2IP.Trim()
}

$F5_DEFAULT_ADMIN_PASSWD = "admin"
$F5_DEFAULT_ROOT_PASSWD = "default"

if($f5CurrentAdminPassword)
{
	$F5_CURRENT_ADMIN_PASSWD = $f5CurrentAdminPassword
}
else
{
	$F5_CURRENT_ADMIN_PASSWD = $F5_DEFAULT_ADMIN_PASSWD
}
	
if($f5CurrentRootPassword)
{
	$F5_CURRENT_ROOT_PASSWD = $f5CurrentRootPassword
}
else
{
	$F5_CURRENT_ROOT_PASSWD = $F5_DEFAULT_ROOT_PASSWD
}
	
$WORKING_DIR = [System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Definition)
$snapin = Get-PSSnapin | Where-Object {$_.Name -eq "iControlSnapIn"}

if( $snapin -eq $null)
{
	try
	{
		Add-PSSnapin iControlSnapIn
	}
	catch
	{
		TraceDebug -text "Failed to add iControlSnapin. Make sure the F5 PowerShell Snapin has been installed and registered on the machine and try the scrip again."
		throw "Add-PSSnapin iControlSnapIn failed."
	}
}

function Trace
{
	param([Parameter(Mandatory=$true)] $text)
	Write-Host $text -ForegroundColor Green
}

function TraceDebug
{
	param([Parameter(Mandatory=$true)] $text)
	Write-host -ForegroundColor Yellow $text
}

function TraceError
{
        param([Parameter(Mandatory=$true)] $text)
	Write-host -ForegroundColor Red $text
}
	
function get-subnetMask
{
	param ([Parameter(Mandatory=$true)] $ipSubnet)
        $a = $ipSubnet.Split('/')
        $prefixLen = [System.Int16]::Parse($a[1])
        $uMask = (0xffffffffL -shl (32-$prefixLen)) -band 0xffffffffL
        $uMask= [System.Net.IPAddress]::HostToNetworkOrder($uMask) -shr 32
        $ipBytes = [System.BitConverter]::GetBytes([int]$uMask)
        $subnetIP = new-object System.Net.IPAddress(,$ipBytes)

        Return $a[0], $subnetIP.ToString();
}

Trace -text "Trying to connect to $($F5_DEFAULT_IP[0]) using admin/$F5_CURRENT_ADMIN_PASSWD credentials"
$r = Initialize-F5.iControl -HostName $F5_DEFAULT_IP[0] -Username admin -Password $F5_CURRENT_ADMIN_PASSWD
Trace -text "    => connected!"

function apply-F5.configuration
{
	param(
            [Parameter(Mandatory=$true)] $f5_ip,
            [Parameter(Mandatory=$true)] $configFilename,
            [Parameter(Mandatory=$true)] $index
        )

        Write-Host -ForegroundColor Magenta "------------------------------------------------------------------"
        Write-Host -ForegroundColor Magenta "About to calculate and apply new configuration to F5 device $index."
        Write-Host -ForegroundColor Magenta "------------------------------------------------------------------"
	Write-Host -ForegroundColor Yellow "Do you want to execute this step? (y/n)"
	$ans = Read-Host

        if($ans -ne "y")
        {
		Write-Host -ForegroundColor Magenta "skipping apply-F5.configuration."
		return
        }

	Trace -text "Resetting F5 configuration to factory defaults."
	Start-Process putty.exe -Wait -ArgumentList ("-ssh root@$f5_ip -pw $F5_CURRENT_ROOT_PASSWD -m factoryReset.txt") -WorkingDirectory $WORKING_DIR
	Initialize-F5.iControl -HostName $f5_ip -Username admin -Password $F5_DEFAULT_ADMIN_PASSWD
	Trace -text "Copying the configuration file to F5"
	Upload-F5.File -RemoteFile /var/local/scf/CPS.scf -LocalFile "$WORKING_DIR\$configFilename"
	Trace -text "Applying newly uploaded configuration file on F5"
	$p = Start-Process cmd.exe -ArgumentList ("/c", "plink.exe -ssh root@$f5_ip -pw $F5_DEFAULT_ROOT_PASSWD -m loadConfiguration.txt") -PassThru -WorkingDirectory $WORKING_DIR  -RedirectStandardError $WORKING_DIR\log_err.txt -RedirectStandardOutput $WORKING_DIR\log.txt

        do
        {
		Start-Sleep -Seconds 1
        }
        while(-not $p.HasExited)
	TraceDebug -Text (Get-Content $WORKING_DIR\log.txt -Raw)
	$err = Get-Content "$WORKING_DIR\log_err.txt" -Raw
	if ($err.Length -ne 0)
	{
		throw $err
	}
		
	Trace -Text "Starting to use new IP $($MANAGEMENT_IP[$index])  to connect."
        $f5_ip = $MANAGEMENT_IP[$index]
	Initialize-F5.iControl -HostName $f5_ip -Username admin -Password $F5_DEFAULT_ADMIN_PASSWD
}

function generate-F5.config
{
	param(
		[Parameter(Mandatory=$true)] $configFilename, 
		[Parameter(Mandatory=$true)] $index
	)

	$configPath = "$WORKING_DIR\$configFilename"
	$_F5_HOSTNAME = $F5_HOSTNAME[$index]
	$_F5_configsyncip = $F5_configsyncip[$index]
	$_LN_EXT_SU01_NONFLOAT_IP = $LN_EXT_SU01_NONFLOAT_IP[$index]
	$_LN_INFRA_SU01_NONFLOAT_IP = $LN_INFRA_SU01_NONFLOAT_IP[$index]
	$_LN_LB_SU01_NONFLOAT_IP = $LN_LB_SU01_NONFLOAT_IP[$index]
	$_LN_SVC_SU01_NONFLOAT_IP = $LN_SVC_SU01_NONFLOAT_IP[$index]
	$_MANAGEMENT_IP = $MANAGEMENT_IP[$index]
        $_MANAGEMENT_IP_PREFIX_LENGTH = $MANAGEMENT_IP_PREFIX_LENGTH[$index]
	$_MANAGEMENT_ROUTE_GATEWAY = $MANAGEMENT_ROUTE_GATEWAY[$index]

	(cat $WORKING_DIR\config-TEMPLATE.txt) `
		-replace '@@F5_HOSTNAME@@', "$_F5_HOSTNAME" `
		-replace '@@F5_configsyncip@@', "$_F5_configsyncip" `
		-replace '@@DNS_SERVER_LIST_BLANK_SEPARATED@@', "$DNS_SERVER_LIST_BLANK_SEPARATED" `
		-replace '@@EXTERNAL_SU1_GATEWAY@@', "$EXTERNAL_SU1_GATEWAY" `
		-replace '@@LN_EXT_SU01_FLOAT_IP@@', "$LN_EXT_SU01_FLOAT_IP" `
		-replace '@@LN_EXT_SU01_NONFLOAT_IP@@', "$_LN_EXT_SU01_NONFLOAT_IP" `
		-replace '@@LN_EXT_SU01_PREFIX_LENGTH@@', "$LN_EXT_SU01_PREFIX_LENGTH" `
		-replace '@@LN_INFRA_SU01_FLOAT_IP@@', "$LN_INFRA_SU01_FLOAT_IP" `
		-replace '@@LN_INFRA_SU01_NONFLOAT_IP@@', "$_LN_INFRA_SU01_NONFLOAT_IP" `
		-replace '@@LN_INFRA_SU01_PREFIX_LENGTH@@', "$LN_INFRA_SU01_PREFIX_LENGTH" `
		-replace '@@LN_LB_SU01_FLOAT_IP@@', "$LN_LB_SU01_FLOAT_IP" `
		-replace '@@LN_LB_SU01_NONFLOAT_IP@@', "$_LN_LB_SU01_NONFLOAT_IP" `
		-replace '@@LN_LB_SU01_PREFIX_LENGTH@@', "$LN_LB_SU01_PREFIX_LENGTH" `
		-replace '@@LN_SVC_SU01_FLOAT_IP@@', "$LN_SVC_SU01_FLOAT_IP" `
		-replace '@@LN_SVC_SU01_NONFLOAT_IP@@', "$_LN_SVC_SU01_NONFLOAT_IP" `
		-replace '@@LN_SVC_SU01_PREFIX_LENGTH@@', "$LN_SVC_SU01_PREFIX_LENGTH" `
		-replace '@@MANAGEMENT_IP@@', "$_MANAGEMENT_IP" `
		-replace '@@MANAGEMENT_IP_PREFIX_LENGTH@@', "$_MANAGEMENT_IP_PREFIX_LENGTH" `
		-replace '@@MANAGEMENT_ROUTE_GATEWAY@@', "$_MANAGEMENT_ROUTE_GATEWAY" `
		> $configPath

	$content = Get-Content $configPath
	$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding($False)
	[System.IO.File]::WriteAllLines($configPath, $content, $Utf8NoBomEncoding)
}

function retrieve-F5.localData
{
	$localDevice = (get-f5.IControl).ManagementDevice.get_local_device()
	$MAC_ADDRESS = (get-f5.IControl).ManagementDevice.get_base_mac_address(($localDevice))
	Trace -text "Device: $localDevice"
	Trace -text "MAC: $MAC_ADDRESS"
}

function Get-IniContent
{
        param([Parameter(Mandatory=$true)] $filePath)

        $ini = @{}
        switch -regex -file $FilePath
        {
		"^\[(.+)\]"
		{
                	$section = $matches[1]
                	$ini[$section] = @{}
                	$CommentCount = 0
            	}
            	"^(;.*)$"
            	{
                	$value = $matches[1]
                	$CommentCount = $CommentCount + 1
                	$name = "Comment" + $CommentCount
                	$ini[$section][$name] = $value
            	} 
            	"(.+?)\s*=(.*)"
            	{
                	$name,$value = $matches[1..2]
                	$ini[$section][$name] = $value
            	}
        }
        return $ini
}

function activate-F5.licence
{
	param([Parameter(Mandatory=$true)] $index)

        Write-Host -ForegroundColor Magenta "------------------------------------------------------------------"
        Write-Host -ForegroundColor Magenta "About to try to ACTIVATE the license for F5 device $index."
        Write-Host -ForegroundColor Magenta "------------------------------------------------------------------"
	Write-Host -ForegroundColor Yellow "Do you want to execute this step? (y/n)"
	$ans = Read-Host

        if($ans -ne "y")
        {
		Write-Host -ForegroundColor Magenta "skipping license activation."
            	return
        }

	$LA = (get-f5.IControl).ManagementLicenseAdministration
	$ASCII = New-Object -TypeName System.Text.ASCIIEncoding
        $status = $LA.get_license_activation_status()

        if($status -eq [iControl.CommonEnabledState]::STATE_ENABLED)
        {
            	Write-Host -ForegroundColor Magenta "It looks like the device is already licensed!!"
		Write-Host -ForegroundColor Yellow "Do you want to execute this step? (y/n)"
		$ans = Read-Host

            	if($ans -ne "y")
            	{
                	Write-Host -ForegroundColor Magenta "skipping activation."
                	return
            	}
        } 

	$keys = $LA.get_registration_keys()

	if ($keys.Count -le 1)
	{	
            	Download-F5.File -RemoteFile "/config/BigDB.dat" -LocalFile "$WORKING_DIR\BigDB.dat"
            	$ini = Get-IniContent -filePath "$WORKING_DIR\BigDB.dat"

            	if ($ini.Count -ge 0 -and 
                	$ini["License.RegistrationKey"].Count -ge 0 -and 
                	$ini["License.RegistrationKey"].value)
            	{
                	$keys = $ini["License.RegistrationKey"].value
            	}
            	else
            	{
                	$keys = $F5_KEYS[$index]
            	}
	}

        TraceDebug -text "Going to request registration using key(s): $keys"
	$dossier = $LA.get_system_dossier($keys)
	TraceDebug -text "Dossier content: $dossier"
	[Windows.Forms.Clipboard]::SetDataObject($dossier, $true)
	Write-Host -ForegroundColor Magenta "The dossier info is in the clipboard, please paste it to the F5 licence server (http://activate.f5.com/license) and put the response back in the clipboard."
	Write-Host -ForegroundColor Magenta "Press any key when ready"
	Read-Host
	$activation = [Windows.Forms.Clipboard]::GetText();

	while(-not ($activation -like "*BIG-IP System License Key File*"))
	{
		Write-Host -ForegroundColor Magenta "Content in the clipboard doesn't look like a license activation. Press any key when ready"
		Read-Host
		$activation = [Windows.Forms.Clipboard]::GetText();
	}

	$LA.install_license($ASCII.GetBytes($activation))
	Trace -text "License activated on device. Now restarting the device..."
	$Services = (Get-F5.iControl).SystemServices
	$Services.set_service( (,"SERVICE_MCPD"), "SERVICE_ACTION_RESTART")
	Trace -text "Device ready."
}

function setpasswd-F5
{
	param (
		[Parameter(Mandatory=$true)] $user, 
		[Parameter(Mandatory=$true)] $passwd
	)

	Trace -text "Changing passwd for user [$user]."
	$um = (Get-F5.iControl).ManagementUserManagement
	$passwdInfo = New-Object iControl.ManagementUserManagementPasswordInfo
	$passwdInfo.is_encrypted = $FALSE;
	$passwdInfo.password = $passwd;
	$um.change_password_2(($user), ($passwdInfo))
}

function setup-F5.Trust
{
        Write-Host -ForegroundColor Magenta "----------------------------------------------------------------------------"
        Write-Host -ForegroundColor Magenta "About to set up device trust between F5 devices (clustering/failover group)."
        Write-Host -ForegroundColor Magenta "----------------------------------------------------------------------------"
	Write-Host -ForegroundColor Yellow "Do you want to execute this step? (y/n)"
	$ans = Read-Host

        if($ans -ne "y")
        {
            	Write-Host -ForegroundColor Magenta "skipping trust setup."
            	return
        }

        Trace -text "setting up device trust (adding devices to the cluster and the failover group)..."
        $trust = (get-f5.IControl).ManagementTrust
        $traffic = (get-f5.IControl).ManagementTrafficGroup
        $group = (get-f5.IControl).ManagementDeviceGroup
        $traffic.remove_all_ha_orders("traffic-group-1")
        $group.remove_all_devices("FailoverGroup")
        $trust.add_authority_device($MANAGEMENT_IP[0], "admin", $F5_DEFAULT_ADMIN_PASSWD, $F5_HOSTNAME[0], "", "", "", "")
        $group.add_device(@("FailoverGroup"), @(($F5_HOSTNAME[0])))
        $group.add_device(@("FailoverGroup"), @(($F5_HOSTNAME[1])))
        $order = @(0)
        $order[0] = New-Object iControl.ManagementTrafficGroupHAOrder
        $order[0].device = $F5_HOSTNAME[0]
        $order[0].order = 0
        $traffic.add_ha_order(@("traffic-group-1"), @($order))
        $order[0].device = $F5_HOSTNAME[1]
        $order[0].order = 1
        $traffic.add_ha_order(@("traffic-group-1"), @($order))
        Trace -text "devices added to the cluster. Waiting for the devices to get enabled."
        $device = (get-f5.IControl).ManagementDevice
	$maxWaitSeconds = 120
	$totalWaitSeconds = 0
        
	do
        {
           	Start-Sleep -Seconds 1
		$totalWaitSeconds += 1
            	$state = $device.get_failover_state($F5_HOSTNAME[0])
        }

        while($state -ne [iControl.CommonHAState]::HA_STATE_STANDBY -and
		$state -ne [iControl.CommonHAState]::HA_STATE_ACTIVE -and
		$totalWaitSeconds -lt $maxWaitSeconds)
        	Trace -text "Device #1 failover state is: $state"
		
		if($state -ne [iControl.CommonHAState]::HA_STATE_STANDBY -and
			$state -ne [iControl.CommonHAState]::HA_STATE_ACTIVE)
		{
			TraceError -text "Device #1 failover state is neither HA_STATE_STANDBY nor HA_STATE_ACTIVE."
			TraceError -text "This is not expected. It may be because the Load Balancer Heartbeat network is not configured properly."
			TraceError -text "Please check the Load Balancer Heartbeat network and then restart the script."
			Throw "Device #1 failover state is not the expected one"
		}

        if($state -ne [iControl.CommonHAState]::HA_STATE_ACTIVE)
        {
            	Trace -text "    Making device #1 the ACTIVE device"
            	$failover = (get-f5.IControl).SystemFailover
            	$device = (get-f5.IControl).ManagementDevice
            	$device.get_failover_state($F5_HOSTNAME)
        }
}

function saveconfig.F5
{
        $sync = (get-f5.IControl).SystemConfigSync
        Start-Sleep -Seconds 2
        $sync.save_configuration("", [iControl.SystemConfigSyncSaveMode]::SAVE_BASE_LEVEL_CONFIG)
	$sync.save_configuration("", [iControl.SystemConfigSyncSaveMode]::SAVE_HIGH_LEVEL_CONFIG)
}
	
function sync-F5.Device
{
        param($askForConfirm = $True, $autosync = $True);

        if($askForConfirm -eq $True)
        {
            	Write-Host -ForegroundColor Magenta "------------------------------------------------------------------"
            	Write-Host -ForegroundColor Magenta "About to sync F5 devices."
            	Write-Host -ForegroundColor Magenta "------------------------------------------------------------------"
		Write-Host -ForegroundColor Yellow "Do you want to execute this step? (y/n)"
		$ans = Read-Host

            	if($ans -ne "y")
            	{
                	Write-Host -ForegroundColor Magenta "skipping sync devices."
                	return
            	}
        }

        $group = (get-f5.IControl).ManagementDeviceGroup

        if($autosync -eq $True)
        {
            	Trace -text "Putting failover group in AUTO SYNC mode..."
            	$group.set_autosync_enabled_state("FailoverGroup", [iControl.CommonEnabledState]::STATE_ENABLED)
        }
        else
        {
            	$group.set_autosync_enabled_state("FailoverGroup", [iControl.CommonEnabledState]::STATE_DISABLED)
        }

        Start-Sleep -Seconds 2
        Trace -text "Sync'ing devices in the failover group..."
        saveconfig.F5
        $stat = $group.get_sync_status("FailoverGroup")
        Write-Host ($stat | Format-List | Out-String)
	$sync = (get-f5.IControl).SystemConfigSync
        $sync.synchronize_to_group_v2("FailoverGroup", $F5_HOSTNAME[1], $true)
        $stat = $group.get_sync_status("FailoverGroup")
        Write-Host ($stat | Format-List | Out-String)
        Start-Sleep -Seconds 5
        $stat = $group.get_sync_status("FailoverGroup")
        Write-Host ($stat | Format-List | Out-String)
        Start-Sleep -Seconds 2
        $sync.synchronize_to_group_v2("FailoverGroup", $F5_HOSTNAME[1], $true)
}

function setPasswd-F5.Device
{
        Write-Host -ForegroundColor Magenta "------------------------------------------------------------------"
        Write-Host -ForegroundColor Magenta "About to change F5 devices credentials."
        Write-Host -ForegroundColor Magenta "------------------------------------------------------------------"
	Write-Host -ForegroundColor Yellow "Do you want to execute this step? (y/n)"
	$ans = Read-Host

        if($ans -ne "y")
        {
            	Write-Host -ForegroundColor Magenta "skipping credentials change."
            	return
        }

	Trace -text "Changing F5 devices credentials..."
	setpasswd-F5 -user "root" -passwd $F5_PASSWD_ROOT[1]
	setpasswd-F5 -user "admin" -passwd $F5_PASSWD_ADMIN[1]
        Initialize-F5.iControl -HostName $MANAGEMENT_IP[1] -Username admin -Password $F5_PASSWD_ADMIN[1]
        sync-F5.Device -askForConfirm $False
}

function setup-F5.SNMP
{
	param ([Parameter(Mandatory=$true)] $ipSubnet)

        Trace -text "Setting up SNMP client info..."
        $snmp = (get-f5.IControl).ManagementSNMPConfiguration
        $clientIPs = @("127.")
        $clients = @()

        foreach ($c in $clientIPs)
        {
            $client = New-Object iControl.ManagementSNMPConfigurationClientAccess
            $client.address = $c
            $client.netmask = ""
            $clients += $client
        }

        $ret = get-subnetMask -ipSubnet $ipSubnet
        $client = New-Object iControl.ManagementSNMPConfigurationClientAccess
        $client.address = $ret[0]
        $client.netmask = $ret[1]
        $clients += $client
        $clients
        $snmp.set_client_access($clients);
	Trace -text "Deleting existing SNMP communities ..."
	$communities = $snmp.get_readonly_community()
	$snmp.remove_readonly_community($communities)
        Trace -text "Setting up SNMP ReadOnly communities..."
        $coms = @(0)
        $coms[0] = New-Object iControl.ManagementSNMPConfigurationWrapperSecurityInformation
        $coms[0].community = $SnmpCommunityString
        $coms[0].source = ""
        $coms[0].oid = ""
        $coms[0].ipv6 = $FALSE
        $snmp.set_readonly_community($coms)
        sync-F5.Device -askForConfirm $false
        Trace -text "SNMP config done!"
}

function get-F5.BootVolume
{
	$sm = (Get-F5.iControl).SystemSoftwareManagement

	try
	{
		$volume = $sm.get_boot_location()
	}
	catch
	{
		$volume = $sm.get_cluster_boot_location()
	}	
	return $volume
}
	
function reboot-F5.Volume
{
	param([Parameter(Mandatory=$true)] $f5_ip)

	Trace -text "Checking current boot volume of F5 device: at IP: $f5_ip with user admin and current password $F5_CURRENT_ADMIN_PASSWD"
	Initialize-F5.iControl -HostName $f5_ip -Username admin -Password $F5_CURRENT_ADMIN_PASSWD
	$sm = (Get-F5.iControl).SystemSoftwareManagement
	$volume = get-F5.BootVolume
	$expectedVolume = "HD1.2"
		
	if($volume -eq $expectedVolume)
	{
		Trace -text "Current boot volume of F5 device at IP $f5_ip is $expectedVolume. So skip rebooting."
		return
	}

	Trace -text "Current boot volume of F5 device at IP $f5_ip is $volume."
	Write-Host -ForegroundColor Yellow  "Will reboot this system to volume $expectedVolume. "
	Write-Host -ForegroundColor Yellow "Do you want to execute this step? (y/n)"
	$ans = Read-Host

        if($ans -ne "y")
        {
            	Write-Host -ForegroundColor Magenta "skipping rebooting."
            	return
        }
		
	Start-Process putty.exe -Wait -ArgumentList ("-ssh root@$f5_ip -pw $F5_CURRENT_ROOT_PASSWD -m rebootVolume.txt") -WorkingDirectory $WORKING_DIR
	$sleepTime = 60
	$maxSleepTime = 600
	$totalSleepTime = 0
	$connected = $false
		
	do
	{
		Trace -text "Waiting $sleepTime seconds for the F5 device to reboot ....."
		Start-Sleep -Seconds $sleepTime
		$totalSleepTime += $sleepTime
			
		try
		{
			Initialize-F5.iControl -HostName $f5_ip -Username admin -Password $F5_DEFAULT_ADMIN_PASSWD	
			$connected = $true
			break
		}
		catch
		{
			Trace -text "F5 device is still rebooting ......"
		}
	} while ($totalSleepTime -lt $maxSleepTime)
		
		if($connected -eq $true)
		{
			$volume = get-F5.BootVolume

			if($volume -eq $expectedVolume)
			{
				Trace -text "F5 device at IP $f5_ip is rebooted into expected volume $expectedVolume. "
				return
			}
			else
			{
				TraceError -text "F5 device is booted in volume $volume, which is not the expected one $expectedVolume. Please manually reboot the F5 device to the volume $expectedVolume and restart the script."
				throw "F5 Failed to boot into volume $expectedVolume"
			}
		}
		
		TraceError -text "Still can't connect to F5 device after $totalSleepTime seconds. Please verify the F5 device $f5_ip is rebooted manually and restart the script."
		Throw "Failed to connect to F5 device."
}
	
function setup-F5.Device
{
	param([Parameter(Mandatory=$true)] $index)

	reboot-F5.Volume -f5_ip $F5_DEFAULT_IP[$index]	
	Trace -text "Starting configuring F5 device at IP $($F5_DEFAULT_IP[$index]) with user admin and password $F5_CURRENT_ADMIN_PASSWD"		
	Initialize-F5.iControl -HostName $F5_DEFAULT_IP[$index] -Username admin -Password $F5_CURRENT_ADMIN_PASSWD
	$F5ProductInfo = Get-F5.ProductInformation
	$F5ProductVersion = new-object System.Version($F5ProductInfo.ProductVersion)
	TraceDebug -Text ("F5 product Version detected is " + $F5ProductInfo.ProductVersion)

	if( ($F5ProductVersion.Major -lt 11) -or ($F5ProductVersion.Major -eq 11 -and $F5ProductVersion.Minor -lt 4) ) 
	{ 
		throw "Not Supported F5 Version" 
	}

	activate-F5.licence -index $index
	generate-F5.config -configFilename pppp.scf -index $index
	TraceDebug -Text "Generated the config file"
	apply-F5.configuration -f5_ip $F5_DEFAULT_IP[$index] -configFilename pppp.scf -index $index
	saveconfig.F5
}

function setup-F5.TestConnectivity
{
        param([Parameter(Mandatory=$true)] $hostname)

        if(!(Test-Connection -ComputerName $hostname -Count 1 -Quiet))
        {
            	TraceError -text "Device at $hostname is NOT reachable"
           	 throw "Device at $hostname is NOT reachable"
            	return $false
        }
        return $true
}

function setup-F5.DefaultRoute
{
	Trace -text "Adding default route to F5 device at IP $($MANAGEMENT_IP[1])"		
	$routeAttribute = New-Object iControl.NetworkingRouteTableV2RouteAttribute
	$routeAttribute.pool_name = "/Common/defaultGatewayPool"
	$routeAttribute.gateway = ""
	$routeAttribute.vlan_name = ""
	$routeDestination = New-Object iControl.NetworkingRouteTableV2RouteDestination
	$routeDestination.address = "0.0.0.0"
	$routeDestination.netmask = "0.0.0.0"
	(Get-F5.iControl).NetworkingRouteTableV2.create_static_route(@("defaultRoute"), @($routeDestination), @($routeAttribute))
	saveconfig.F5
	sync-F5.Device -askForConfirm $false
}

function setup-F5.Racks
{
	Write-Host -ForegroundColor Magenta "--------------------------------------------------------------------------------------------"
        Write-Host -ForegroundColor Magenta "About to configure F5 Devices."
        Write-Host -ForegroundColor Magenta "For your convenience, please open a web browser to http://activate.f5.com/license right now."
        Write-Host -ForegroundColor Magenta " "
        Write-Host -ForegroundColor Magenta "--------------------------------------------------------------------------"
        Write-Host -ForegroundColor Magenta "About to configure F5 Device #1"
	Write-Host -ForegroundColor Magenta "Connect the laptop to the first F5 device management port"
	Write-Host -ForegroundColor Yellow "Do you want to execute this step? (y/n)"
	$ans = Read-Host

        if($ans -eq "y")
        {
            	setup-F5.TestConnectivity -hostname $F5_DEFAULT_IP[0]
	    	setup-F5.Device 0
		Write-Host -ForegroundColor Magenta "F5 Device #1 configured!"
        }

        Write-Host -ForegroundColor Magenta "About to configure F5 Device #2"
        Write-Host -ForegroundColor Magenta "Now connect the laptop to the second F5 device management port"
	Write-Host -ForegroundColor Yellow "Do you want to execute this step? (y/n)"
	$ans = Read-Host

        if($ans -eq "y")
        {
		setup-F5.TestConnectivity -hostname $F5_DEFAULT_IP[1]
	        setup-F5.Device 1
		Write-Host -ForegroundColor Magenta "F5 Device #2 configured!"
        }

	Write-Host -ForegroundColor Magenta "Now connect laptop to the BMC Switch (connecting to $($MANAGEMENT_IP[1]))"
        Write-Host -ForegroundColor Yellow "Press Enter when ready"
	Read-Host
	Write-Host -ForegroundColor Magenta "Establishing iControl Connection with F5 device $($MANAGEMENT_IP[1]) using password $F5_DEFAULT_ADMIN_PASSWD"
	Initialize-F5.iControl -HostName $MANAGEMENT_IP[1] -Username admin -Password $F5_DEFAULT_ADMIN_PASSWD
        setup-F5.Trust
        sync-F5.Device
        setup-F5.SNMP -ipSubnet $racknetworks["Infrastructure"].IPV4Subnet  
	setPasswd-F5.Device
	setup-F5.DefaultRoute
}

setup-F5.Racks
