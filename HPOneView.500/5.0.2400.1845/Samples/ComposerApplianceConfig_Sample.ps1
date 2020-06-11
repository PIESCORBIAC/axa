##############################################################################
# ComposerApplianceConfig_Sample.ps1
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

    [Parameter (Mandatory, HelpMessage = "Provide the Appliances DHCP Address.")]
	[Alias('vm_ipaddr')]
    [ValidateNotNullorEmpty()]
	[IPAddress]$DhcpAddress,

	[Parameter (Mandatory, HelpMessage = "Provide the Appliances NEW Hostname or FQDN.")]
	[String]$Hostname,

	[Parameter (Mandatory, HelpMessage = "Provide a [SecureString] pr [String] object representing the new appliance Administrator password.")]
	[ValidateNotNullorEmpty()]
	[Object]$NewPassword,

	[Parameter (Mandatory, HelpMessage = "Provide the Composer Primary Virtual IP.")]
    [ValidateNotNullorEmpty()]
	[IPAddress]$IPv4Address,

	[Parameter (Mandatory, HelpMessage = "Provide the Appliances NEW IPv4 Subnet.")]
    [ValidateNotNullorEmpty()]
	[String]$IPv4SubnetMask,

	[Parameter (Mandatory, HelpMessage = "Provide the Appliances NEW IPv4 Default Gateway.")]
    [ValidateNotNullorEmpty()]
	[IPAddress]$IPv4Gateway,

	[Parameter (Mandatory, HelpMessage = "Provide the Appliances NEW IPv4 DNS Servers.")]
    [ValidateNotNullorEmpty()]
	[Array]$IPv4DnsServers,

	[Parameter (Mandatory, HelpMessage = "Provide the Appliances NEW DNS Domain Name.")]
    [ValidateNotNullorEmpty()]
	[String]$DnsDomainName,

    [Parameter (Mandatory, HelpMessage = "Provide the Appliances NEW DNS Domain Name.")]
    [ValidateNotNullorEmpty()]
    [IPAddress]$ServiceIPv4Node1,

    [Parameter (Mandatory, HelpMessage = "Provide the Appliances NEW DNS Domain Name.")]
    [ValidateNotNullorEmpty()]
    [IPAddress]$ServiceIPv4Node2,

	[Parameter (Mandatory = $false, HelpMessage = "Provide the Appliances NEW IPv4 NTP Servers.")]
    [ValidateNotNullorEmpty()]
	[Array]$IPv4NtpServers,

    [Parameter (Mandatory = $False, HelpMessage = "Provide the Appliances NEW IPv6 Static Address.")]
    [ValidateNotNullorEmpty()]
    [IPAddress]$IPv6Address,

    [Parameter (Mandatory = $False, HelpMessage = "Provide the Appliances NEW IPv6 Static Address.")]
    [ValidateNotNullorEmpty()]
    [Int]$IPv6CidrMask,

    [Parameter (Mandatory = $False, HelpMessage = "Provide the Service IP for Node 1 NEW IPv6 Static Address.")]
    [ValidateNotNullorEmpty()]
    [IPAddress]$ServiceIPv6Node1,

    [Parameter (Mandatory = $False, HelpMessage = "Provide the Service IP for Node 2 NEW IPv6 Static Address.")]
    [ValidateNotNullorEmpty()]
    [IPAddress]$ServiceIPv6Node2

)

if (-not (Get-Module HPOneView.410)) 
{

    Import-Module POSH-HPOneView.410

}

