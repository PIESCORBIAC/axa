##############################################################################
# ApplianceConfig_Sample.ps1
# - Example scripts for configuring an HPE OneView appliance (networking, NTP, 
#   etc.).
#
#   VERSION 3.0
#
# (C) Copyright 2013-2020 Hewlett Packard Enterprise Development LP 
##############################################################################
<#
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
#>
##############################################################################

[CmdletBinding()]
param
(

    [Parameter (Mandatory, HelpMessage = "Please provide the Appliances DHCP Address.")]
    [ValidateNotNullorEmpty()]
	[IPAddress]$vm_ipaddr,

	[Parameter (Mandatory, HelpMessage = "Please provide the Appliances NEW Hostname or FQDN.")]
	[String]$Hostname,

	[Parameter (Mandatory, HelpMessage = "Provide a [SecureString] pr [String] object representing the new appliance Administrator password.")]
	[ValidateNotNullorEmpty()]
	[Object]$NewPassword,

	[Parameter (Mandatory, HelpMessage = "Please provide the Appliances NEW Static IPv4 Address.")]
    [ValidateNotNullorEmpty()]
	[IPAddress]$IPv4Address,

	[Parameter (Mandatory, HelpMessage = "Please provide the Appliances NEW IPv4 Subnet.")]
    [ValidateNotNullorEmpty()]
	[String]$IPv4SubnetMask,

	[Parameter (Mandatory, HelpMessage = "Please provide the Appliances NEW IPv4 Default Gateway.")]
    [ValidateNotNullorEmpty()]
	[IPAddress]$IPv4Gateway,

	[Parameter (Mandatory, HelpMessage = "Please provide the Appliances NEW IPv4 DNS Servers.")]
    [ValidateNotNullorEmpty()]
	[Array]$IPv4DnsServers,

	[Parameter (Mandatory, HelpMessage = "Please provide the Appliances NEW DNS Domain Name.")]
    [ValidateNotNullorEmpty()]
	[String]$DnsDomainName,

	[Parameter (Mandatory = $false, HelpMessage = "Please provide the Appliances NEW IPv4 NTP Servers.")]
    [ValidateNotNullorEmpty()]
	[Array]$IPv4NtpServers,

    [Parameter (Mandatory = $False, HelpMessage = "Please provide the Appliances NEW IPv6 Static Address.")]
    [ValidateNotNullorEmpty()]
    [IPAddress]$IPv6Address,

    [Parameter (Mandatory = $False, HelpMessage = "Please provide the Appliances NEW IPv6 Static Address CIDR Subnet Mask.")]
    [ValidateNotNullorEmpty()]
    [Int]$IPv6CidrMask

)

if (-not (get-module HPOneView.410)) 
{

    Import-Module POneView.400

}

