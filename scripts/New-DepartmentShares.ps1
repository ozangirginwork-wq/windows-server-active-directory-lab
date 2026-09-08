#Requires -RunAsAdministrator

<#
.SYNOPSIS
Creates department folders and SMB shares with role-based permissions.

.DESCRIPTION
Designed for the ozanlab.test training environment. Domain Admins and SYSTEM
receive Full Control. Each department group receives Modify NTFS access and
Change share access only to its matching folder. Reruns validate existing
share paths and permissions before preserving the intended access entries.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$RootPath = 'C:\Shares',
    [string]$DomainNetBIOSName = 'OZANLAB'
)

$ErrorActionPreference = 'Stop'

$Departments = [ordered]@{
    IT      = 'GG_IT_Users'
    HR      = 'GG_HR_Users'
    Finance = 'GG_Finance_Users'
    Sales   = 'GG_Sales_Users'
}

if ($PSCmdlet.ShouldProcess($RootPath, 'Create departmental share structure')) {
    New-Item -Path $RootPath -ItemType Directory -Force | Out-Null

    foreach ($Department in $Departments.GetEnumerator()) {
        $Name = $Department.Key
        $Path = Join-Path $RootPath $Name
        $Group = "$DomainNetBIOSName\$($Department.Value)"
        $DomainAdmins = "$DomainNetBIOSName\Domain Admins"

        $ExistingShare = Get-SmbShare | Where-Object Name -EQ $Name

        if ($ExistingShare) {
            $ExpectedPath = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
            $ActualPath = [System.IO.Path]::GetFullPath($ExistingShare.Path).TrimEnd('\')
            if ($ActualPath -ne $ExpectedPath) {
                throw "Share '$Name' points to '$ActualPath'; expected '$ExpectedPath'."
            }
            $UnexpectedShareAccess = Get-SmbShareAccess -Name $Name |
                Where-Object { $_.AccountName -notin @($DomainAdmins, $Group) -or $_.AccessControlType -ne 'Allow' }
            if ($UnexpectedShareAccess) {
                throw "Share '$Name' has unexpected permissions. Review them before rerunning."
            }
        }
        if (Test-Path -LiteralPath $Path) {
            $ExpectedSids = @('S-1-5-18') + @(@($DomainAdmins, $Group) | ForEach-Object {
                ([System.Security.Principal.NTAccount]::new($_)).Translate([System.Security.Principal.SecurityIdentifier]).Value
            })
            $UnexpectedAcl = (Get-Acl -LiteralPath $Path).Access | Where-Object {
                -not $_.IsInherited -and (
                    $_.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value -notin $ExpectedSids -or
                    $_.AccessControlType -ne 'Allow'
                )
            }
            if ($UnexpectedAcl) {
                throw "Folder '$Path' has unexpected explicit NTFS permissions. Review them before rerunning."
            }
        }

        New-Item -Path $Path -ItemType Directory -Force | Out-Null

        & icacls.exe $Path /inheritance:r | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Failed to disable inheritance on '$Path'." }
        & icacls.exe $Path /grant:r `
            'SYSTEM:(OI)(CI)(F)' `
            "${DomainAdmins}:(OI)(CI)(F)" `
            "${Group}:(OI)(CI)(M)" | Out-Null

        if ($LASTEXITCODE -ne 0) { throw "Failed to set NTFS permissions on '$Path'." }

        if (-not $ExistingShare) {
            New-SmbShare `
                -Name $Name `
                -Path $Path `
                -FullAccess $DomainAdmins `
                -ChangeAccess $Group | Out-Null
        }
        else {
            $ExpectedPath = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
            $ActualPath = [System.IO.Path]::GetFullPath($ExistingShare.Path).TrimEnd('\')

            if ($ActualPath -ne $ExpectedPath) {
                throw "Share '$Name' already points to '$ActualPath'; expected '$ExpectedPath'."
            }

            $ExpectedAccounts = @($DomainAdmins, $Group)
            $UnexpectedAccess = Get-SmbShareAccess -Name $Name |
                Where-Object { $_.AccountName -notin $ExpectedAccounts }

            if ($UnexpectedAccess) {
                $UnexpectedSummary = ($UnexpectedAccess |
                    ForEach-Object {
                        "$($_.AccountName) [$($_.AccessControlType):$($_.AccessRight)]"
                    }) -join ', '

                throw "Share '$Name' has unexpected access entries: $UnexpectedSummary"
            }

            Grant-SmbShareAccess `
                -Name $Name `
                -AccountName $DomainAdmins `
                -AccessRight Full `
                -Force | Out-Null

            Grant-SmbShareAccess `
                -Name $Name `
                -AccountName $Group `
                -AccessRight Change `
                -Force | Out-Null
        }

        [pscustomobject]@{
            Share       = $Name
            Path        = $Path
            AccessGroup = $Group
        }
    }
}
