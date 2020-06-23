﻿##############################################################################
# Server_Multiconnection_SAN_Storage_Sample.ps1
#
# Example script to demonstrate creating a Server Profile with the following:
#
# - Configure 2 NICs in paired with Red
# - Configure 2 NICs in paired with Black
# - Configure 2 NICs in paired with NetworkSet (Production Networks)
# - Configure 2 FC connections to the Production Fabric A and B            
# - Set requested bandwidth
# - Attach SAN Storage
#
#   VERSION 3.1
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
if (-not (get-module HPOneView.410)) 
{

    Import-Module HPOneView.410

}

if (-not $ConnectedSessions) 
{

	$Appliance = Read-Host 'ApplianceName'
	$Username  = Read-Host 'Username'
	$Password  = Read-Host 'Password' -AsSecureString

    $ApplianceConnection = Connect-HPOVMgmt -Hostname $Appliance -Username $Username -Password $Password

}

# Now view what enclosures have been imported
Write-Host "Here is the list of enclosures managed by this appliance"
Get-HPOVEnclosure

# Now list all the servers that have been imported with their current state
$servers = Get-HPOVServer
Write-Host "There are [$servers.Count] servers managed by this appliance."
Get-HPOVServer

# Make sure all the servers are powered off
$servers | % {
    if ($_.powerState -ne "Off") {
        Write-Host "Server '$_.name' is ($_.powerState).  Powering off..."
        $Server | Stop-HPOVServer -Confirm:$false
    }
}

# Now create a server profile for the first available server
$server = Get-HPOVServer -NoProfile | Select -First 1

$profileName = "Profile-" + $server.serialNumber
Write-Host "Creating" $profileName "for server" $server.name

# Assume that networks "red" and "blue" are available for this server
$netRed = Get-HPOVNetwork "red"
$conRed1 = New-HPOVProfileConnection -id 1 -type Ethernet -requestedBW 1000 -network $netRed
$conRed2 = New-HPOVProfileConnection -id 2 -type Ethernet -requestedBW 1000 -network $netRed

$netProdFCA = Get-HPOVNetwork "Production Fabric A"
$conFC1 = New-HPOVProfileConnection -id 3 -type FibreChannel -requestedBW 4000 -network $netProdFCA
$netProdFCB = Get-HPOVNetwork "Production Fabric B"
$conFC2 = New-HPOVProfileConnection -id 4 -type FibreChannel -requestedBW 4000 -network $netProdFCB

$netBlack = Get-HPOVNetwork "black"
$conBlack1 = New-HPOVProfileConnection -id 5 -type Ethernet -requestedBW 2000 -network $netBlack
$conBlack2 = New-HPOVProfileConnection -id 6 -type Ethernet -requestedBW 2000 -network $netBlack

$netSetProd = Get-HPOVNetworkSet "Production Networks"
$conSet1 = New-HPOVProfileConnection -id 7 -type Ethernet -requestedBW 3000 -network $netSetProd
$conSet2 = New-HPOVProfileConnection -id 8 -type Ethernet -requestedBW 3000 -network $netSetProd

#Build array of connections for the profile
$conList = @($conRed1, $conRed2, $conBlack1, $conBlack2, $conSet1, $conSet2, $conFC1, $conFC2)

#Attach Volumes
$volume1 = Get-HPOVStorageVolume -Name Volume1 | Get-HPOVProfileAttachVolume -volumeid 1
$volume2 = Get-HPOVStorageVolume -Name SharedVolume1 | Get-HPOVProfileAttachVolume -volumeid 2
$attachVolumes = @($volume1,$volume2)

#Submit profile to the appliance
$task = New-HPOVProfile -name $profileName -server $server -connections $conList -SANStorage -HostOsType VMware -StorageVolume $attachVolumes -Async

#Monitor the profile async task progress
Write-Host $task.name $task.taskStatus
$task = $task | Wait-HPOVTaskComplete


# Change Connection ID 5 and 6 to "green" in the profile we just created
$profile = Send-HPOVRequest $task.associatedResource.resourceUri
Write-Host "Adding network to" $profile.name
    
#Validate the Server Power is off prior to modifying Connections (Requirement for 1.00 and 1.01)
if ($server.powerState -ne "Off") {
    Write-Host "Server" $server.name "is" $server.powerState ".  Powering it off..."
    $Server | Stop-HPOVServer -Confirm:$false
}

$netGreen = Get-HPOVNetwork "green"
$conGreen1 = New-HPOVProfileConnection -connectionId 5 -type Ethernet -network $netGreen
$conGreen2 = New-HPOVProfileConnection -connectionId 6 -type Ethernet -network $netGreen
$profile.connections = $profile.connections + $conGreen1 + $conGreen2
$task = Set-HPOVResource $profile
$task = Wait-HPOVTaskComplete -taskUri $task.uri

# Display the connections for our profile
$profile = Send-HPOVRequest $task.associatedResource.resourceUri
$profile.connections | Format-Table

