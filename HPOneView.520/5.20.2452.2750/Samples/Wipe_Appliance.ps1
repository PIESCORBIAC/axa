##############################################################################
# Wipe_Appliance.ps1
# - Remove ALL resource from an appliance (useful to clean a system between demos).
#
#   VERSION 3.00
#
# (C) Copyright 2013-2020 Hewlett Packard Enterprise Development LP 
##############################################################################
# The information contained herein is subject to change without notice. 
# The only warranties for HP products and services are set forth in the 
# express warranty statements accompanying such products and services. 
# Nothing herein should be construed as constituting an additional warranty. 
# HP shall not be liable for technical or editorial errors or omissions 
# contained herein.
#
##############################################################################
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param
(

    [Parameter (Mandatory)]
    [ValidateNotNullorEmpty()]
    [String]$Hostname,

    [Parameter (Mandatory)]
    [ValidateNotNullorEmpty()]
    [String]$Username,

    [Parameter (Mandatory)]
    [ValidateNotNullorEmpty()]
    [Object]$Password

)

if ($PSCmdlet.ShouldProcess($Hostname,("remove all resources on appliance")))
{   

    if (! (Get-Module -Name 'HPOneView.410')) 
    {
        
        Import-Module HPOneView.410

    }

    # First connect to the CI Management Appliance (if not already connected)
    if (! $ConnectedSessions) 
    {

        Try
        {

            $Params = @{

                Hostname = $Hostname;
                Username = $Username;
                Password = $Password

            }

            Connect-HPOVMgmt @Params

        }

        Catch
        {

            PSCmdlet.ThrowTerminatingError($_)

        }            

    }

    Try
    {

        ############################################################
        #  REMOVE CONFIGURATION (for cleanup after/between demos)  #
        ############################################################

        # Delete ALL Server Profiles
        $tasks = Get-HPOVServerProfile | Remove-HPOVServerProfile -Force -Confirm:$false | Wait-HPOVTaskComplete

        if ($tasks | ? taskState -ne 'Completed') { 

            $Tasks | ? taskState -ne 'Completed' | Format-List

            Write-Error '1 or more Remove Server Profile tasks failed to complete successfully.' -ErrorAction Stop

        }

        # Delete ALL Server Profile Templates
        $tasks = Get-HPOVServerProfileTemplate | Remove-HPOVServerProfileTemplate -Confirm:$false | Wait-HPOVTaskComplete

        if ($tasks | ? taskState -ne 'Completed') { 

            $Tasks | ? taskState -ne 'Completed' | Format-List

            Write-Error '1 or more Remove Server Profile Template tasks failed to complete successfully.' -ErrorAction Stop

        }

        # Remove ALL iPDUs
        $tasks = Get-HPOVPowerDevice | Remove-HPOVPowerDevice -Force -Confirm:$false | Wait-HPOVTaskComplete

        if ($tasks | ? taskState -ne 'Completed') { 

            $Tasks | ? taskState -ne 'Completed' | Format-List
            
            Write-Error '1 or more Remove Power Device tasks failed to complete successfully.' -ErrorAction Stop

        }

        # Remove ALL Enclosures
        $tasks = Get-HPOVEnclosure | Remove-HPOVEnclosure -Force -Confirm:$false | Wait-HPOVTaskComplete

        if ($tasks | ? taskState -ne 'Completed') { 

            $Tasks | ? taskState -ne 'Completed' | Format-List
            
            Write-Error '1 or more Remove Enclosure tasks failed to complete successfully.' -ErrorAction Stop

        }

        # Remove ALL Rack Servers
        $tasks = Get-HPOVServer | Remove-HPOVServer -Force -Confirm:$false | Wait-HPOVTaskComplete

        if ($tasks | ? taskState -ne 'Completed') { 

            $Tasks | ? taskState -ne 'Completed' | Format-List
            
            Write-Error '1 or more Remove Server Hardware Resources tasks failed to complete successfully.' -ErrorAction Stop

        }

        # Delete ALL Enclosure Groups:
        $tasks = Get-HPOVEnclosureGroup | Remove-HPOVEnclosureGroup -Force -Confirm:$false
        
        if ($tasks | ? Message -ne 'Resource deleted successfully.') { 

            $Tasks | ? Message -ne 'Resource deleted successfully.' | Format-List
            
            Write-Error '1 or more Remove Enclosure Group requests failed to complete successfully.' -ErrorAction Stop

        }

        # Delete ALL Logical Interconnect Groups
        $tasks = Get-HPOVLogicalInterconnectGroup | Remove-HPOVLogicalInterconnectGroup -Force -Confirm:$false | Wait-HPOVTaskComplete

        if ($tasks | ? taskState -ne 'Completed') { 

            $Tasks | ? taskState -ne 'Completed' | Format-List
            
            Write-Error '1 or more Remove Logical Interconnect Group tasks failed to complete successfully.' -ErrorAction Stop

        }

        # Delete ALL Network-Sets
        $tasks = Get-HPOVNetworkSet | Remove-HPOVNetworkSet -Confirm:$false | Wait-HPOVTaskComplete

        if ($tasks | ? taskState -ne 'Completed') { 

            $Tasks | ? taskState -ne 'Completed' | Format-List
            
            Write-Error '1 or more Remove Network Set tasks failed to complete successfully.' -ErrorAction Stop

        }

        # Delete ALL Networks
        $tasks = Get-HPOVNetwork | Remove-HPOVNetwork -Confirm:$false | Wait-HPOVTaskComplete

        if ($tasks | ? taskState -ne 'Completed') { 

            $Tasks | ? taskState -ne 'Completed' | Format-List
            
            Write-Error '1 or more Remove Network tasks failed to complete successfully.' -ErrorAction Stop

        }

        # Delete ALL Storage Volumes
        $tasks = Get-HPOVStorageVolume | Remove-HPOVStorageVolume -Force -Confirm:$false | Wait-HPOVTaskComplete

        if ($tasks | ? taskState -ne 'Completed') { 

            $Tasks | ? taskState -ne 'Completed' | Format-List
            
            Write-Error '1 or more Remove Storage Volume tasks failed to complete successfully.' -ErrorAction Stop

        }

        # Delete ALL Storage Pools
        $tasks = Get-HPOVStoragePool | Remove-HPOVStoragePool -Force -Confirm:$false | Wait-HPOVTaskComplete

        if ($tasks | ? taskState -ne 'Completed') { 

            $Tasks | ? taskState -ne 'Completed' | Format-List
            
            Write-Error '1 or more Remove Storage Pool tasks failed to complete successfully.' -ErrorAction Stop

        }

        # Delete ALL Storage Systems
        $tasks = Get-HPOVStorageSYstem | Remove-HPOVStorageSystem -Force -Confirm:$false | Wait-HPOVTaskComplete

        if ($tasks | ? taskState -ne 'Completed') { 

            $Tasks | ? taskState -ne 'Completed' | Format-List
            
            Write-Error '1 or more Remove Storage System tasks failed to complete successfully.' -ErrorAction Stop

        }

        # Delete ALL SAN Managers
        $tasks = Get-HPOVSanManager | Remove-HPOVSanManager -Confirm:$false | Wait-HPOVTaskComplete

        if ($tasks | ? taskState -ne 'Completed') { 

            $Tasks | ? taskState -ne 'Completed' | Format-List
            
            Write-Error '1 or more Remove SAN Manager tasks failed to complete successfully.' -ErrorAction Stop

        }

        # Delete ALL Unmanaged Devices
        $tasks = Get-HPOVUnmanagedDevice | Remove-HPOVUnmanagedDevice -Force -Confirm:$false
        
        if ($tasks | ? Message -ne 'Resource deleted successfully.') { 

            $Tasks | ? Message -ne 'Resource deleted successfully.' | Format-List
            
            Write-Error '1 or more Remove Unmanaged Device requests failed to complete successfully.' -ErrorAction Stop

        }

    }

    Catch
    {

        $PSCmdlet.ThrowTerminatingError($_)

    }

}

