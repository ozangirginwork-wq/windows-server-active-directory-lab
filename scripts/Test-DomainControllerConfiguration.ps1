#Requires -RunAsAdministrator
#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
Collects validation evidence from the OzanLab domain controller.
#>

[CmdletBinding()]
param(
    [string]$DomainDistinguishedName = 'DC=ozanlab,DC=test',
    [string]$LabOUDistinguishedName = 'OU=OzanLab,DC=ozanlab,DC=test'
)

Write-Host "`n=== Domain ===" -ForegroundColor Cyan
Get-ADDomain | Select-Object DNSRoot, NetBIOSName, DomainMode, PDCEmulator

Write-Host "`n=== DNS ===" -ForegroundColor Cyan
Resolve-DnsName 'dc01.ozanlab.test' -Type A

Write-Host "`n=== OzanLab Organizational Units ===" -ForegroundColor Cyan
Get-ADOrganizationalUnit -Filter * -SearchBase $LabOUDistinguishedName |
    Sort-Object DistinguishedName |
    Select-Object Name, DistinguishedName

Write-Host "`n=== Department Users ===" -ForegroundColor Cyan
Get-ADUser -Filter * -SearchBase "OU=Users,$LabOUDistinguishedName" |
    Sort-Object Name |
    Select-Object Name, SamAccountName, Enabled, DistinguishedName

Write-Host "`n=== Department Group Membership ===" -ForegroundColor Cyan
'GG_IT_Users', 'GG_HR_Users', 'GG_Finance_Users', 'GG_Sales_Users' |
    ForEach-Object {
        $GroupName = $_
        Get-ADGroupMember -Identity $GroupName |
            Select-Object @{Name = 'Group'; Expression = { $GroupName }}, Name, SamAccountName
    }

Write-Host "`n=== Effective Domain Password and Lockout Policy ===" -ForegroundColor Cyan
Get-ADDefaultDomainPasswordPolicy |
    Select-Object MinPasswordLength, PasswordHistoryCount, MaxPasswordAge,
        ComplexityEnabled, LockoutThreshold, LockoutDuration, LockoutObservationWindow

Write-Host "`n=== Department SMB Shares ===" -ForegroundColor Cyan
Get-SmbShare |
    Where-Object Name -In 'IT', 'HR', 'Finance', 'Sales' |
    Sort-Object Name |
    Select-Object Name, Path

Write-Host "`n=== Share Permissions ===" -ForegroundColor Cyan
'IT', 'HR', 'Finance', 'Sales' |
    ForEach-Object { Get-SmbShareAccess -Name $_ } |
    Select-Object Name, AccountName, AccessControlType, AccessRight