# ADVANCED SERVER SETTINGS
# First view the capabilities of the server hardware for this profile
$serverType = Send-HPOVRequest $profile.serverHardwareTypeUri
Write-Host "Boot options for this server:" $serverType.bootCapabilities

# Set the boot order for the server
$profile.boot.order = @("PXE", "HardDisk", "USB", "CD", "Floppy", "FibreChannelHba")
$profile.boot.manageBoot = $true
Write-Host "Set boot order to" $profile.boot.order

#Set the BIOS setting to disable external USB ports
Write-Host "There are" $serverType.biosSettings.Count "possible BIOS settings for this server"
foreach ($setting in $serverType.biosSettings) {
    if ($setting.name.Contains("USB Control")) { 
        foreach ($option in $setting.options) {
            if ($option.name.Contains("External")) {
                $profile.bios.manageBios = $true
                $profile.bios.overriddenSettings = 
                    @(@{id=$setting.id;value=$option.id})
                Write-Host $setting.name ":" $option.name
                break
            }
        }
        break
        }
    }

# Let's update the profile with boot order and BIOS settings and validate the result
$task = Set-HPOVResource $profile
$task = Wait-HPOVTaskComplete -Task $task -timeout (New-TimeSpan -Minutes 20)
$profile = Send-HPOVRequest $task.associatedResource.resourceUri

# Now update the firmware of the profile.  
# List available SPP's on the appliance
Get-HPOVBaseline

$sppFileName = Read-Host "Which SPP file do you want to select ('SPP*.iso'), or <Enter> to skip firmware"
if ($sppFileName) {
    $fw = Get-HPOVBaseline -FileName $sppFileName
    # Now select the firmware SPP in the server profile
    if ($serverType.firmwareUpdateSupported) {
        $profile.firmwareSettings.manageFirmware = $true
        $profile.firmwareSettings.firmwareBaselineUri = $fw.uri
        $task = Set-HPOVResource $profile
        $task = Wait-HPOVTaskComplete -taskUri $task.uri -timeout (New-TimeSpan -Minutes 30)

    } else {
        Write-Host "Firmware update not supported for" $serverType.model
    }
}
# SIG # Begin signature block
# MIIjGQYJKoZIhvcNAQcCoIIjCjCCIwYCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB9F5Av/ouKPz35
# 1i39yCq4eThWjHQ3T5HobO9LNce1MKCCHiIwggVhMIIESaADAgECAhB2TE55PkNI
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgOFxX1LyKVlVG
# jm965WYejwO+NLsq9N4naoVsmgvYteUwDQYJKoZIhvcNAQEBBQAEggEAj0HnVyeR
# MO4ujY9l1P0D1c8n2JbVMSCHsxc4UC38K+jSNuVVlacEhLViSg5fpUCBwECi8HGb
# EbJCpA+uIxOq28HqAEGNZcy9o2ahW1p7FPa3RRH6QCc4Hi6C4SG9eMnfYGTtawY4
# JAHeAF9viazL4s5pPKjnMEyoekDsNRv7YGVsSptcDBEJGknalQuJqRlltKXq12Iw
# ewbNYbU+62EteUdDZBWCLAxTheBa0MMy0pPSs1Sm+2ZmqBunN04ZVmcyfD9seqWn
# t1ZYRGlVclt2uQuviEplZrt14hV2ISHNzb3sjT+fQ7bgt5VaNdmnkeGDsIN28CiU
# cmq58Ano6XUKRKGCAg8wggILBgkqhkiG9w0BCQYxggH8MIIB+AIBATB2MGIxCzAJ
# BgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5k
# aWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0IEFzc3VyZWQgSUQgQ0EtMQIQ
# AwGaAjr/WLFr1tXq5hfwZjAJBgUrDgMCGgUAoF0wGAYJKoZIhvcNAQkDMQsGCSqG
# SIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMjAwNjE5MjM1NjE0WjAjBgkqhkiG9w0B
# CQQxFgQUGluxOHOykwNpY17IE9sYWPOeuiswDQYJKoZIhvcNAQEBBQAEggEAbFx8
# 96pjkZ9xuBVwtecPzwoSeZwjdXmbaHgWEgSeAVPYt/93W7VXjLz75bSXnyOH2Rjt
# XBUGkXChy1J7fuNAsAU9pWd+/VRE5R1iPrZ2caPvaW4hhj1W/ULQVFdYQZ+6w5Cp
# dpNalLMsHN/wAUuWXQNIsGZkTxn1c6Ls1MKx9J4imWPIJ7mLPuBhofaFyTjzFeUz
# hZ0j/wggf2Rc9p363pAiT2QmEwLI5/D+MZn3QH1NlY6JXV9HUyUBoQSIpXs6GwtM
# +CuMZpVa1AsWIJ37Y5BSPr6AXCl484s1sAJEARCHrLEBO9Bx9Q/qZCypCSyvm9Eu
# Qo/Na0aoHjTvcciREA==
# SIG # End signature block