elseif ($PSBoundParameters['Whatif'])
{

    "[{0}] -WhatIf provided." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

}

else
{

    "[{0}] User cancelled." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

}
# SIG # Begin signature block
# MIIjGQYJKoZIhvcNAQcCoIIjCjCCIwYCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCC6i+e/UJeXDNGC
# n1Jw4MZFMe+Hfc12Yb1law2VvwrAmqCCHiIwggVhMIIESaADAgECAhB2TE55PkNI
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgyptMB/vFZnHP
# wAzldSvgVydCIOFfh00x8Gh7MOhT1FswDQYJKoZIhvcNAQEBBQAEggEANHZmYxsy
# 44IgUHsSM/lTy4sO+ekXl9eoR5O3yEqTlF6oPB3wxDAPe8RgvGVfwd3zg2DHYvod
# LnjvsphI8Qs9aej0nNSJ3+bb/Wwgez7ZfyPqkPFBSw5BrvJby6zvPvtIrX3apkvX
# Kgox3VNqfWIas55wZ5V2YSbFsdfJjhQYFBc1Ttt5LjlIMmm9H8QRQ6Skw1WHl8rO
# Xi+vFjVgzr9+zZaheDUHLuphb80N7i4QeE6hLr/4NiU/xBHejbUvL7iONwnZvtqs
# jJJoYoyU9a8l8N11v9Nmt9Jj3glYWssPAM2yMKLrEo/00eSXxh1DhqKcxY4CEdgj
# TJm3Kb0QEgNfw6GCAg8wggILBgkqhkiG9w0BCQYxggH8MIIB+AIBATB2MGIxCzAJ
# BgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5k
# aWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0IEFzc3VyZWQgSUQgQ0EtMQIQ
# AwGaAjr/WLFr1tXq5hfwZjAJBgUrDgMCGgUAoF0wGAYJKoZIhvcNAQkDMQsGCSqG
# SIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMjAwNjE5MjM1NzMzWjAjBgkqhkiG9w0B
# CQQxFgQUhy6p6AKhqYf4lzw3tmHXkSTNi7MwDQYJKoZIhvcNAQEBBQAEggEAYsJ0
# +eul/cdfey6pjAiemsYU5xB65/gyTjlW6fnwTBm+u8UMB/wFMeGWP/bawukcb+NJ
# NypYet5TLjdvcWRkyGWu7rrehdsDHldyORGSzCuW1JRFFAW6orX7SIJGHuJ+tKmf
# lw9x5LoM3N94ptUxO9UVemzwDIfy1Jl8n6Crof1BISHwVRCmnQM0UWSHBw6pnN1z
# 68ULM45noqnfLuRr8M+2tW1+hC6MXGvtEF+nVO8humzgSUAUh7xtogXckgR+IDKc
# zKJB4YnG2+oQj6jDY5Ra4ZM5+4k4aGz3didF0i3jWdSLuS8AqSMeU1Nmgl+Tf72F
# PYHyhL8nYfHcFA3yqQ==
# SIG # End signature block