#region 

	Write-Host 'Waiting for appliance to respond to network test.' -NoNewline

	While (-not (Test-Connection -ComputerName $vm_ipaddr.IPAddressToString -Quiet))
	{

		Write-Host '.' -NoNewline

	}

	Write-Host ""

	#Core Appliance Setup

    # Accept the EULA
    if (-not (Get-HPOVEulaStatus -Appliance $vm_ipaddr.IPAddressToString).Accepted ) 
	{

        Write-Host "Accepting EULA..."

		Try
		{

			$ret = Set-HPOVEulaStatus -SupportAccess "yes" -Appliance $vm_ipaddr.IPAddressToString

		}

		Catch
		{

			$PSCMdlet.ThrowTerminatingError($_)
		}
        
    }

    # For initial setup, connect first using "default" Administrator credentials:
    Try 
	{ 
		
		Connect-HPOVMgmt -appliance $vm_ipaddr.IPAddressToString -user "Administrator" -password "admin"
	
	}

    catch [HPOneView.Appliance.PasswordChangeRequired] 
	{

        Write-Host "Set initial password"

		Try
		{

			Set-HPOVInitialPassword -OldPassword "admin" -NewPassword $NewPassword -Appliance $vm_ipaddr.IPAddressToString

		}

		Catch
		{

			$PSCMdlet.ThrowTerminatingError($_)

		}
    
    }

	Catch
	{

		$PSCMdlet.ThrowTerminatingError($_)

	}

    Write-Host "Reconnect with new password"

	Try
	{

		$ApplianceConnection = Connect-HPOVMgmt -appliance $vm_ipaddr.IPAddressToString -user Administrator -password $NewPassword

	}
    
	Catch
	{

		$PSCMdlet.ThrowTerminatingError($_)

	}

    Write-Host "Set appliance networking configuration"

    $params = @{

        Hostname        = $Hostname;
        IPv4Addr        = $IPv4Address.IPAddressToString;
        IPv4Subnet      = $IPv4SubnetMask;
        IPv4Gateway     = $IPv4Gateway.IPAddressToString;
        DomainName      = $DnsDomainName;
        IPv4NameServers = $IPv4DnsServers

    }

	if ($IPv6Address)
    {

		$params.Add('IPv6Type','STATIC')
        $params.Add('IPv6Addr', $IPv6Address)
		$params.Add('IPv6Subnet', $IPv6CidrMask)

    }

	Try
	{

		$task = Set-HPOVApplianceNetworkConfig @params

	}
    
	Catch
	{

		$PSCMdlet.ThrowTerminatingError($_)

	}

    if (-not($Global:ConnectedSessions | ? Name -EQ $Hostname)) 
	{ 
	
		Try
		{

			$ApplianceConnection = Connect-HPOVMgmt -appliance $Hostname -user Administrator -password $NewPassword

		}	
		
		Catch
		{

			$PSCMdlet.ThrowTerminatingError($_)

		}
	
	}

	try
	{

		Write-Host 'Setting Appliance NTP Servers'

        $Results = Set-HPOVApplianceDateTime -NtpServers $IPv4NtpServers

	}

	catch
	{

		$PSCmdlet.ThrowTerminatingError($_)

	}

    Write-Host "Completed appliance networking configuration"

    $template = "WebServer" # must always use concatenated name format
    $CA       = "MyCA.domain.local\domain-MyCA-CA"  
	$csrdir   = "C:\Certs\Requests"

    if (-not(Test-Path $csrdir)) 
	{ 
		
		New-Item -Path $csrdir -ItemType directory | Out-Null 
	
	} 

    #Process appliance certificate
    $CSR = @{
        
        Country         = "US";
        State           = "California";
        City            = "Palo Alto";
        Organization    = "Hewlett-Packard";
        CommonName      = $Hostname;
        AlternativeName = "$Hostname,hpov,$IPv4Address"
    
    }

	Try
	{

		$request = New-HPOVApplianceCsr @CSR -ApplianceConnection $ApplianceConnection

	}
    
	Catch
	{

		$PSCMdlet.ThrowTerminatingError($_)

	}

    $baseName    = $Hostname
    $csrFileName = "$Hostname.csr"
    $cerFileName = "$Hostname.cer"

    Set-Content -path (Join-Path $csrdir -ChildPath $csrFileName) -value $request.base64Data -Force

    $csr = Get-ChildItem $csrdir | ? name -eq $csrFileName

    $parameters = "-config {0} -submit -attrib CertificateTemplate:{1} {2}\{3}.csr {2}\{3}.cer {2}\{3}.p7b" -f $CA, $template, $csrdir, $baseName 

    $request = [System.Diagnostics.Process]::Start("certreq", $parameters)
    
    $request.WaitForExit()

    $Task = gc $csrdir\$cerFileName | Install-HPOVApplianceCertificate -ApplianceConnection $ApplianceConnection | Wait-HPOVTaskComplete

    #Configuring appliance LDAP/AD Security
    $dc1 = New-HPOVLdapServer -Name dc1.domain.local
    $dc2 = New-HPOVLdapServer -Name dc2.domain.local

    $AuthParams = @{

        UserName = "ftoomey@domain.local"
        Password = convertto-securestring -asplaintext "HPinv3nt" -force

    }

	Try
	{

		$LdapAuthDirectory = New-HPOVLdapDirectory -Name 'domain.local' -AD -BaseDN 'dc=domain,dc=local' -servers $dc1,$dc2 @AuthParams
		$LdapGroups = $LdapAuthDirectory | Show-HPOVLdapGroups @AuthParams
		$InfrastructureAdminGroup = $LdapGroups | ? Name -match 'CI Manager Full'
		$ServerAdminGroup = $LdapGroups | ? Name -match 'CI Manager Server'
		$StorageAdminGroup = $LdapGroups | ? Name -match 'CI Manager Storage'
		$NetworkAdminGroup = $LdapGroups | ? Name -match 'CI Manager Network'
		New-HPOVLdapGroup -d $LdapAuthDirectory -GroupName $InfrastructureAdminGroup -Roles "Infrastructure administrator" @AuthParams
		New-HPOVLdapGroup -d $LdapAuthDirectory -GroupName $NetworkAdminGroup -Roles "Network administrator"  @AuthParams
		New-HPOVLdapGroup -d $LdapAuthDirectory -GroupName $ServerAdminGroup  -Roles "Server administrator"  @AuthParams
		New-HPOVLdapGroup -d $LdapAuthDirectory -GroupName $StorageAdminGroup -Roles "Storage administrator"  @AuthParams

	}
    
	Catch
	{

		$PSCMdlet.ThrowTerminatingError($_)

	}

	Try
	{

		#Upload custom SPP Baseline
	    gci \\Server\SPP\bp-Default-Baseline-0-1.iso | Add-HPOVBaseline

	}

	Catch
	{

		$PSCMdlet.ThrowTerminatingError($_)

	}

    Try
	{

		write-host "Adding OneView license."
		New-HPOVLicense -License '9CDC D9MA H9P9 KHVY V7B5 HWWB Y9JL KMPL FE2H 5BP4 DXAU 2CSM GHTG L762 EG4Z X3VJ KJVT D5KM EFVW DW5J G4QM M6SW 9K2P 3E82 AJYM LURN TZZP AB6X 82Z5 WHEF D9ED 3RUX BJS2 XFXC T84U R42A 58S5 XA2D WXAP GMTQ 4YLB MM2S CZU7 2E4X E8EW BGB5 BWPD CAAR YT9J 4NUG 2NJN J9UF "424710048 HPOV-NFR1 HP_OneView_16_Seat_NFR 64HTAYJH92EY"_3KB73-R2JV9-V9HS6-LYGTN-6RLYW'

	}

	Catch
	{

		$PSCMdlet.ThrowTerminatingError($_)

	}
    
	# Create the new users
    New-HPOVUser Nat   -fullName "Nat Network Admin"  -password hpinvent -roles "Network administrator"
    New-HPOVUser Sally -fullName "Sally Server Admin" -password hpinvent -roles "Server administrator"
    New-HPOVUser Sandy -fullName "Sandy SAN Admin"    -password hpinvent -roles "Storage administrator"
    New-HPOVUser Rheid -fullName "Rheid Read-Only"	  -password hpinvent -roles "Read only"
    New-HPOVUser Bob   -fullName "Bob Backup"	      -password hpinvent -roles "Backup administrator"
    New-HPOVUser admin -fullName "admin"              -password hpinvent -roles "Infrastructure administrator"

#endregion 