#region 

	Write-Host 'Waiting for appliance to respond to network test.' -NoNewline

	While (-not (Test-Connection -ComputerName $DhcpAddress.IPAddressToString -Quiet))
	{

		Write-Host '.' -NoNewline

	}

	Write-Host ""

	#Core Appliance Setup

    # Accept the EULA
    if (-not (Get-HPOVEulaStatus -Appliance $DhcpAddress.IPAddressToString).Accepted ) 
	{

        Write-Host "Accepting EULA..."

		Try
		{

			$ret = Set-HPOVEulaStatus -SupportAccess "yes" -Appliance $DhcpAddress.IPAddressToString

		}

		Catch
		{

			$PSCMdlet.ThrowTerminatingError($_)
		}
        
    }

    # For initial setup, connect first using "default" Administrator credentials:
    Try 
	{ 
		
		Connect-HPOVMgmt -appliance $DhcpAddress.IPAddressToString -user "Administrator" -password "admin"
	
	}

    catch [HPOneView.Appliance.PasswordChangeRequired] 
	{

        Write-Host "Set initial password"

		Try
		{

			Set-HPOVInitialPassword -OldPassword "admin" -NewPassword $NewPassword -Appliance $DhcpAddress.IPAddressToString

		}

		Catch
		{

			$PSCMdlet.ThrowTerminatingError($_)

		}
    
    }

	catch [HPOneView.Appliance.AuthSessionException] 
	{

		Write-Host "Default password was already changed."

	}

	Catch
	{

		$PSCMdlet.ThrowTerminatingError($_)

	}

    Write-Host "Reconnect with new password"

	Try
	{

		$ApplianceConnection = Connect-HPOVMgmt -appliance $DhcpAddress.IPAddressToString -user Administrator -password $NewPassword

	}
    
	Catch
	{

		$PSCMdlet.ThrowTerminatingError($_)

	}

    Write-Host "Set appliance networking configuration"

    $params = @{

        Hostname         = $Hostname;
        IPv4Addr         = $IPv4Address.IPAddressToString;
        IPv4Subnet       = $IPv4SubnetMask;
        IPv4Gateway      = $IPv4Gateway.IPAddressToString;
        DomainName       = $DnsDomainName;
        IPv4NameServers  = $IPv4DnsServers;
        ServiceIPv4Node1 = $ServiceIPv4Node1;
        ServiceIPv4Node2 = $ServiceIPv4Node2

    }

    if ($IPv6Address)
    {

		$params.Add('IPv6Type','STATIC')
        $params.Add('IPv6Addr', $IPv6Address)
		$params.Add('IPv6Subnet', $IPv6CidrMask)
        $params.Add('ServiceIPv6Node1', $ServiceIPv6Node1)
        $params.Add('ServiceIPv6Node2', $ServiceIPv6Node2)

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
		$ServerAdminGroup  = $LdapGroups | ? Name -match 'CI Manager Server'
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
	    gci \\Server\software\SPP\bp-2016-07-11-00.iso | Add-HPOVBaseline

	}

	Catch
	{

		$PSCMdlet.ThrowTerminatingError($_)

	}

    
	# Create the new users
    New-HPOVUser Nat   -fullName "Nat Network Admin"  -password hpinvent -roles "Network administrator"
    New-HPOVUser Sarah -fullName "Sarah Server Admin" -password hpinvent -roles "Server administrator"
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
    	password  = "pasword";
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

		New-HPOVNetwork -Name "MLAG VLAN 10" -type "Ethernet" -vlanId 10 -smartlink $true -purpose Management
		
        # Internal Networks
		New-HPOVNetwork -Name "Internal Live Migration" -type "Ethernet" -vlanId 100 -smartlink $true -purpose VMMigration
        New-HPOVNetwork -Name "Internal Heartbeat" -type "Ethernet" -vlanId 101 -smartlink $true -purpose Management
        New-HPOVNetwork -Name "iSCSI Network" -type "Ethernet" -vlanId 3000 -smartlink $true -purpose ISCSI
    
		# VM Networks
        20,30,40,50 | % { New-HPOVNetwork -Name "MLAG Prod VLAN $_" -type "Ethernet" -vlanId $_ -smartlink $true -purpose General }
		101,102,103,104,105 | % { New-HPOVNetwork -Name "MLAG Dev VLAN $_" -type "Ethernet" -vlanId $_ -smartlink $true -purpose General }

		$AllMlagDevNetworks = Get-HPOVNetwork -Name "MLAG Dev VLAN"
		$AllMlagNetworks    = Get-HPOVNetwork -Name "MLAG VLAN*"
        $InternalNetworks   = Get-HPOVNetwork -Name Internal*
    
		# Create the network sets
		New-HPOVNetworkSet -Name "Prod NetSet" -networks $AllMlagNetworks -untaggedNetwork $AllMlagNetworks[0] -typicalBandwidth 2500 -maximumBandwidth 10000 
		New-HPOVNetworkSet -Name "Dev Networks A" -networks $AllMlagDevNetworks -untaggedNetwork $AllMlagDevNetworks[0]  -typicalBandwidth 2500 -maximumBandwidth 10000 
    
		# Create the FC networks:
		New-HPOVNetwork -Name "Fabric A" -type "FibreChannel" -typicalBandwidth 4000 -autoLoginRedistribution $true #-managedSan "SAN1_0"
		New-HPOVNetwork -Name "Fabric B" -type "FibreChannel" -typicalBandwidth 4000 -autoLoginRedistribution $true #-managedSan "SAN1_1"
		New-HPOVNetwork -Name "DirectAttach A" -type "FibreChannel" -typicalBandwidth 4000 -autoLoginRedistribution $true -fabricType DirectAttach
		New-HPOVNetwork -Name "DirectAttach B" -type "FibreChannel" -typicalBandwidth 4000 -autoLoginRedistribution $true -fabricType DirectAttach

	}
    
    Catch
	{

		$PSCMdlet.ThrowTerminatingError($_)

	}

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

        $Results = Get-HPOVStorageSystem | Add-HPOVStoragePool -Pool 'FST_CPG1','FST_CPG2' | Wait-HPOVTaskComplete

	}

	Catch
	{

		$PSCMdlet.ThrowTerminatingError($_)

	}

	$SynergyLigParams = @{

		Name               = 'Default Synergy LIG';
		InterconnectBaySet = 3;
		FabricModuleType   = 'SEVC40F8';
		FrameCount         = 3;
		InternalNetworks   = $InternalNetworks;
		FabricRedundancy   = 'HighlyAvailable'
		Bays               = @{
								Frame1 = @{Bay3 = 'SEVC40f8'; Bay6 = 'SE20ILM' }; 
								Frame2 = @{Bay3 = 'SE20ILM'; Bay6 = 'SEVC40f8'};
								Frame3 = @{Bay3 = 'SE20ILM'; Bay6 = 'SE20ILM'}
								}

	}
	
	$CreatedLogicalInterconnectObject = New-HPOVLogicalInterconnectGroup @SynergyLigParams | Get-HPOVLogicalInterconnectGroup

	$UplinkSetParams = @{

		InputObject = $CreatedLogicalInterconnectObject;
		Name        = 'MLag UplinkSet';
		Type        = 'Ethernet';
		Networks    = $AllMlagNetworks;
		UplinkPorts = "Enclosure1:Bay3:Q1","Enclosure1:Bay3:Q2","Enclosure2:Bay6:Q1","Enclosure2:Bay6:Q2"

	}

	$CreateUplinkSetResults = New-HPOVUplinkSet @UplinkSetParams

	$LIG = Get-HPOVLogicalInterconnectGroup -Name 'Default Synergy LIG'
        
	$EgParams = @{

		Name                            = 'Synergy Default EG';
		EnclosureCount                  = 3;
		LogicalInterconnectGroupMapping = $LIG;
		IPv4AddressType                 = 'DHCP'

	}

    $CreateEGResults = New-HPOVEnclosureGroup @EgParams

    Disconnect-HPOVMgmt

	Remove-Module HPOneView.410

