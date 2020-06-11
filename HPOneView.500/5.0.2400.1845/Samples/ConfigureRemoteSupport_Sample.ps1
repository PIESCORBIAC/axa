##############################################################################
# ConfigureRemoteSupport_Sample.ps1
# - Example script to configure Remote Support
#
#   VERSION 1.0
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

    [Parameter (Mandatory, HelpMessage = "Provide the Company Name.", ParameterSetName = 'Default')]
    [Parameter (Mandatory, HelpMessage = "Provide the Company Name.", ParameterSetName = 'Default')]
    [ValidateNotNullorEmpty()]
	[String]$CompanyName,

	[Parameter (Mandatory = $false, HelpMessage = "Use to enable HPE marketing emails.", ParameterSetName = 'Default')]
	[Parameter (Mandatory = $false, HelpMessage = "Use to enable HPE marketing emails.", ParameterSetName = 'InsightOnline')]
	[Switch]$MarketingOptIn,

	[Parameter (Mandatory, HelpMessage = "Provide the authorized HPE Passport account to register the appliance with Insight Online.", ParameterSetName = 'InsightOnline')]
	[ValidateNotNullorEmpty()]
	[String]$InsightOnlineUsername = 'MyPassportAccount@domain.com',

	[Parameter (Mandatory, HelpMessage = "Provide the authorized HPE Passport account password to register the appliance with Insight Online.", ParameterSetName = 'InsightOnline')]
    [ValidateNotNullorEmpty()]
	[securestring]$InsightOnlinePassword = (ConvertTo-SecureString -String 'MyPassword' -AsPlainText -Force),

	[Parameter (Mandatory, HelpMessage = "Provide the default site Address.", ParameterSetName = 'Default')]
	[Parameter (Mandatory, HelpMessage = "Provide the default site Address.", ParameterSetName = 'InsightOnline')]
    [ValidateNotNullorEmpty()]
	[String]$AddressLine1,

	[Parameter (Mandatory = $false, HelpMessage = "Provide the default site Address.", ParameterSetName = 'Default')]
	[Parameter (Mandatory = $false, HelpMessage = "Provide the default site Address.", ParameterSetName = 'InsightOnline')]
    [ValidateNotNullorEmpty()]
	[String]$AddressLine2,

	[Parameter (Mandatory, HelpMessage = "Provide the default site City.", ParameterSetName = 'Default')]
	[Parameter (Mandatory, HelpMessage = "Provide the default site City.", ParameterSetName = 'InsightOnline')]
    [ValidateNotNullorEmpty()]
	[String]$City,

	[Parameter (Mandatory, HelpMessage = "Provide the default site State or Provence.", ParameterSetName = 'Default')]
	[Parameter (Mandatory, HelpMessage = "Provide the default site State or Provence.", ParameterSetName = 'InsightOnline')]
    [ValidateNotNullorEmpty()]
	[String]$State,

	[Parameter (Mandatory, HelpMessage = "Provide the default site Postal or Zip code.", ParameterSetName = 'Default')]
	[Parameter (Mandatory, HelpMessage = "Provide the default site Postal or Zip code.", ParameterSetName = 'InsightOnline')]
    [ValidateNotNullorEmpty()]
	[String]$PostalCode,

    [Parameter (Mandatory, HelpMessage = "Provide the default site Country.", ParameterSetName = 'Default')]
    [Parameter (Mandatory, HelpMessage = "Provide the default site Country.", ParameterSetName = 'InsightOnline')]
    [ValidateNotNullorEmpty()]
    [String]$Country,

    [Parameter (Mandatory, HelpMessage = "Provide the default site Timezone.", ParameterSetName = 'Default')]
    [Parameter (Mandatory, HelpMessage = "Provide the default site Timezone.", ParameterSetName = 'InsightOnline')]
    [ValidateNotNullorEmpty()]
    [String]$TimeZone,

	[Parameter (Mandatory = $false, HelpMessage = "Provide the primary Remote Support contact as a Hashtable.  Example: @{FirstName = 'Bob'; LastName = 'Smith'; Email = 'bob.smith@domain.com'; PrimaryPhone = '123-456-7890'; Language = 'en'; Default = `$true}", ParameterSetName = 'Default')]
	[Parameter (Mandatory = $false, HelpMessage = "Provide the primary Remote Support contact as a Hashtable.  Example: @{FirstName = 'Bob'; LastName = 'Smith'; Email = 'bob.smith@domain.com'; PrimaryPhone = '123-456-7890'; Language = 'en'; Default = `$true}")]
    [ValidateNotNullorEmpty()]
    [ValidateNotNullorEmpty()]
	[Hashtable]$PrimaryContact,

	[Parameter (Mandatory = $false, HelpMessage = "Provide the secondary Remote Support contact as a Hashtable.  Example: @{FirstName = 'Bob'; LastName = 'Smith'; Email = 'bob.smith@domain.com'; PrimaryPhone = '123-456-7890'; Language = 'en'; Default = `$true}", ParameterSetName = 'Default')]
	[Parameter (Mandatory = $false, HelpMessage = "Provide the secondary Remote Support contact as a Hashtable.  Example: @{FirstName = 'Bob'; LastName = 'Smith'; Email = 'bob.smith@domain.com'; PrimaryPhone = '123-456-7890'; Language = 'en'; Default = `$true}")]
    [ValidateNotNullorEmpty()]
	[Hashtable]$SecondaryContact,

	[Parameter (Mandatory = $false, HelpMessage = "Provide the Remote Support Reseller Partner as a Hashtable.  Example: @{Name = 'My Reseller Partner'; Type = 'Reseller'; ResellerID = 1234567}", ParameterSetName = 'Default')]
	[Parameter (Mandatory = $false, HelpMessage = "Provide the Remote Support Reseller Partner as a Hashtable.  Example: @{Name = 'My Reseller Partner'; Type = 'Reseller'; ResellerID = 1234567}", ParameterSetName = 'InsightOnline')]
    [ValidateNotNullorEmpty()]
    [Hashtable]$ResellerPartner,

	[Parameter (Mandatory = $false, HelpMessage = "Provide the secondary Remote Support contact as a Hashtable.  Example: @{Name = 'My Support Partner'; Type = 'Support'; ResellerID = 098765}", ParameterSetName = 'Default')]
	[Parameter (Mandatory = $false, HelpMessage = "Provide the secondary Remote Support contact as a Hashtable.  Example: @{Name = 'My Support Partner'; Type = 'Support'; ResellerID = 098765}", ParameterSetName = 'InsightOnline')]
    [ValidateNotNullorEmpty()]
    [Hashtable]$SupportPartner



)