#region 

	#Resource Configuration    

    $params = @{

        hostname  = "172.18.15.1";
        type      = "BNA";
        username  = "administrator";
    	password  = "password";
        UseSsl    = $True

    }
    
    write-host "Importing BNA SAN Manager"

	Try
	{

		Add-HPOVSanManager @params | Wait-HPOVTaskComplete

	}
    
	Catch
	{

		$PSCMdlet.ThrowTerminatingError($_)

	}
    
    Write-Host "Creating network resources"
    
    # Management networks
	Try
	{

		New-HPOVNetwork -Name "VLAN 1-A" -type "Ethernet" -vlanId 1 -smartlink $true -purpose Management
		New-HPOVNetwork -Name "VLAN 1-B" -type "Ethernet" -vlanId 1 -smartlink $true -purpose Management
		
        # Internal Networks
		New-HPOVNetwork -Name "Live Migration" -type "Ethernet" -vlanId 100 -smartlink $true -purpose VMMigration
        New-HPOVNetwork -Name "Heartbeat" -type "Ethernet" -vlanId 101 -smartlink $true -purpose Management
        New-HPOVNetwork -Name "iSCSI Network" -type "Ethernet" -vlanId 3000 -smartlink $true -purpose ISCSI
    
		# VM Networks
		10,20,30,40,50 | % { New-HPOVNetwork -Name "VLAN $_-A" -type "Ethernet" -vlanId $_ -smartlink $true -purpose General }
		10,20,30,40,50 | % { New-HPOVNetwork -Name "VLAN $_-B" -type "Ethernet" -vlanId $_ -smartlink $true -purpose General }
		101,102,103,104,105 | % { New-HPOVNetwork -Name "Dev VLAN $_-A" -type "Ethernet" -vlanId $_ -smartlink $true -purpose General }
		101,102,103,104,105 | % { New-HPOVNetwork -Name "Dev VLAN $_-B" -type "Ethernet" -vlanId $_ -smartlink $true -purpose General }

        #Misc networks
        New-HPOVNetwork -Name "My Vlan 501" -type "Ethernet" -vlanId 3000 -smartlink $true -purpose General
    
		$ProdNetsA = Get-HPOVNetwork -Name "VLAN *0-A" -ErrorAction Stop
		$ProdNetsB = Get-HPOVNetwork -Name "VLAN *0-B" -ErrorAction Stop
		$DevNetsA  = Get-HPOVNetwork -Name "Dev VLAN *-A" -ErrorAction Stop
		$DevNetsB  = Get-HPOVNetwork -Name "Dev VLAN *-B" -ErrorAction Stop
        $InternalNetworks = 'Live Migration','Heartbeat' | % { Get-HPOVNetwork -Name $_ -ErrorAction Stop }
    
		# Create the network sets
		New-HPOVNetworkSet -Name "Prod NetSet1 A" -networks $ProdNetsA -untaggedNetwork $ProdNetsA[0] -typicalBandwidth 2500 -maximumBandwidth 10000 
		New-HPOVNetworkSet -Name "Prod NetSet1 B" -networks $ProdNetsB -untaggedNetwork $ProdNetsB[0] -typicalBandwidth 2500 -maximumBandwidth 10000 
		New-HPOVNetworkSet -Name "Dev Networks A" -networks $DevNetsA  -untaggedNetwork $DevNetsA[0]  -typicalBandwidth 2500 -maximumBandwidth 10000 
		New-HPOVNetworkSet -Name "Dev Networks B" -networks $DevNetsB  -untaggedNetwork $DevNetsB[0]  -typicalBandwidth 2500 -maximumBandwidth 10000 
    
		# Create the FC networks:
		New-HPOVNetwork -Name "Fabric A" -type "FibreChannel" -typicalBandwidth 4000 -autoLoginRedistribution $true -managedSan "SAN1_0"
		New-HPOVNetwork -Name "Fabric B" -type "FibreChannel" -typicalBandwidth 4000 -autoLoginRedistribution $true -managedSan "SAN1_1"
		New-HPOVNetwork -Name "DirectAttach A" -type "FibreChannel" -typicalBandwidth 4000 -autoLoginRedistribution $true -fabricType DirectAttach
		New-HPOVNetwork -Name "DirectAttach B" -type "FibreChannel" -typicalBandwidth 4000 -autoLoginRedistribution $true -fabricType DirectAttach

	}
    
    Catch
	{

		$PSCMdlet.ThrowTerminatingError($_)

	}   
    
	Try
	{

		$LigName = "Default VC FF LIG"
		$Bays = @{ 1 = 'Flex2040f8'; 2 = 'Flex2040f8'}

		$SnmpDest1 = New-HPOVSnmpTrapDestination -Destination mysnmpserver.domain.local -Community MyR3adcommun1ty -SnmpFormat SNMPv1 -TrapSeverities critical,warning
		$SnmpDest2 = New-HPOVSnmpTrapDestination -Destination 10.44.120.9 -Community MyR3adcommun1ty -SnmpFormat SNMPv1 -TrapSeverities critical,warning -VCMTrapCategories legacy -EnetTrapCategories Other,PortStatus,PortThresholds -FCTrapCategories Other,PortStatus
		$SnmpConfig = New-HPOVSnmpConfiguration -ReadCommunity MyR3adC0mmun1ty -AccessList '10.44.120.9/32','172.20.148.0/22' -TrapDestinations $SnmpDest1,$SnmpDest2

		$CreatedLig = New-HPOVLogicalInterconnectGroup -Name $LigName -Bays $Bays -Snmp $SnmpConfig -EnableIgmpSnooping $True -InternalNetworks $InternalNetworks | Wait-HPOVTaskComplete | Get-HPOVLogicalInterconnectGroup

		# Get FC Network Objects
		$FabricA   = Get-HPOVNetwork -Name "Fabric A" -ErrorAction Stop
		$FabricB   = Get-HPOVNetwork -Name "Fabric B" -ErrorAction Stop
		$DAFabricA = Get-HPOVNetwork -Name "DirectAttach A" -ErrorAction Stop
		$DAFabricB = Get-HPOVNetwork -Name "DirectAttach B" -ErrorAction Stop

		# Create Ethernet Uplink Sets
		$CreatedLig = $CreatedLig | New-HPOVUplinkSet -Name "Uplink Set 1" -Type "Ethernet" -Networks $ProdNetsA -nativeEthNetwork $ProdNetsA[0] -UplinkPorts "BAY1:X1","BAY1:X2" -EthMode "Auto" | Wait-HPOVTaskComplete | Get-HPOVLogicalInterconnectGroup -ErrorAction Stop
		$CreatedLig = $CreatedLig | New-HPOVUplinkSet -Name "Uplink Set 2" -Type "Ethernet" -Networks $ProdNetsB -nativeEthNetwork $ProdNetsB[0] -UplinkPorts "BAY2:X1","BAY2:X2" -EthMode "Auto" | Wait-HPOVTaskComplete | Get-HPOVLogicalInterconnectGroup -ErrorAction Stop
    
		# FC Uplink Sets
		$CreatedLig = $CreatedLig | New-HPOVUplinkSet -Name "FC Fabric A" -Type "FibreChannel" -Networks $FabricA   -UplinkPorts "BAY1:X7" | Wait-HPOVTaskComplete | Get-HPOVLogicalInterconnectGroup -ErrorAction Stop
		$CreatedLig = $CreatedLig | New-HPOVUplinkSet -Name "FC Fabric B" -Type "FibreChannel" -Networks $FabricB   -UplinkPorts "BAY2:X7" | Wait-HPOVTaskComplete | Get-HPOVLogicalInterconnectGroup -ErrorAction Stop
		$CreatedLig = $CreatedLig | New-HPOVUplinkSet -Name "DA Fabric A" -Type "FibreChannel" -Networks $DAFabricA -UplinkPorts "BAY1:X3",'BAY1:X4' | Wait-HPOVTaskComplete | Get-HPOVLogicalInterconnectGroup -ErrorAction Stop
		$CreatedLig = $CreatedLig | New-HPOVUplinkSet -Name "DA Fabric B" -Type "FibreChannel" -Networks $DAFabricB -UplinkPorts "BAY2:X3",'BAY2:X4' | Wait-HPOVTaskComplete | Get-HPOVLogicalInterconnectGroup -ErrorAction Stop

	}

	Catch
	{

		$PSCMdlet.ParameterSetName

		$PSCMdlet.ThrowTerminatingError($_)

	}
	
	Try
	{

		$EGParams = @{

			Name                     = "Default EG 1"
			LogicalInterConnectGroup = $CreatedLig
			ConfigurationScript      = 'ADD USER "admin" "Supersecretpassword"
SET USER CONTACT "admin" ""
SET USER FULLNAME "admin" ""
SET USER ACCESS "admin" ADMINISTRATOR
ASSIGN SERVER 1-16 "admin"
ASSIGN INTERCONNECT 1-8 "admin"
ASSIGN OA "admin"
ENABLE USER "admin"
hponcfg all >> end_marker
<RIBCL VERSION="2.0">
   <LOGIN USER_LOGIN="admin" PASSWORD="passthrough">
      <USER_INFO MODE="write">
         <ADD_USER
           USER_NAME="admin"
           USER_LOGIN="admin"
           PASSWORD="Supersecretpassword">
            <ADMIN_PRIV value ="N"/>
            <REMOTE_CONS_PRIV value ="Y"/>
            <RESET_SERVER_PRIV value ="N"/>
            <VIRTUAL_MEDIA_PRIV value ="N"/>            
            <CONFIG_ILO_PRIV value="Yes"/>
         </ADD_USER>
      </USER_INFO>
   </LOGIN>
</RIBCL>
end_marker'
		}

		$EnclosureGroup = New-HPOVEnclosureGroup @EGParams

	}

	Catch
	{

		$PSCMdlet.ThrowTerminatingError($_)

	}
    
    Write-host "Sleeping 30 seconds"
    start-sleep -Seconds 30

    $params = @{
    
        username  = "3paradm";
        password  = "3pardata";
        hostname  = "172.18.11.11";
        domain    = "NO DOMAIN"
    
    }
    
    Write-Host "Importing storage array: $($params.hostname)"
	Try
	{

		$Results = Add-HPOVStorageSystem @params | Wait-HPOVTaskComplete

        $Results = Get-HPOVStorageSystem -ErrorAction Stop | Add-HPOVStoragePool -Pool 'FST_CPG1','FST_CPG2' | Wait-HPOVTaskComplete

		$StorageVolume = Get-HPOVStoragePool -Pool 'FST_CPG1' -ErrorAction Stop | New-HPOVStorageVolume -Name 'DO NOT DELETE' -Capacity 1

	}

	Catch
	{

		$PSCMdlet.ThrowTerminatingError($_)

	}

    #Add Encl1
    Try
    {

        $EnclosureAddParams = @{

            Hostname       = '172.18.1.11';
            Username       = 'administrator';
            Password       = 'password';
            EnclosureGroup = $EnclosureGroup

        }

		$Results = Add-HPOVEnclosure @EnclosureAddParams

    }

    Catch
    {

        $PSCMdlet.ThrowTerminatingError($_)

    }

    Disconnect-HPOVMgmt

	Remove-Module HPOneView.410

