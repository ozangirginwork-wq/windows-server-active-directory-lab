#Requires -RunAsAdministrator

<#
.SYNOPSIS
Validates CLIENT01 network, domain, DNS, secure-channel, and GPO configuration.
#>

[CmdletBinding()]
param(
    [string]$DomainController = 'dc01.ozanlab.test',
    [string]$ExpectedDomain = 'ozanlab.test'
)

$ComputerSystem = Get-CimInstance Win32_ComputerSystem
$Network = Get-NetIPConfiguration -InterfaceAlias 'Ethernet'

Write-Host "`n=== Client Identity ===" -ForegroundColor Cyan
[pscustomobject]@{
    ComputerName = $env:COMPUTERNAME
    Domain       = $ComputerSystem.Domain
    DomainJoined = $ComputerSystem.PartOfDomain
    Expected     = $ExpectedDomain
}

Write-Host "`n=== Network Configuration ===" -ForegroundColor Cyan
$Network | Select-Object InterfaceAlias, IPv4Address, IPv4DefaultGateway, DNSServer

Write-Host "`n=== DC Connectivity and DNS ===" -ForegroundColor Cyan
Test-Connection -ComputerName $DomainController -Count 2
Resolve-DnsName $DomainController -Type A

Write-Host "`n=== Domain Secure Channel ===" -ForegroundColor Cyan
Test-ComputerSecureChannel -Verbose

Write-Host "`n=== Applied Computer GPOs ===" -ForegroundColor Cyan
gpresult.exe /r /scope computer

Write-Host "`n=== Workstation Inactivity Timeout ===" -ForegroundColor Cyan
Get-ItemPropertyValue `
    -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' `
    -Name InactivityTimeoutSecs