if (-not (Get-Module HPOneView.410)) 
{

    Import-Module POSH-HPOneView.410

}

if (-not $ConnectedSessions) 
{

	$Appliance = Read-Host 'ApplianceName'
	$Username  = Read-Host 'Username'
	$Password  = Read-Host 'Password' -AsSecureString

    $ApplianceConnection = Connect-HPOVMgmt -Hostname $Appliance -Username $Username -Password $Password

}

"Connected to appliance: {0} " -f ($ConnectedSessions | ? Default).Name | Write-Host

#Add Primary (Default) Remote Support Contact
New-HPOVRemoteSupportContact @PrimaryContact

if ($PSBoundParameters['SecondaryContact'])
{

    New-HPOVRemoteSupportContact @SecondaryContact

}

#Set the datacenter site address
$DefaultSiteParams = @{

    AddressLine1 = $AddressLine1;
    State        = $State;
    City         = $City;
    PostalCode   = $PostalCode;
    Country      = $Country;
    TimeZone     = $TimeZone

}

if ($PSBoundParameters['AddressLine2'])
{

    $DefaultSiteParams.Add('AddressLine2',$AddressLine2)

}

Set-HPOVRemoteSupportDefaultSite @DefaultSiteParams

#Add a new Reseller Partner
if ($PSBoundParameters['ResellerPartner'])
{

    New-HPOVRemoteSupportPartner @ResellerPartner

}

#Add a new Support Partner
if ($PSBoundParameters['SupportPartner'])
{

    New-HPOVRemoteSupportPartner @SupportPartner

}

#Register and authorize the appliance with your Company Name.  Uncomment the end to enable Insight Online portal registration.
$EnableRemoteSupportParams = @{

    CompanyName = $CompanyName;
    MarketingOptIn = $MarketingOptIn.IsPresent

}

if ($PSCmdlet.ParameterSetName -eq 'InsightOnline')
{

    $EnableRemoteSupportParams.Add('InsightOnlineUsername', $InsightOnlineUsername)
    $EnableRemoteSupportParams.Add('InsightOnlinePassword', $InsightOnlinePassword)

}

Set-HPOVRemoteSupport @EnableRemoteSupportParams