#endregion
# SIG # Begin signature block
# MIIeZwYJKoZIhvcNAQcCoIIeWDCCHlQCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCD35pN7ABwjKTBJ
# pF0sAzES6Va7E2b/0j2nW1I8ZXHbFqCCGXMwggPuMIIDV6ADAgECAhB+k+v7fMZO
# WepLmnfUBvw7MA0GCSqGSIb3DQEBBQUAMIGLMQswCQYDVQQGEwJaQTEVMBMGA1UE
# CBMMV2VzdGVybiBDYXBlMRQwEgYDVQQHEwtEdXJiYW52aWxsZTEPMA0GA1UEChMG
# VGhhd3RlMR0wGwYDVQQLExRUaGF3dGUgQ2VydGlmaWNhdGlvbjEfMB0GA1UEAxMW
# VGhhd3RlIFRpbWVzdGFtcGluZyBDQTAeFw0xMjEyMjEwMDAwMDBaFw0yMDEyMzAy
# MzU5NTlaMF4xCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3Jh
# dGlvbjEwMC4GA1UEAxMnU3ltYW50ZWMgVGltZSBTdGFtcGluZyBTZXJ2aWNlcyBD
# QSAtIEcyMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAsayzSVRLlxwS
# CtgleZEiVypv3LgmxENza8K/LlBa+xTCdo5DASVDtKHiRfTot3vDdMwi17SUAAL3
# Te2/tLdEJGvNX0U70UTOQxJzF4KLabQry5kerHIbJk1xH7Ex3ftRYQJTpqr1SSwF
# eEWlL4nO55nn/oziVz89xpLcSvh7M+R5CvvwdYhBnP/FA1GZqtdsn5Nph2Upg4XC
# YBTEyMk7FNrAgfAfDXTekiKryvf7dHwn5vdKG3+nw54trorqpuaqJxZ9YfeYcRG8
# 4lChS+Vd+uUOpyyfqmUg09iW6Mh8pU5IRP8Z4kQHkgvXaISAXWp4ZEXNYEZ+VMET
# fMV58cnBcQIDAQABo4H6MIH3MB0GA1UdDgQWBBRfmvVuXMzMdJrU3X3vP9vsTIAu
# 3TAyBggrBgEFBQcBAQQmMCQwIgYIKwYBBQUHMAGGFmh0dHA6Ly9vY3NwLnRoYXd0
# ZS5jb20wEgYDVR0TAQH/BAgwBgEB/wIBADA/BgNVHR8EODA2MDSgMqAwhi5odHRw
# Oi8vY3JsLnRoYXd0ZS5jb20vVGhhd3RlVGltZXN0YW1waW5nQ0EuY3JsMBMGA1Ud
# JQQMMAoGCCsGAQUFBwMIMA4GA1UdDwEB/wQEAwIBBjAoBgNVHREEITAfpB0wGzEZ
# MBcGA1UEAxMQVGltZVN0YW1wLTIwNDgtMTANBgkqhkiG9w0BAQUFAAOBgQADCZuP
# ee9/WTCq72i1+uMJHbtPggZdN1+mUp8WjeockglEbvVt61h8MOj5aY0jcwsSb0ep
# rjkR+Cqxm7Aaw47rWZYArc4MTbLQMaYIXCp6/OJ6HVdMqGUY6XlAYiWWbsfHN2qD
# IQiOQerd2Vc/HXdJhyoWBl6mOGoiEqNRGYN+tjCCBKMwggOLoAMCAQICEA7P9DjI
# /r81bgTYapgbGlAwDQYJKoZIhvcNAQEFBQAwXjELMAkGA1UEBhMCVVMxHTAbBgNV
# BAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMTAwLgYDVQQDEydTeW1hbnRlYyBUaW1l
# IFN0YW1waW5nIFNlcnZpY2VzIENBIC0gRzIwHhcNMTIxMDE4MDAwMDAwWhcNMjAx
# MjI5MjM1OTU5WjBiMQswCQYDVQQGEwJVUzEdMBsGA1UEChMUU3ltYW50ZWMgQ29y
# cG9yYXRpb24xNDAyBgNVBAMTK1N5bWFudGVjIFRpbWUgU3RhbXBpbmcgU2Vydmlj
# ZXMgU2lnbmVyIC0gRzQwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCi
# Yws5RLi7I6dESbsO/6HwYQpTk7CY260sD0rFbv+GPFNVDxXOBD8r/amWltm+YXkL
# W8lMhnbl4ENLIpXuwitDwZ/YaLSOQE/uhTi5EcUj8mRY8BUyb05Xoa6IpALXKh7N
# S+HdY9UXiTJbsF6ZWqidKFAOF+6W22E7RVEdzxJWC5JH/Kuu9mY9R6xwcueS51/N
# ELnEg2SUGb0lgOHo0iKl0LoCeqF3k1tlw+4XdLxBhircCEyMkoyRLZ53RB9o1qh0
# d9sOWzKLVoszvdljyEmdOsXF6jML0vGjG/SLvtmzV4s73gSneiKyJK4ux3DFvk6D
# Jgj7C72pT5kI4RAocqrNAgMBAAGjggFXMIIBUzAMBgNVHRMBAf8EAjAAMBYGA1Ud
# JQEB/wQMMAoGCCsGAQUFBwMIMA4GA1UdDwEB/wQEAwIHgDBzBggrBgEFBQcBAQRn
# MGUwKgYIKwYBBQUHMAGGHmh0dHA6Ly90cy1vY3NwLndzLnN5bWFudGVjLmNvbTA3
# BggrBgEFBQcwAoYraHR0cDovL3RzLWFpYS53cy5zeW1hbnRlYy5jb20vdHNzLWNh
# LWcyLmNlcjA8BgNVHR8ENTAzMDGgL6AthitodHRwOi8vdHMtY3JsLndzLnN5bWFu
# dGVjLmNvbS90c3MtY2EtZzIuY3JsMCgGA1UdEQQhMB+kHTAbMRkwFwYDVQQDExBU
# aW1lU3RhbXAtMjA0OC0yMB0GA1UdDgQWBBRGxmmjDkoUHtVM2lJjFz9eNrwN5jAf
# BgNVHSMEGDAWgBRfmvVuXMzMdJrU3X3vP9vsTIAu3TANBgkqhkiG9w0BAQUFAAOC
# AQEAeDu0kSoATPCPYjA3eKOEJwdvGLLeJdyg1JQDqoZOJZ+aQAMc3c7jecshaAba
# tjK0bb/0LCZjM+RJZG0N5sNnDvcFpDVsfIkWxumy37Lp3SDGcQ/NlXTctlzevTcf
# Q3jmeLXNKAQgo6rxS8SIKZEOgNER/N1cdm5PXg5FRkFuDbDqOJqxOtoJcRD8HHm0
# gHusafT9nLYMFivxf1sJPZtb4hbKE4FtAC44DagpjyzhsvRaqQGvFZwsL0kb2yK7
# w/54lFHDhrGCiF3wPbRRoXkzKy57udwgCRNx62oZW8/opTBXLIlJP7nPf8m/PiJo
# Y1OavWl0rMUdPH+S4MO8HNgEdTCCBWIwggRKoAMCAQICEQCzbs5fgB8AS2rJIXDX
# R3ilMA0GCSqGSIb3DQEBCwUAMHwxCzAJBgNVBAYTAkdCMRswGQYDVQQIExJHcmVh
# dGVyIE1hbmNoZXN0ZXIxEDAOBgNVBAcTB1NhbGZvcmQxGDAWBgNVBAoTD1NlY3Rp
# Z28gTGltaXRlZDEkMCIGA1UEAxMbU2VjdGlnbyBSU0EgQ29kZSBTaWduaW5nIENB
# MB4XDTE5MDYxODAwMDAwMFoXDTIwMDYxNzIzNTk1OVowgdIxCzAJBgNVBAYTAlVT
# MQ4wDAYDVQQRDAU5NDMwNDELMAkGA1UECAwCQ0ExEjAQBgNVBAcMCVBhbG8gQWx0
# bzEcMBoGA1UECQwTMzAwMCBIYW5vdmVyIFN0cmVldDErMCkGA1UECgwiSGV3bGV0
# dCBQYWNrYXJkIEVudGVycHJpc2UgQ29tcGFueTEaMBgGA1UECwwRSFAgQ3liZXIg
# U2VjdXJpdHkxKzApBgNVBAMMIkhld2xldHQgUGFja2FyZCBFbnRlcnByaXNlIENv
# bXBhbnkwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQClFSsHizFHGZwQ
# sgNCWgwrlOux/o1pXncJmWdaq4j2GhKfUPXgrLMgjRXf8YZKvN593hQ7Y0yGLpe4
# rTQun9zGIkSTljmAJSs5aPus2sf/iJsdSK0+V7WARK3GTIB27EtJFTk7rqF2w5wT
# o3ljE3U5MiN3sh8+wH9NiB/OglaLZOCmdBuekBnqtf4nsTXq3SfKHDujb1Wz4MEX
# dSdGjnI73CUX6CeQRAYLfdNFzuTUjVoa636etglxIpspvvEx1bOmcwRqXeYIqHAT
# I87CK4XoZGPxBS+LHO/WQrUw98m/hKd0fM22Y81P7aU3qx6L39v58N2HCnntuWvW
# 4/My8kwTAgMBAAGjggGGMIIBgjAfBgNVHSMEGDAWgBQO4TqoUzox1Yq+wbutZxoD
# ha00DjAdBgNVHQ4EFgQURYRf50CA27/6qrzBRcNYEIQSDbAwDgYDVR0PAQH/BAQD
# AgeAMAwGA1UdEwEB/wQCMAAwEwYDVR0lBAwwCgYIKwYBBQUHAwMwEQYJYIZIAYb4
# QgEBBAQDAgQQMEAGA1UdIAQ5MDcwNQYMKwYBBAGyMQECAQMCMCUwIwYIKwYBBQUH
# AgEWF2h0dHBzOi8vc2VjdGlnby5jb20vQ1BTMEMGA1UdHwQ8MDowOKA2oDSGMmh0
# dHA6Ly9jcmwuc2VjdGlnby5jb20vU2VjdGlnb1JTQUNvZGVTaWduaW5nQ0EuY3Js
# MHMGCCsGAQUFBwEBBGcwZTA+BggrBgEFBQcwAoYyaHR0cDovL2NydC5zZWN0aWdv
# LmNvbS9TZWN0aWdvUlNBQ29kZVNpZ25pbmdDQS5jcnQwIwYIKwYBBQUHMAGGF2h0
# dHA6Ly9vY3NwLnNlY3RpZ28uY29tMA0GCSqGSIb3DQEBCwUAA4IBAQBA32vHyM/A
# Krus3SOGh7LUJmoqJpy+Bi2vr7/MHSrGHGGYhe8yspy2FUsBv++n6GKKmpleP1kS
# nzCUSTP09XOAepdUn/MgD3lvXr+nBfqa8WrYKAo/xh+5gtFDOiTi99gqq0SOkHxQ
# WRtIF4VKOG7SvI3E5av0kCqeaAsSa8k2TUq9UKbiMGfHJELYe38Za94yeUTDFs/6
# 8J8H/FV8AOPmP/r+b1lxkogo+DWsmGjz2myfrVhyTn4m//ihxppB9pUZ2Iq5XEMA
# M+aPptDpxGT3Beuaz6B0+WhMP9/4tjeyHQYPcOJcWqr+uGFBUp+ATYtOhGUxWfpX
# 8y2VaXU+x/I/MIIFdzCCBF+gAwIBAgIQE+oocFv07O0MNmMJgGFDNjANBgkqhkiG
# 9w0BAQwFADBvMQswCQYDVQQGEwJTRTEUMBIGA1UEChMLQWRkVHJ1c3QgQUIxJjAk
# BgNVBAsTHUFkZFRydXN0IEV4dGVybmFsIFRUUCBOZXR3b3JrMSIwIAYDVQQDExlB
# ZGRUcnVzdCBFeHRlcm5hbCBDQSBSb290MB4XDTAwMDUzMDEwNDgzOFoXDTIwMDUz
# MDEwNDgzOFowgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpOZXcgSmVyc2V5MRQw
# EgYDVQQHEwtKZXJzZXkgQ2l0eTEeMBwGA1UEChMVVGhlIFVTRVJUUlVTVCBOZXR3
# b3JrMS4wLAYDVQQDEyVVU0VSVHJ1c3QgUlNBIENlcnRpZmljYXRpb24gQXV0aG9y
# aXR5MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAgBJlFzYOw9sIs9Cs
# Vw127c0n00ytUINh4qogTQktZAnczomfzD2p7PbPwdzx07HWezcoEStH2jnGvDoZ
# tF+mvX2do2NCtnbyqTsrkfjib9DsFiCQCT7i6HTJGLSR1GJk23+jBvGIGGqQIjy8
# /hPwhxR79uQfjtTkUcYRZ0YIUcuGFFQ/vDP+fmyc/xadGL1RjjWmp2bIcmfbIWax
# 1Jt4A8BQOujM8Ny8nkz+rwWWNR9XWrf/zvk9tyy29lTdyOcSOk2uTIq3XJq0tyA9
# yn8iNK5+O2hmAUTnAU5GU5szYPeUvlM3kHND8zLDU+/bqv50TmnHa4xgk97Exwzf
# 4TKuzJM7UXiVZ4vuPVb+DNBpDxsP8yUmazNt925H+nND5X4OpWaxKXwyhGNVicQN
# wZNUMBkTrNN9N6frXTpsNVzbQdcS2qlJC9/YgIoJk2KOtWbPJYjNhLixP6Q5D9kC
# nusSTJV882sFqV4Wg8y4Z+LoE53MW4LTTLPtW//e5XOsIzstAL81VXQJSdhJWBp/
# kjbmUZIO8yZ9HE0XvMnsQybQv0FfQKlERPSZ51eHnlAfV1SoPv10Yy+xUGUJ5lhC
# LkMaTLTwJUdZ+gQek9QmRkpQgbLevni3/GcV4clXhB4PY9bpYrrWX1Uu6lzGKAgE
# JTm4Diup8kyXHAc/DVL17e8vgg8CAwEAAaOB9DCB8TAfBgNVHSMEGDAWgBStvZh6
# NLQm9/rEJlTvA73gJMtUGjAdBgNVHQ4EFgQUU3m/WqorSs9UgOHYm8Cd8rIDZssw
# DgYDVR0PAQH/BAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8wEQYDVR0gBAowCDAGBgRV
# HSAAMEQGA1UdHwQ9MDswOaA3oDWGM2h0dHA6Ly9jcmwudXNlcnRydXN0LmNvbS9B
# ZGRUcnVzdEV4dGVybmFsQ0FSb290LmNybDA1BggrBgEFBQcBAQQpMCcwJQYIKwYB
# BQUHMAGGGWh0dHA6Ly9vY3NwLnVzZXJ0cnVzdC5jb20wDQYJKoZIhvcNAQEMBQAD
# ggEBAJNl9jeDlQ9ew4IcH9Z35zyKwKoJ8OkLJvHgwmp1ocd5yblSYMgpEg7wrQPW
# CcR23+WmgZWnRtqCV6mVksW2jwMibDN3wXsyF24HzloUQToFJBv2FAY7qCUkDrvM
# KnXduXBBP3zQYzYhBx9G/2CkkeFnvN4ffhkUyWNnkepnB2u0j4vAbkN9w6GAbLIe
# vFOFfdyQoaS8Le9Gclc1Bb+7RrtubTeZtv8jkpHGbkD4jylW6l/VXxRTrPBPYer3
# IsynVgviuDQfJtl7GQVoP7o81DgGotPmjw7jtHFtQELFhLRAlSv0ZaBIefYdgWOW
# nU914Ph85I6p0fKtirOMxyHNwu8wggX1MIID3aADAgECAhAdokgwb5smGNCC4JZ9
# M9NqMA0GCSqGSIb3DQEBDAUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMKTmV3
# IEplcnNleTEUMBIGA1UEBxMLSmVyc2V5IENpdHkxHjAcBgNVBAoTFVRoZSBVU0VS
# VFJVU1QgTmV0d29yazEuMCwGA1UEAxMlVVNFUlRydXN0IFJTQSBDZXJ0aWZpY2F0
# aW9uIEF1dGhvcml0eTAeFw0xODExMDIwMDAwMDBaFw0zMDEyMzEyMzU5NTlaMHwx
# CzAJBgNVBAYTAkdCMRswGQYDVQQIExJHcmVhdGVyIE1hbmNoZXN0ZXIxEDAOBgNV
# BAcTB1NhbGZvcmQxGDAWBgNVBAoTD1NlY3RpZ28gTGltaXRlZDEkMCIGA1UEAxMb
# U2VjdGlnbyBSU0EgQ29kZSBTaWduaW5nIENBMIIBIjANBgkqhkiG9w0BAQEFAAOC
# AQ8AMIIBCgKCAQEAhiKNMoV6GJ9J8JYvYwgeLdx8nxTP4ya2JWYpQIZURnQxYsUQ
# 7bKHJ6aZy5UwwFb1pHXGqQ5QYqVRkRBq4Etirv3w+Bisp//uLjMg+gwZiahse60A
# w2Gh3GllbR9uJ5bXl1GGpvQn5Xxqi5UeW2DVftcWkpwAL2j3l+1qcr44O2Pej79u
# TEFdEiAIWeg5zY/S1s8GtFcFtk6hPldrH5i8xGLWGwuNx2YbSp+dgcRyQLXiX+8L
# Rf+jzhemLVWwt7C8VGqdvI1WU8bwunlQSSz3A7n+L2U18iLqLAevRtn5RhzcjHxx
# KPP+p8YU3VWRbooRDd8GJJV9D6ehfDrahjVh0wIDAQABo4IBZDCCAWAwHwYDVR0j
# BBgwFoAUU3m/WqorSs9UgOHYm8Cd8rIDZsswHQYDVR0OBBYEFA7hOqhTOjHVir7B
# u61nGgOFrTQOMA4GA1UdDwEB/wQEAwIBhjASBgNVHRMBAf8ECDAGAQH/AgEAMB0G
# A1UdJQQWMBQGCCsGAQUFBwMDBggrBgEFBQcDCDARBgNVHSAECjAIMAYGBFUdIAAw
# UAYDVR0fBEkwRzBFoEOgQYY/aHR0cDovL2NybC51c2VydHJ1c3QuY29tL1VTRVJU
# cnVzdFJTQUNlcnRpZmljYXRpb25BdXRob3JpdHkuY3JsMHYGCCsGAQUFBwEBBGow
# aDA/BggrBgEFBQcwAoYzaHR0cDovL2NydC51c2VydHJ1c3QuY29tL1VTRVJUcnVz
# dFJTQUFkZFRydXN0Q0EuY3J0MCUGCCsGAQUFBzABhhlodHRwOi8vb2NzcC51c2Vy
# dHJ1c3QuY29tMA0GCSqGSIb3DQEBDAUAA4ICAQBNY1DtRzRKYaTb3moqjJvxAAAe
# HWJ7Otcywvaz4GOz+2EAiJobbRAHBE++uOqJeCLrD0bs80ZeQEaJEvQLd1qcKkE6
# /Nb06+f3FZUzw6GDKLfeL+SU94Uzgy1KQEi/msJPSrGPJPSzgTfTt2SwpiNqWWhS
# Ql//BOvhdGV5CPWpk95rcUCZlrp48bnI4sMIFrGrY1rIFYBtdF5KdX6luMNstc/f
# SnmHXMdATWM19jDTz7UKDgsEf6BLrrujpdCEAJM+U100pQA1aWy+nyAlEA0Z+1CQ
# Yb45j3qOTfafDh7+B1ESZoMmGUiVzkrJwX/zOgWb+W/fiH/AI57SHkN6RTHBnE2p
# 8FmyWRnoao0pBAJ3fEtLzXC+OrJVWng+vLtvAxAldxU0ivk2zEOS5LpP8WKTKCVX
# KftRGcehJUBqhFfGsp2xvBwK2nxnfn0u6ShMGH7EezFBcZpLKewLPVdQ0srd/Z4F
# UeVEeN0B3rF1mA1UJP3wTuPi+IO9crrLPTru8F4XkmhtyGH5pvEqCgulufSe7pgy
# BYWe6/mDKdPGLH29OncuizdCoGqC7TtKqpQQpOEN+BfFtlp5MxiS47V1+KHpjgol
# HuQe8Z9ahyP/n6RRnvs5gBHN27XEp6iAb+VT1ODjosLSWxr6MiYtaldwHDykWC6j
# 81tLB9wyWfOHpxptWDGCBEowggRGAgEBMIGRMHwxCzAJBgNVBAYTAkdCMRswGQYD
# VQQIExJHcmVhdGVyIE1hbmNoZXN0ZXIxEDAOBgNVBAcTB1NhbGZvcmQxGDAWBgNV
# BAoTD1NlY3RpZ28gTGltaXRlZDEkMCIGA1UEAxMbU2VjdGlnbyBSU0EgQ29kZSBT
# aWduaW5nIENBAhEAs27OX4AfAEtqySFw10d4pTANBglghkgBZQMEAgEFAKB8MBAG
# CisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisG
# AQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCDQsAKmDQpq
# 7jcpzuxXlMIDVQZREsXofUgi2Tl9KU2AiDANBgkqhkiG9w0BAQEFAASCAQBMevTM
# Pa0WDtTu8mtYZcuooqcpLibINBVUHwljsedZ3AylUwxvmItTad02T4YHqvarqE2H
# +wKh+X3PZS3tet49Igdacv3Wp/nEcJFMXLgpKnTMVWwg/vBj95oshbB+bYRlfIwc
# E6dvP+xgHHAEMfeHi0n/yVFxbPPk9PxpRhlcpaKiKSJdbk8sJsBGXEVm/AMrxvJ+
# BtQVyXoRDmnjyuh+tWKsWOBdBkVqtiIeFh1E6od1ZTFF1CRCQoMjdl1QGXUSiuxb
# oBcaXWZts/9BMxfBsITLuVDTLkp/EVNTOIs6kgbt8L7/ZziL6g0mxacc1m5ddQqp
# W7mucIYW0b5jSbg3oYICCzCCAgcGCSqGSIb3DQEJBjGCAfgwggH0AgEBMHIwXjEL
# MAkGA1UEBhMCVVMxHTAbBgNVBAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMTAwLgYD
# VQQDEydTeW1hbnRlYyBUaW1lIFN0YW1waW5nIFNlcnZpY2VzIENBIC0gRzICEA7P
# 9DjI/r81bgTYapgbGlAwCQYFKw4DAhoFAKBdMBgGCSqGSIb3DQEJAzELBgkqhkiG
# 9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTIwMDQyNzIzMDQzMFowIwYJKoZIhvcNAQkE
# MRYEFIenHHznq22fb2gzCwN2QKSDHP+MMA0GCSqGSIb3DQEBAQUABIIBAFkXjuIc
# raEqYFxSKCFo6oeTFUJA7G2bNK7XdamValXHhM5qg2mv1wCw5CPhVSWsAKsl5OOP
# d51dm9NPyCWtXH02GwPsxtfzLDYoDoWfSs+kpTHlVdMatrJpZLf+UWLX40cvehLA
# FifGaACUJ4arKu8/O+rD7AqZJPfjL7xWbF8GPn6l6u5Mq/1SD14RwGYrWUMOyPs8
# JvErqzf9lmsgQKMkfPvSSfaFNNnpNsEsXVH3+s63c32UDByT4ChbYY23LsQsDCJJ
# +Uix+GDD+q5AQTup3z8rzJsPAPhCU9K2PI7zx3W9aL5qlqm2FXSQGdrVBGLZSaa/
# gr9cu0Tv9azDQFg=
# SIG # End signature block