#endregion
# SIG # Begin signature block
# MIIjGQYJKoZIhvcNAQcCoIIjCjCCIwYCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCQqvmc2IF1DzWi
# wN4Mke5xAmDwyl63CG2AL+QXXvid56CCHiIwggVhMIIESaADAgECAhB2TE55PkNI
# O10XEYNqkr0BMA0GCSqGSIb3DQEBCwUAMHwxCzAJBgNVBAYTAkdCMRswGQYDVQQI
# ExJHcmVhdGVyIE1hbmNoZXN0ZXIxEDAOBgNVBAcTB1NhbGZvcmQxGDAWBgNVBAoT
# D1NlY3RpZ28gTGltaXRlZDEkMCIGA1UEAxMbU2VjdGlnbyBSU0EgQ29kZSBTaWdu
# aW5nIENBMB4XDTIwMDEyOTAwMDAwMFoXDTIxMDEyODIzNTk1OVowgdIxCzAJBgNV
# BAYTAlVTMQ4wDAYDVQQRDAU5NDMwNDELMAkGA1UECAwCQ0ExEjAQBgNVBAcMCVBh
# bG8gQWx0bzEcMBoGA1UECQwTMzAwMCBIYW5vdmVyIFN0cmVldDErMCkGA1UECgwi
# SGV3bGV0dCBQYWNrYXJkIEVudGVycHJpc2UgQ29tcGFueTEaMBgGA1UECwwRSFAg
# Q3liZXIgU2VjdXJpdHkxKzApBgNVBAMMIkhld2xldHQgUGFja2FyZCBFbnRlcnBy
# aXNlIENvbXBhbnkwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCvRDPh
# KKeABVHX3uR8gbgwJRObEp72PUbtdRaTIiZfmgrd6zGNv4Jm/Y7NaAbJU4zqBVgE
# jxheJu7zMlsqOwCtPmocdi9MNIbY/pkFJ7DxM3kLejDGB1u0cHaDUL0EiyzDTzIC
# 7XtsIGw/BOLrRjqKsDGRNytiaNSt//acldDLq2z1CZmAYMQfkvJ0yjGARFTGb2Ti
# tXrIu7nXjU8KrBrEyyUVDPS8w3MMhTq+ot/XjCl9TF0akN4foJm5AVS9ByKSpiae
# RUY94wRMMiBBkbmZ2tLUs3Dq1u4eOyGXCBRgnOdymrn13JTTV4FOcWh7VisEG68x
# 2BSyrS/HGsDCYQYbAgMBAAGjggGGMIIBgjAfBgNVHSMEGDAWgBQO4TqoUzox1Yq+
# wbutZxoDha00DjAdBgNVHQ4EFgQUh4Yh6Id9YrSze2lDYQHnUSpKqUYwDgYDVR0P
# AQH/BAQDAgeAMAwGA1UdEwEB/wQCMAAwEwYDVR0lBAwwCgYIKwYBBQUHAwMwEQYJ
# YIZIAYb4QgEBBAQDAgQQMEAGA1UdIAQ5MDcwNQYMKwYBBAGyMQECAQMCMCUwIwYI
# KwYBBQUHAgEWF2h0dHBzOi8vc2VjdGlnby5jb20vQ1BTMEMGA1UdHwQ8MDowOKA2
# oDSGMmh0dHA6Ly9jcmwuc2VjdGlnby5jb20vU2VjdGlnb1JTQUNvZGVTaWduaW5n
# Q0EuY3JsMHMGCCsGAQUFBwEBBGcwZTA+BggrBgEFBQcwAoYyaHR0cDovL2NydC5z
# ZWN0aWdvLmNvbS9TZWN0aWdvUlNBQ29kZVNpZ25pbmdDQS5jcnQwIwYIKwYBBQUH
# MAGGF2h0dHA6Ly9vY3NwLnNlY3RpZ28uY29tMA0GCSqGSIb3DQEBCwUAA4IBAQAv
# 2YEjwnu/UrMtMhKcSzUuwDgDoMyK8X40qdzOHED1jq1o7AUkz3fVI1BvT6xQdfRU
# yk1v+EkfM3LXsgc+U3sXt0U0BuDWyXfa1LgcU3DGnDk26R1EZyGQ4/rtrIh6nf/p
# JMmd+Exowu1qvObVgJi6miAXS58T4Pq5Pptn7E4t2gwXfkSdNVgwiSYZEAo/nlj5
# W3SgUF7FsBRpQH9fvQFvRjXeKFYjYiXCnOQd2rmwtKj51++Fmpn+5bqUoeltHrSG
# Wqw8ACgj1ZsC0QfxoIT6Cu29N3Kf/Odgk/Gm0f5zVdPUGGUFpPbRaT8OyMF8hx9G
# sN6uUOLceuLXLZq6CIJmMIIFgTCCBGmgAwIBAgIQOXJEOvkit1HX02wQ3TE1lTAN
# BgkqhkiG9w0BAQwFADB7MQswCQYDVQQGEwJHQjEbMBkGA1UECAwSR3JlYXRlciBN
# YW5jaGVzdGVyMRAwDgYDVQQHDAdTYWxmb3JkMRowGAYDVQQKDBFDb21vZG8gQ0Eg
# TGltaXRlZDEhMB8GA1UEAwwYQUFBIENlcnRpZmljYXRlIFNlcnZpY2VzMB4XDTE5
# MDMxMjAwMDAwMFoXDTI4MTIzMTIzNTk1OVowgYgxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpOZXcgSmVyc2V5MRQwEgYDVQQHEwtKZXJzZXkgQ2l0eTEeMBwGA1UEChMV
# VGhlIFVTRVJUUlVTVCBOZXR3b3JrMS4wLAYDVQQDEyVVU0VSVHJ1c3QgUlNBIENl
# cnRpZmljYXRpb24gQXV0aG9yaXR5MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIIC
# CgKCAgEAgBJlFzYOw9sIs9CsVw127c0n00ytUINh4qogTQktZAnczomfzD2p7PbP
# wdzx07HWezcoEStH2jnGvDoZtF+mvX2do2NCtnbyqTsrkfjib9DsFiCQCT7i6HTJ
# GLSR1GJk23+jBvGIGGqQIjy8/hPwhxR79uQfjtTkUcYRZ0YIUcuGFFQ/vDP+fmyc
# /xadGL1RjjWmp2bIcmfbIWax1Jt4A8BQOujM8Ny8nkz+rwWWNR9XWrf/zvk9tyy2
# 9lTdyOcSOk2uTIq3XJq0tyA9yn8iNK5+O2hmAUTnAU5GU5szYPeUvlM3kHND8zLD
# U+/bqv50TmnHa4xgk97Exwzf4TKuzJM7UXiVZ4vuPVb+DNBpDxsP8yUmazNt925H
# +nND5X4OpWaxKXwyhGNVicQNwZNUMBkTrNN9N6frXTpsNVzbQdcS2qlJC9/YgIoJ
# k2KOtWbPJYjNhLixP6Q5D9kCnusSTJV882sFqV4Wg8y4Z+LoE53MW4LTTLPtW//e
# 5XOsIzstAL81VXQJSdhJWBp/kjbmUZIO8yZ9HE0XvMnsQybQv0FfQKlERPSZ51eH
# nlAfV1SoPv10Yy+xUGUJ5lhCLkMaTLTwJUdZ+gQek9QmRkpQgbLevni3/GcV4clX
# hB4PY9bpYrrWX1Uu6lzGKAgEJTm4Diup8kyXHAc/DVL17e8vgg8CAwEAAaOB8jCB
# 7zAfBgNVHSMEGDAWgBSgEQojPpbxB+zirynvgqV/0DCktDAdBgNVHQ4EFgQUU3m/
# WqorSs9UgOHYm8Cd8rIDZsswDgYDVR0PAQH/BAQDAgGGMA8GA1UdEwEB/wQFMAMB
# Af8wEQYDVR0gBAowCDAGBgRVHSAAMEMGA1UdHwQ8MDowOKA2oDSGMmh0dHA6Ly9j
# cmwuY29tb2RvY2EuY29tL0FBQUNlcnRpZmljYXRlU2VydmljZXMuY3JsMDQGCCsG
# AQUFBwEBBCgwJjAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuY29tb2RvY2EuY29t
# MA0GCSqGSIb3DQEBDAUAA4IBAQAYh1HcdCE9nIrgJ7cz0C7M7PDmy14R3iJvm3WO
# nnL+5Nb+qh+cli3vA0p+rvSNb3I8QzvAP+u431yqqcau8vzY7qN7Q/aGNnwU4M30
# 9z/+3ri0ivCRlv79Q2R+/czSAaF9ffgZGclCKxO/WIu6pKJmBHaIkU4MiRTOok3J
# MrO66BQavHHxW/BBC5gACiIDEOUMsfnNkjcZ7Tvx5Dq2+UUTJnWvu6rvP3t3O9LE
# ApE9GQDTF1w52z97GA1FzZOFli9d31kWTz9RvdVFGD/tSo7oBmF0Ixa1DVBzJ0RH
# fxBdiSprhTEUxOipakyAvGp4z7h/jnZymQyd/teRCBaho1+VMIIF9TCCA92gAwIB
# AgIQHaJIMG+bJhjQguCWfTPTajANBgkqhkiG9w0BAQwFADCBiDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCk5ldyBKZXJzZXkxFDASBgNVBAcTC0plcnNleSBDaXR5MR4w
# HAYDVQQKExVUaGUgVVNFUlRSVVNUIE5ldHdvcmsxLjAsBgNVBAMTJVVTRVJUcnVz
# dCBSU0EgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkwHhcNMTgxMTAyMDAwMDAwWhcN
# MzAxMjMxMjM1OTU5WjB8MQswCQYDVQQGEwJHQjEbMBkGA1UECBMSR3JlYXRlciBN
# YW5jaGVzdGVyMRAwDgYDVQQHEwdTYWxmb3JkMRgwFgYDVQQKEw9TZWN0aWdvIExp
# bWl0ZWQxJDAiBgNVBAMTG1NlY3RpZ28gUlNBIENvZGUgU2lnbmluZyBDQTCCASIw
# DQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAIYijTKFehifSfCWL2MIHi3cfJ8U
# z+MmtiVmKUCGVEZ0MWLFEO2yhyemmcuVMMBW9aR1xqkOUGKlUZEQauBLYq798PgY
# rKf/7i4zIPoMGYmobHutAMNhodxpZW0fbieW15dRhqb0J+V8aouVHltg1X7XFpKc
# AC9o95ftanK+ODtj3o+/bkxBXRIgCFnoOc2P0tbPBrRXBbZOoT5Xax+YvMRi1hsL
# jcdmG0qfnYHEckC14l/vC0X/o84Xpi1VsLewvFRqnbyNVlPG8Lp5UEks9wO5/i9l
# NfIi6iwHr0bZ+UYc3Ix8cSjz/qfGFN1VkW6KEQ3fBiSVfQ+noXw62oY1YdMCAwEA
# AaOCAWQwggFgMB8GA1UdIwQYMBaAFFN5v1qqK0rPVIDh2JvAnfKyA2bLMB0GA1Ud
# DgQWBBQO4TqoUzox1Yq+wbutZxoDha00DjAOBgNVHQ8BAf8EBAMCAYYwEgYDVR0T
# AQH/BAgwBgEB/wIBADAdBgNVHSUEFjAUBggrBgEFBQcDAwYIKwYBBQUHAwgwEQYD
# VR0gBAowCDAGBgRVHSAAMFAGA1UdHwRJMEcwRaBDoEGGP2h0dHA6Ly9jcmwudXNl
# cnRydXN0LmNvbS9VU0VSVHJ1c3RSU0FDZXJ0aWZpY2F0aW9uQXV0aG9yaXR5LmNy
# bDB2BggrBgEFBQcBAQRqMGgwPwYIKwYBBQUHMAKGM2h0dHA6Ly9jcnQudXNlcnRy
# dXN0LmNvbS9VU0VSVHJ1c3RSU0FBZGRUcnVzdENBLmNydDAlBggrBgEFBQcwAYYZ
# aHR0cDovL29jc3AudXNlcnRydXN0LmNvbTANBgkqhkiG9w0BAQwFAAOCAgEATWNQ
# 7Uc0SmGk295qKoyb8QAAHh1iezrXMsL2s+Bjs/thAIiaG20QBwRPvrjqiXgi6w9G
# 7PNGXkBGiRL0C3danCpBOvzW9Ovn9xWVM8Ohgyi33i/klPeFM4MtSkBIv5rCT0qx
# jyT0s4E307dksKYjalloUkJf/wTr4XRleQj1qZPea3FAmZa6ePG5yOLDCBaxq2Na
# yBWAbXReSnV+pbjDbLXP30p5h1zHQE1jNfYw08+1Cg4LBH+gS667o6XQhACTPlNd
# NKUANWlsvp8gJRANGftQkGG+OY96jk32nw4e/gdREmaDJhlIlc5KycF/8zoFm/lv
# 34h/wCOe0h5DekUxwZxNqfBZslkZ6GqNKQQCd3xLS81wvjqyVVp4Pry7bwMQJXcV
# NIr5NsxDkuS6T/FikyglVyn7URnHoSVAaoRXxrKdsbwcCtp8Z359LukoTBh+xHsx
# QXGaSynsCz1XUNLK3f2eBVHlRHjdAd6xdZgNVCT98E7j4viDvXK6yz067vBeF5Jo
# bchh+abxKgoLpbn0nu6YMgWFnuv5gynTxix9vTp3Los3QqBqgu07SqqUEKThDfgX
# xbZaeTMYkuO1dfih6Y4KJR7kHvGfWocj/5+kUZ77OYARzdu1xKeogG/lU9Tg46LC
# 0lsa+jImLWpXcBw8pFguo/NbSwfcMlnzh6cabVgwggZqMIIFUqADAgECAhADAZoC
# Ov9YsWvW1ermF/BmMA0GCSqGSIb3DQEBBQUAMGIxCzAJBgNVBAYTAlVTMRUwEwYD
# VQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAf
# BgNVBAMTGERpZ2lDZXJ0IEFzc3VyZWQgSUQgQ0EtMTAeFw0xNDEwMjIwMDAwMDBa
# Fw0yNDEwMjIwMDAwMDBaMEcxCzAJBgNVBAYTAlVTMREwDwYDVQQKEwhEaWdpQ2Vy
# dDElMCMGA1UEAxMcRGlnaUNlcnQgVGltZXN0YW1wIFJlc3BvbmRlcjCCASIwDQYJ
# KoZIhvcNAQEBBQADggEPADCCAQoCggEBAKNkXfx8s+CCNeDg9sYq5kl1O8xu4FOp
# nx9kWeZ8a39rjJ1V+JLjntVaY1sCSVDZg85vZu7dy4XpX6X51Id0iEQ7Gcnl9ZGf
# xhQ5rCTqqEsskYnMXij0ZLZQt/USs3OWCmejvmGfrvP9Enh1DqZbFP1FI46GRFV9
# GIYFjFWHeUhG98oOjafeTl/iqLYtWQJhiGFyGGi5uHzu5uc0LzF3gTAfuzYBje8n
# 4/ea8EwxZI3j6/oZh6h+z+yMDDZbesF6uHjHyQYuRhDIjegEYNu8c3T6Ttj+qkDx
# ss5wRoPp2kChWTrZFQlXmVYwk/PJYczQCMxr7GJCkawCwO+k8IkRj3cCAwEAAaOC
# AzUwggMxMA4GA1UdDwEB/wQEAwIHgDAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB/wQM
# MAoGCCsGAQUFBwMIMIIBvwYDVR0gBIIBtjCCAbIwggGhBglghkgBhv1sBwEwggGS
# MCgGCCsGAQUFBwIBFhxodHRwczovL3d3dy5kaWdpY2VydC5jb20vQ1BTMIIBZAYI
# KwYBBQUHAgIwggFWHoIBUgBBAG4AeQAgAHUAcwBlACAAbwBmACAAdABoAGkAcwAg
# AEMAZQByAHQAaQBmAGkAYwBhAHQAZQAgAGMAbwBuAHMAdABpAHQAdQB0AGUAcwAg
# AGEAYwBjAGUAcAB0AGEAbgBjAGUAIABvAGYAIAB0AGgAZQAgAEQAaQBnAGkAQwBl
# AHIAdAAgAEMAUAAvAEMAUABTACAAYQBuAGQAIAB0AGgAZQAgAFIAZQBsAHkAaQBu
# AGcAIABQAGEAcgB0AHkAIABBAGcAcgBlAGUAbQBlAG4AdAAgAHcAaABpAGMAaAAg
# AGwAaQBtAGkAdAAgAGwAaQBhAGIAaQBsAGkAdAB5ACAAYQBuAGQAIABhAHIAZQAg
# AGkAbgBjAG8AcgBwAG8AcgBhAHQAZQBkACAAaABlAHIAZQBpAG4AIABiAHkAIABy
# AGUAZgBlAHIAZQBuAGMAZQAuMAsGCWCGSAGG/WwDFTAfBgNVHSMEGDAWgBQVABIr
# E5iymQftHt+ivlcNK2cCzTAdBgNVHQ4EFgQUYVpNJLZJMp1KKnkag0v0HonByn0w
# fQYDVR0fBHYwdDA4oDagNIYyaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lD
# ZXJ0QXNzdXJlZElEQ0EtMS5jcmwwOKA2oDSGMmh0dHA6Ly9jcmw0LmRpZ2ljZXJ0
# LmNvbS9EaWdpQ2VydEFzc3VyZWRJRENBLTEuY3JsMHcGCCsGAQUFBwEBBGswaTAk
# BggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEEGCCsGAQUFBzAC
# hjVodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURD
# QS0xLmNydDANBgkqhkiG9w0BAQUFAAOCAQEAnSV+GzNNsiaBXJuGziMgD4CH5Yj/
# /7HUaiwx7ToXGXEXzakbvFoWOQCd42yE5FpA+94GAYw3+puxnSR+/iCkV61bt5qw
# YCbqaVchXTQvH3Gwg5QZBWs1kBCge5fH9j/n4hFBpr1i2fAnPTgdKG86Ugnw7HBi
# 02JLsOBzppLA044x2C/jbRcTBu7kA7YUq/OPQ6dxnSHdFMoVXZJB2vkPgdGZdA0m
# xA5/G7X1oPHGdwYoFenYk+VVFvC7Cqsc21xIJ2bIo4sKHOWV2q7ELlmgYd3a822i
# YemKC23sEhi991VUQAOSK2vCUcIKSK+w1G7g9BQKOhvjjz3Kr2qNe9zYRDCCBs0w
# ggW1oAMCAQICEAb9+QOWA63qAArrPye7uhswDQYJKoZIhvcNAQEFBQAwZTELMAkG
# A1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRp
# Z2ljZXJ0LmNvbTEkMCIGA1UEAxMbRGlnaUNlcnQgQXNzdXJlZCBJRCBSb290IENB
# MB4XDTA2MTExMDAwMDAwMFoXDTIxMTExMDAwMDAwMFowYjELMAkGA1UEBhMCVVMx
# FTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNv
# bTEhMB8GA1UEAxMYRGlnaUNlcnQgQXNzdXJlZCBJRCBDQS0xMIIBIjANBgkqhkiG
# 9w0BAQEFAAOCAQ8AMIIBCgKCAQEA6IItmfnKwkKVpYBzQHDSnlZUXKnE0kEGj8kz
# /E1FkVyBn+0snPgWWd+etSQVwpi5tHdJ3InECtqvy15r7a2wcTHrzzpADEZNk+yL
# ejYIA6sMNP4YSYL+x8cxSIB8HqIPkg5QycaH6zY/2DDD/6b3+6LNb3Mj/qxWBZDw
# MiEWicZwiPkFl32jx0PdAug7Pe2xQaPtP77blUjE7h6z8rwMK5nQxl0SQoHhg26C
# cz8mSxSQrllmCsSNvtLOBq6thG9IhJtPQLnxTPKvmPv2zkBdXPao8S+v7Iki8msY
# ZbHBc63X8djPHgp0XEK4aH631XcKJ1Z8D2KkPzIUYJX9BwSiCQIDAQABo4IDejCC
# A3YwDgYDVR0PAQH/BAQDAgGGMDsGA1UdJQQ0MDIGCCsGAQUFBwMBBggrBgEFBQcD
# AgYIKwYBBQUHAwMGCCsGAQUFBwMEBggrBgEFBQcDCDCCAdIGA1UdIASCAckwggHF
# MIIBtAYKYIZIAYb9bAABBDCCAaQwOgYIKwYBBQUHAgEWLmh0dHA6Ly93d3cuZGln
# aWNlcnQuY29tL3NzbC1jcHMtcmVwb3NpdG9yeS5odG0wggFkBggrBgEFBQcCAjCC
# AVYeggFSAEEAbgB5ACAAdQBzAGUAIABvAGYAIAB0AGgAaQBzACAAQwBlAHIAdABp
# AGYAaQBjAGEAdABlACAAYwBvAG4AcwB0AGkAdAB1AHQAZQBzACAAYQBjAGMAZQBw
# AHQAYQBuAGMAZQAgAG8AZgAgAHQAaABlACAARABpAGcAaQBDAGUAcgB0ACAAQwBQ
# AC8AQwBQAFMAIABhAG4AZAAgAHQAaABlACAAUgBlAGwAeQBpAG4AZwAgAFAAYQBy
# AHQAeQAgAEEAZwByAGUAZQBtAGUAbgB0ACAAdwBoAGkAYwBoACAAbABpAG0AaQB0
# ACAAbABpAGEAYgBpAGwAaQB0AHkAIABhAG4AZAAgAGEAcgBlACAAaQBuAGMAbwBy
# AHAAbwByAGEAdABlAGQAIABoAGUAcgBlAGkAbgAgAGIAeQAgAHIAZQBmAGUAcgBl
# AG4AYwBlAC4wCwYJYIZIAYb9bAMVMBIGA1UdEwEB/wQIMAYBAf8CAQAweQYIKwYB
# BQUHAQEEbTBrMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20w
# QwYIKwYBBQUHMAKGN2h0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2Vy
# dEFzc3VyZWRJRFJvb3RDQS5jcnQwgYEGA1UdHwR6MHgwOqA4oDaGNGh0dHA6Ly9j
# cmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwOqA4
# oDaGNGh0dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJv
# b3RDQS5jcmwwHQYDVR0OBBYEFBUAEisTmLKZB+0e36K+Vw0rZwLNMB8GA1UdIwQY
# MBaAFEXroq/0ksuCMS1Ri6enIZ3zbcgPMA0GCSqGSIb3DQEBBQUAA4IBAQBGUD7J
# tygkpzgdtlspr1LPUukxR6tWXHvVDQtBs+/sdR90OPKyXGGinJXDUOSCuSPRujqG
# cq04eKx1XRcXNHJHhZRW0eu7NoR3zCSl8wQZVann4+erYs37iy2QwsDStZS9Xk+x
# BdIOPRqpFFumhjFiqKgz5Js5p8T1zh14dpQlc+Qqq8+cdkvtX8JLFuRLcEwAiR78
# xXm8TBJX/l/hHrwCXaj++wc4Tw3GXZG5D2dFzdaD7eeSDY2xaYxP+1ngIw/Sqq4A
# fO6cQg7PkdcntxbuD8O9fAqg7iwIVYUiuOsYGk38KiGtSTGDR5V3cdyxG0tLHBCc
# dxTBnU8vWpUIKRAmMYIETTCCBEkCAQEwgZAwfDELMAkGA1UEBhMCR0IxGzAZBgNV
# BAgTEkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UEBxMHU2FsZm9yZDEYMBYGA1UE
# ChMPU2VjdGlnbyBMaW1pdGVkMSQwIgYDVQQDExtTZWN0aWdvIFJTQSBDb2RlIFNp
# Z25pbmcgQ0ECEHZMTnk+Q0g7XRcRg2qSvQEwDQYJYIZIAWUDBAIBBQCgfDAQBgor
# BgEEAYI3AgEMMQIwADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEE
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgWEou+Bs3yQ+3
# m8Yiah+QJNqeQf9nSvUuhb5aO9F+I3EwDQYJKoZIhvcNAQEBBQAEggEADHZv9IN3
# tuzIGkFuGLfbNqWXYwJJ4JISPU/clAkebvSYWo7eenzAkzzmUMjRXEztfF9po3uk
# nxVCFQ9TsEzmq9ip7Qh1t8HHwlRKL9odfEIEQU+287VxwHXKD/+zib/8s7GiKISz
# ZsYQNiCYOG5JcEsJrzQuu3UgievynWMRyS+49C1HNo3qLY+h7y+brr/pfA0WGnrj
# mob3v+FvWvKbAhw8qi+umpIIOwEzj5opyWk8pe4C1JGr+mWyPHtAF4HQq6Ea/6tJ
# W2CKb3u+VTnNE5W05mm6w9LGn2aWhs3n7HUueTzMstdJIApbaLcc4YoD6qSknwlW
# t+gc6PxryemXWKGCAg8wggILBgkqhkiG9w0BCQYxggH8MIIB+AIBATB2MGIxCzAJ
# BgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5k
# aWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0IEFzc3VyZWQgSUQgQ0EtMQIQ
# AwGaAjr/WLFr1tXq5hfwZjAJBgUrDgMCGgUAoF0wGAYJKoZIhvcNAQkDMQsGCSqG
# SIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMjAwNjE5MjM0NzQ0WjAjBgkqhkiG9w0B
# CQQxFgQUkgRxtH6w2dxAFbga+5C+o01RRcIwDQYJKoZIhvcNAQEBBQAEggEAlk5L
# r8bJGaCIpDfUrimCK4NkwqL7vU7SeXzPNqnRrB5qlbJePq17DxjIzIIZFXotTa0n
# kqz1/gomh61ykGookfoJMIs337MZYXGLQBM9XvQSQAlDTAdOGiSfj0RdhtiSpHaf
# bl1XvUy6L83AGunknlPPnJOTwk2dhvHjvPR5mhqcyIu5fKBEgMxdUOyL5jRIpyuG
# VzYqPMbmQANazhrbK9egvCCg64vjQNCgUFu70VyBTokv+K9QjjGQCleij/hM69F4
# VOXBfXd0N8br1aSu8XdbcIxi3Nlh1wbtF+FpYr5ABDoe/5lPvZM4aKXaS8ujECiC
# paWi+domrjHEXrY9rg==
# SIG # End signature block