# SIG # Begin signature block
# MIIjEQYJKoZIhvcNAQcCoIIjAjCCIv4CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCuG7khueONSDZP
# EnamH8UkByxf9h+vBS030LODeyM40qCCHhkwggViMIIESqADAgECAhEAs27OX4Af
# AEtqySFw10d4pTANBgkqhkiG9w0BAQsFADB8MQswCQYDVQQGEwJHQjEbMBkGA1UE
# CBMSR3JlYXRlciBNYW5jaGVzdGVyMRAwDgYDVQQHEwdTYWxmb3JkMRgwFgYDVQQK
# Ew9TZWN0aWdvIExpbWl0ZWQxJDAiBgNVBAMTG1NlY3RpZ28gUlNBIENvZGUgU2ln
# bmluZyBDQTAeFw0xOTA2MTgwMDAwMDBaFw0yMDA2MTcyMzU5NTlaMIHSMQswCQYD
# VQQGEwJVUzEOMAwGA1UEEQwFOTQzMDQxCzAJBgNVBAgMAkNBMRIwEAYDVQQHDAlQ
# YWxvIEFsdG8xHDAaBgNVBAkMEzMwMDAgSGFub3ZlciBTdHJlZXQxKzApBgNVBAoM
# Ikhld2xldHQgUGFja2FyZCBFbnRlcnByaXNlIENvbXBhbnkxGjAYBgNVBAsMEUhQ
# IEN5YmVyIFNlY3VyaXR5MSswKQYDVQQDDCJIZXdsZXR0IFBhY2thcmQgRW50ZXJw
# cmlzZSBDb21wYW55MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEApRUr
# B4sxRxmcELIDQloMK5Trsf6NaV53CZlnWquI9hoSn1D14KyzII0V3/GGSrzefd4U
# O2NMhi6XuK00Lp/cxiJEk5Y5gCUrOWj7rNrH/4ibHUitPle1gEStxkyAduxLSRU5
# O66hdsOcE6N5YxN1OTIjd7IfPsB/TYgfzoJWi2TgpnQbnpAZ6rX+J7E16t0nyhw7
# o29Vs+DBF3UnRo5yO9wlF+gnkEQGC33TRc7k1I1aGut+nrYJcSKbKb7xMdWzpnME
# al3mCKhwEyPOwiuF6GRj8QUvixzv1kK1MPfJv4SndHzNtmPNT+2lN6sei9/b+fDd
# hwp57blr1uPzMvJMEwIDAQABo4IBhjCCAYIwHwYDVR0jBBgwFoAUDuE6qFM6MdWK
# vsG7rWcaA4WtNA4wHQYDVR0OBBYEFEWEX+dAgNu/+qq8wUXDWBCEEg2wMA4GA1Ud
# DwEB/wQEAwIHgDAMBgNVHRMBAf8EAjAAMBMGA1UdJQQMMAoGCCsGAQUFBwMDMBEG
# CWCGSAGG+EIBAQQEAwIEEDBABgNVHSAEOTA3MDUGDCsGAQQBsjEBAgEDAjAlMCMG
# CCsGAQUFBwIBFhdodHRwczovL3NlY3RpZ28uY29tL0NQUzBDBgNVHR8EPDA6MDig
# NqA0hjJodHRwOi8vY3JsLnNlY3RpZ28uY29tL1NlY3RpZ29SU0FDb2RlU2lnbmlu
# Z0NBLmNybDBzBggrBgEFBQcBAQRnMGUwPgYIKwYBBQUHMAKGMmh0dHA6Ly9jcnQu
# c2VjdGlnby5jb20vU2VjdGlnb1JTQUNvZGVTaWduaW5nQ0EuY3J0MCMGCCsGAQUF
# BzABhhdodHRwOi8vb2NzcC5zZWN0aWdvLmNvbTANBgkqhkiG9w0BAQsFAAOCAQEA
# QN9rx8jPwCq7rN0jhoey1CZqKiacvgYtr6+/zB0qxhxhmIXvMrKcthVLAb/vp+hi
# ipqZXj9ZEp8wlEkz9PVzgHqXVJ/zIA95b16/pwX6mvFq2CgKP8YfuYLRQzok4vfY
# KqtEjpB8UFkbSBeFSjhu0ryNxOWr9JAqnmgLEmvJNk1KvVCm4jBnxyRC2Ht/GWve
# MnlEwxbP+vCfB/xVfADj5j/6/m9ZcZKIKPg1rJho89psn61Yck5+Jv/4ocaaQfaV
# GdiKuVxDADPmj6bQ6cRk9wXrms+gdPloTD/f+LY3sh0GD3DiXFqq/rhhQVKfgE2L
# ToRlMVn6V/MtlWl1PsfyPzCCBXcwggRfoAMCAQICEBPqKHBb9OztDDZjCYBhQzYw
# DQYJKoZIhvcNAQEMBQAwbzELMAkGA1UEBhMCU0UxFDASBgNVBAoTC0FkZFRydXN0
# IEFCMSYwJAYDVQQLEx1BZGRUcnVzdCBFeHRlcm5hbCBUVFAgTmV0d29yazEiMCAG
# A1UEAxMZQWRkVHJ1c3QgRXh0ZXJuYWwgQ0EgUm9vdDAeFw0wMDA1MzAxMDQ4Mzha
# Fw0yMDA1MzAxMDQ4MzhaMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMKTmV3IEpl
# cnNleTEUMBIGA1UEBxMLSmVyc2V5IENpdHkxHjAcBgNVBAoTFVRoZSBVU0VSVFJV
# U1QgTmV0d29yazEuMCwGA1UEAxMlVVNFUlRydXN0IFJTQSBDZXJ0aWZpY2F0aW9u
# IEF1dGhvcml0eTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAIASZRc2
# DsPbCLPQrFcNdu3NJ9NMrVCDYeKqIE0JLWQJ3M6Jn8w9qez2z8Hc8dOx1ns3KBEr
# R9o5xrw6GbRfpr19naNjQrZ28qk7K5H44m/Q7BYgkAk+4uh0yRi0kdRiZNt/owbx
# iBhqkCI8vP4T8IcUe/bkH47U5FHGEWdGCFHLhhRUP7wz/n5snP8WnRi9UY41pqdm
# yHJn2yFmsdSbeAPAUDrozPDcvJ5M/q8FljUfV1q3/875PbcstvZU3cjnEjpNrkyK
# t1yatLcgPcp/IjSufjtoZgFE5wFORlObM2D3lL5TN5BzQ/Myw1Pv26r+dE5px2uM
# YJPexMcM3+EyrsyTO1F4lWeL7j1W/gzQaQ8bD/MlJmszbfduR/pzQ+V+DqVmsSl8
# MoRjVYnEDcGTVDAZE6zTfTen6106bDVc20HXEtqpSQvf2ICKCZNijrVmzyWIzYS4
# sT+kOQ/ZAp7rEkyVfPNrBaleFoPMuGfi6BOdzFuC00yz7Vv/3uVzrCM7LQC/NVV0
# CUnYSVgaf5I25lGSDvMmfRxNF7zJ7EMm0L9BX0CpRET0medXh55QH1dUqD79dGMv
# sVBlCeZYQi5DGky08CVHWfoEHpPUJkZKUIGy3r54t/xnFeHJV4QeD2PW6WK61l9V
# LupcxigIBCU5uA4rqfJMlxwHPw1S9e3vL4IPAgMBAAGjgfQwgfEwHwYDVR0jBBgw
# FoAUrb2YejS0Jvf6xCZU7wO94CTLVBowHQYDVR0OBBYEFFN5v1qqK0rPVIDh2JvA
# nfKyA2bLMA4GA1UdDwEB/wQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MBEGA1UdIAQK
# MAgwBgYEVR0gADBEBgNVHR8EPTA7MDmgN6A1hjNodHRwOi8vY3JsLnVzZXJ0cnVz
# dC5jb20vQWRkVHJ1c3RFeHRlcm5hbENBUm9vdC5jcmwwNQYIKwYBBQUHAQEEKTAn
# MCUGCCsGAQUFBzABhhlodHRwOi8vb2NzcC51c2VydHJ1c3QuY29tMA0GCSqGSIb3
# DQEBDAUAA4IBAQCTZfY3g5UPXsOCHB/Wd+c8isCqCfDpCybx4MJqdaHHecm5UmDI
# KRIO8K0D1gnEdt/lpoGVp0bagleplZLFto8DImwzd8F7MhduB85aFEE6BSQb9hQG
# O6glJA67zCp13blwQT980GM2IQcfRv9gpJHhZ7zeH34ZFMljZ5HqZwdrtI+LwG5D
# fcOhgGyyHrxThX3ckKGkvC3vRnJXNQW/u0a7bm03mbb/I5KRxm5A+I8pVupf1V8U
# U6zwT2Hq9yLMp1YL4rg0HybZexkFaD+6PNQ4BqLT5o8O47RxbUBCxYS0QJUr9GWg
# SHn2HYFjlp1PdeD4fOSOqdHyrYqzjMchzcLvMIIF9TCCA92gAwIBAgIQHaJIMG+b
# JhjQguCWfTPTajANBgkqhkiG9w0BAQwFADCBiDELMAkGA1UEBhMCVVMxEzARBgNV
# BAgTCk5ldyBKZXJzZXkxFDASBgNVBAcTC0plcnNleSBDaXR5MR4wHAYDVQQKExVU
# aGUgVVNFUlRSVVNUIE5ldHdvcmsxLjAsBgNVBAMTJVVTRVJUcnVzdCBSU0EgQ2Vy
# dGlmaWNhdGlvbiBBdXRob3JpdHkwHhcNMTgxMTAyMDAwMDAwWhcNMzAxMjMxMjM1
# OTU5WjB8MQswCQYDVQQGEwJHQjEbMBkGA1UECBMSR3JlYXRlciBNYW5jaGVzdGVy
# MRAwDgYDVQQHEwdTYWxmb3JkMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxJDAi
# BgNVBAMTG1NlY3RpZ28gUlNBIENvZGUgU2lnbmluZyBDQTCCASIwDQYJKoZIhvcN
# AQEBBQADggEPADCCAQoCggEBAIYijTKFehifSfCWL2MIHi3cfJ8Uz+MmtiVmKUCG
# VEZ0MWLFEO2yhyemmcuVMMBW9aR1xqkOUGKlUZEQauBLYq798PgYrKf/7i4zIPoM
# GYmobHutAMNhodxpZW0fbieW15dRhqb0J+V8aouVHltg1X7XFpKcAC9o95ftanK+
# ODtj3o+/bkxBXRIgCFnoOc2P0tbPBrRXBbZOoT5Xax+YvMRi1hsLjcdmG0qfnYHE
# ckC14l/vC0X/o84Xpi1VsLewvFRqnbyNVlPG8Lp5UEks9wO5/i9lNfIi6iwHr0bZ
# +UYc3Ix8cSjz/qfGFN1VkW6KEQ3fBiSVfQ+noXw62oY1YdMCAwEAAaOCAWQwggFg
# MB8GA1UdIwQYMBaAFFN5v1qqK0rPVIDh2JvAnfKyA2bLMB0GA1UdDgQWBBQO4Tqo
# Uzox1Yq+wbutZxoDha00DjAOBgNVHQ8BAf8EBAMCAYYwEgYDVR0TAQH/BAgwBgEB
# /wIBADAdBgNVHSUEFjAUBggrBgEFBQcDAwYIKwYBBQUHAwgwEQYDVR0gBAowCDAG
# BgRVHSAAMFAGA1UdHwRJMEcwRaBDoEGGP2h0dHA6Ly9jcmwudXNlcnRydXN0LmNv
# bS9VU0VSVHJ1c3RSU0FDZXJ0aWZpY2F0aW9uQXV0aG9yaXR5LmNybDB2BggrBgEF
# BQcBAQRqMGgwPwYIKwYBBQUHMAKGM2h0dHA6Ly9jcnQudXNlcnRydXN0LmNvbS9V
# U0VSVHJ1c3RSU0FBZGRUcnVzdENBLmNydDAlBggrBgEFBQcwAYYZaHR0cDovL29j
# c3AudXNlcnRydXN0LmNvbTANBgkqhkiG9w0BAQwFAAOCAgEATWNQ7Uc0SmGk295q
# Koyb8QAAHh1iezrXMsL2s+Bjs/thAIiaG20QBwRPvrjqiXgi6w9G7PNGXkBGiRL0
# C3danCpBOvzW9Ovn9xWVM8Ohgyi33i/klPeFM4MtSkBIv5rCT0qxjyT0s4E307dk
# sKYjalloUkJf/wTr4XRleQj1qZPea3FAmZa6ePG5yOLDCBaxq2NayBWAbXReSnV+
# pbjDbLXP30p5h1zHQE1jNfYw08+1Cg4LBH+gS667o6XQhACTPlNdNKUANWlsvp8g
# JRANGftQkGG+OY96jk32nw4e/gdREmaDJhlIlc5KycF/8zoFm/lv34h/wCOe0h5D
# ekUxwZxNqfBZslkZ6GqNKQQCd3xLS81wvjqyVVp4Pry7bwMQJXcVNIr5NsxDkuS6
# T/FikyglVyn7URnHoSVAaoRXxrKdsbwcCtp8Z359LukoTBh+xHsxQXGaSynsCz1X
# UNLK3f2eBVHlRHjdAd6xdZgNVCT98E7j4viDvXK6yz067vBeF5Jobchh+abxKgoL
# pbn0nu6YMgWFnuv5gynTxix9vTp3Los3QqBqgu07SqqUEKThDfgXxbZaeTMYkuO1
# dfih6Y4KJR7kHvGfWocj/5+kUZ77OYARzdu1xKeogG/lU9Tg46LC0lsa+jImLWpX
# cBw8pFguo/NbSwfcMlnzh6cabVgwggZqMIIFUqADAgECAhADAZoCOv9YsWvW1erm
# F/BmMA0GCSqGSIb3DQEBBQUAMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdp
# Q2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERp
# Z2lDZXJ0IEFzc3VyZWQgSUQgQ0EtMTAeFw0xNDEwMjIwMDAwMDBaFw0yNDEwMjIw
# MDAwMDBaMEcxCzAJBgNVBAYTAlVTMREwDwYDVQQKEwhEaWdpQ2VydDElMCMGA1UE
# AxMcRGlnaUNlcnQgVGltZXN0YW1wIFJlc3BvbmRlcjCCASIwDQYJKoZIhvcNAQEB
# BQADggEPADCCAQoCggEBAKNkXfx8s+CCNeDg9sYq5kl1O8xu4FOpnx9kWeZ8a39r
# jJ1V+JLjntVaY1sCSVDZg85vZu7dy4XpX6X51Id0iEQ7Gcnl9ZGfxhQ5rCTqqEss
# kYnMXij0ZLZQt/USs3OWCmejvmGfrvP9Enh1DqZbFP1FI46GRFV9GIYFjFWHeUhG
# 98oOjafeTl/iqLYtWQJhiGFyGGi5uHzu5uc0LzF3gTAfuzYBje8n4/ea8EwxZI3j
# 6/oZh6h+z+yMDDZbesF6uHjHyQYuRhDIjegEYNu8c3T6Ttj+qkDxss5wRoPp2kCh
# WTrZFQlXmVYwk/PJYczQCMxr7GJCkawCwO+k8IkRj3cCAwEAAaOCAzUwggMxMA4G
# A1UdDwEB/wQEAwIHgDAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUF
# BwMIMIIBvwYDVR0gBIIBtjCCAbIwggGhBglghkgBhv1sBwEwggGSMCgGCCsGAQUF
# BwIBFhxodHRwczovL3d3dy5kaWdpY2VydC5jb20vQ1BTMIIBZAYIKwYBBQUHAgIw
# ggFWHoIBUgBBAG4AeQAgAHUAcwBlACAAbwBmACAAdABoAGkAcwAgAEMAZQByAHQA
# aQBmAGkAYwBhAHQAZQAgAGMAbwBuAHMAdABpAHQAdQB0AGUAcwAgAGEAYwBjAGUA
# cAB0AGEAbgBjAGUAIABvAGYAIAB0AGgAZQAgAEQAaQBnAGkAQwBlAHIAdAAgAEMA
# UAAvAEMAUABTACAAYQBuAGQAIAB0AGgAZQAgAFIAZQBsAHkAaQBuAGcAIABQAGEA
# cgB0AHkAIABBAGcAcgBlAGUAbQBlAG4AdAAgAHcAaABpAGMAaAAgAGwAaQBtAGkA
# dAAgAGwAaQBhAGIAaQBsAGkAdAB5ACAAYQBuAGQAIABhAHIAZQAgAGkAbgBjAG8A
# cgBwAG8AcgBhAHQAZQBkACAAaABlAHIAZQBpAG4AIABiAHkAIAByAGUAZgBlAHIA
# ZQBuAGMAZQAuMAsGCWCGSAGG/WwDFTAfBgNVHSMEGDAWgBQVABIrE5iymQftHt+i
# vlcNK2cCzTAdBgNVHQ4EFgQUYVpNJLZJMp1KKnkag0v0HonByn0wfQYDVR0fBHYw
# dDA4oDagNIYyaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJl
# ZElEQ0EtMS5jcmwwOKA2oDSGMmh0dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9EaWdp
# Q2VydEFzc3VyZWRJRENBLTEuY3JsMHcGCCsGAQUFBwEBBGswaTAkBggrBgEFBQcw
# AYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEEGCCsGAQUFBzAChjVodHRwOi8v
# Y2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURDQS0xLmNydDAN
# BgkqhkiG9w0BAQUFAAOCAQEAnSV+GzNNsiaBXJuGziMgD4CH5Yj//7HUaiwx7ToX
# GXEXzakbvFoWOQCd42yE5FpA+94GAYw3+puxnSR+/iCkV61bt5qwYCbqaVchXTQv
# H3Gwg5QZBWs1kBCge5fH9j/n4hFBpr1i2fAnPTgdKG86Ugnw7HBi02JLsOBzppLA
# 044x2C/jbRcTBu7kA7YUq/OPQ6dxnSHdFMoVXZJB2vkPgdGZdA0mxA5/G7X1oPHG
# dwYoFenYk+VVFvC7Cqsc21xIJ2bIo4sKHOWV2q7ELlmgYd3a822iYemKC23sEhi9
# 91VUQAOSK2vCUcIKSK+w1G7g9BQKOhvjjz3Kr2qNe9zYRDCCBs0wggW1oAMCAQIC
# EAb9+QOWA63qAArrPye7uhswDQYJKoZIhvcNAQEFBQAwZTELMAkGA1UEBhMCVVMx
# FTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNv
# bTEkMCIGA1UEAxMbRGlnaUNlcnQgQXNzdXJlZCBJRCBSb290IENBMB4XDTA2MTEx
# MDAwMDAwMFoXDTIxMTExMDAwMDAwMFowYjELMAkGA1UEBhMCVVMxFTATBgNVBAoT
# DERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEhMB8GA1UE
# AxMYRGlnaUNlcnQgQXNzdXJlZCBJRCBDQS0xMIIBIjANBgkqhkiG9w0BAQEFAAOC
# AQ8AMIIBCgKCAQEA6IItmfnKwkKVpYBzQHDSnlZUXKnE0kEGj8kz/E1FkVyBn+0s
# nPgWWd+etSQVwpi5tHdJ3InECtqvy15r7a2wcTHrzzpADEZNk+yLejYIA6sMNP4Y
# SYL+x8cxSIB8HqIPkg5QycaH6zY/2DDD/6b3+6LNb3Mj/qxWBZDwMiEWicZwiPkF
# l32jx0PdAug7Pe2xQaPtP77blUjE7h6z8rwMK5nQxl0SQoHhg26Ccz8mSxSQrllm
# CsSNvtLOBq6thG9IhJtPQLnxTPKvmPv2zkBdXPao8S+v7Iki8msYZbHBc63X8djP
# Hgp0XEK4aH631XcKJ1Z8D2KkPzIUYJX9BwSiCQIDAQABo4IDejCCA3YwDgYDVR0P
# AQH/BAQDAgGGMDsGA1UdJQQ0MDIGCCsGAQUFBwMBBggrBgEFBQcDAgYIKwYBBQUH
# AwMGCCsGAQUFBwMEBggrBgEFBQcDCDCCAdIGA1UdIASCAckwggHFMIIBtAYKYIZI
# AYb9bAABBDCCAaQwOgYIKwYBBQUHAgEWLmh0dHA6Ly93d3cuZGlnaWNlcnQuY29t
# L3NzbC1jcHMtcmVwb3NpdG9yeS5odG0wggFkBggrBgEFBQcCAjCCAVYeggFSAEEA
# bgB5ACAAdQBzAGUAIABvAGYAIAB0AGgAaQBzACAAQwBlAHIAdABpAGYAaQBjAGEA
# dABlACAAYwBvAG4AcwB0AGkAdAB1AHQAZQBzACAAYQBjAGMAZQBwAHQAYQBuAGMA
# ZQAgAG8AZgAgAHQAaABlACAARABpAGcAaQBDAGUAcgB0ACAAQwBQAC8AQwBQAFMA
# IABhAG4AZAAgAHQAaABlACAAUgBlAGwAeQBpAG4AZwAgAFAAYQByAHQAeQAgAEEA
# ZwByAGUAZQBtAGUAbgB0ACAAdwBoAGkAYwBoACAAbABpAG0AaQB0ACAAbABpAGEA
# YgBpAGwAaQB0AHkAIABhAG4AZAAgAGEAcgBlACAAaQBuAGMAbwByAHAAbwByAGEA
# dABlAGQAIABoAGUAcgBlAGkAbgAgAGIAeQAgAHIAZQBmAGUAcgBlAG4AYwBlAC4w
# CwYJYIZIAYb9bAMVMBIGA1UdEwEB/wQIMAYBAf8CAQAweQYIKwYBBQUHAQEEbTBr
# MCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wQwYIKwYBBQUH
# MAKGN2h0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJ
# RFJvb3RDQS5jcnQwgYEGA1UdHwR6MHgwOqA4oDaGNGh0dHA6Ly9jcmwzLmRpZ2lj
# ZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwOqA4oDaGNGh0dHA6
# Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmww
# HQYDVR0OBBYEFBUAEisTmLKZB+0e36K+Vw0rZwLNMB8GA1UdIwQYMBaAFEXroq/0
# ksuCMS1Ri6enIZ3zbcgPMA0GCSqGSIb3DQEBBQUAA4IBAQBGUD7Jtygkpzgdtlsp
# r1LPUukxR6tWXHvVDQtBs+/sdR90OPKyXGGinJXDUOSCuSPRujqGcq04eKx1XRcX
# NHJHhZRW0eu7NoR3zCSl8wQZVann4+erYs37iy2QwsDStZS9Xk+xBdIOPRqpFFum
# hjFiqKgz5Js5p8T1zh14dpQlc+Qqq8+cdkvtX8JLFuRLcEwAiR78xXm8TBJX/l/h
# HrwCXaj++wc4Tw3GXZG5D2dFzdaD7eeSDY2xaYxP+1ngIw/Sqq4AfO6cQg7Pkdcn
# txbuD8O9fAqg7iwIVYUiuOsYGk38KiGtSTGDR5V3cdyxG0tLHBCcdxTBnU8vWpUI
# KRAmMYIETjCCBEoCAQEwgZEwfDELMAkGA1UEBhMCR0IxGzAZBgNVBAgTEkdyZWF0
# ZXIgTWFuY2hlc3RlcjEQMA4GA1UEBxMHU2FsZm9yZDEYMBYGA1UEChMPU2VjdGln
# byBMaW1pdGVkMSQwIgYDVQQDExtTZWN0aWdvIFJTQSBDb2RlIFNpZ25pbmcgQ0EC
# EQCzbs5fgB8AS2rJIXDXR3ilMA0GCWCGSAFlAwQCAQUAoHwwEAYKKwYBBAGCNwIB
# DDECMAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEO
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIL8At0r8SI//PuessJXbYjrY
# PngEcIon86/c5y177WgvMA0GCSqGSIb3DQEBAQUABIIBAFENF2Kf67o7eqfj2qCP
# rRpELxZtQQSCSrH67AFh0HzW6zqSy0lKOOHLVCj/RINblI9m8zmzjwMYL9TFvhZI
# /rOfxUC+Ie6TQLXzJrA/C2gIaZsyyACXrgwQJFqdxFB/91w2nu21rUPcJ1CPvemP
# aR9Geol+0YVN4PLkB/chneg4NvYE8wLdcFH4oFf2YRhtJ53fSPMOm1fwDQ5rQjoY
# CtdwCFnOYACQe6h02Sm7RzA2JReSl1LG9CabbCluLHRYcqkOOkLwSO3JQxAbGCwx
# T7PCsELBCCIw6O9Tg7nBFD7NCTCjAW5W1Urw3FxXanZScEVxzTtaT8dvmoYEwDsl
# PEGhggIPMIICCwYJKoZIhvcNAQkGMYIB/DCCAfgCAQEwdjBiMQswCQYDVQQGEwJV
# UzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQu
# Y29tMSEwHwYDVQQDExhEaWdpQ2VydCBBc3N1cmVkIElEIENBLTECEAMBmgI6/1ix
# a9bV6uYX8GYwCQYFKw4DAhoFAKBdMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEw
# HAYJKoZIhvcNAQkFMQ8XDTIwMDQyNzIzMDU1M1owIwYJKoZIhvcNAQkEMRYEFCGe
# 7FBNzlL9eY9FCr7+2kmRgBddMA0GCSqGSIb3DQEBAQUABIIBABxD+Pwh5WqCiqYh
# 8EU89ys6YSN/wCI7a8EMHxhIFvaMTWTu3NISGFJN0UojofHAa4DEM/LQX8LSyVa/
# tfdrqBBQhs7EAQdehyTrrRB/y+M33irLbANlglA06MMfcp3JygeXqXlV6L6xkLdN
# jc6HVaH3Igb+KGfk9VOY9T37iKuNwobMi4+BLWtODGdmD9a5mBNdyNq+zJfC62kn
# /1fXGuhp3aDHv/g6kw/lrT0YTA2WgdHf/3Ilx9IXq01cEm4GZQV300T7RD14nUdi
# em7rHQAwAg4hnqFvWzoJIosm9/d5rlX83hP5lPzrCfRlpHG+4rTQeeM1yeINqGaH
# YPH0C28=
# SIG # End signature block
