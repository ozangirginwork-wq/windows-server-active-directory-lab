#Requires -RunAsAdministrator

<#
.SYNOPSIS
Creates department folders and SMB shares with role-based permissions.

.DESCRIPTION
Designed for the ozanlab.test training environment. Domain Admins and SYSTEM
receive Full Control. Each department group receives Modify NTFS access and
Change share access only to its matching folder.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$RootPath = 'C:\Shares',
    [string]$DomainNetBIOSName = 'OZANLAB'
)

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

        New-Item -Path $Path -ItemType Directory -Force | Out-Null

        & icacls.exe $Path /inheritance:r | Out-Null
        & icacls.exe $Path /grant:r `
            'SYSTEM:(OI)(CI)(F)' `
            "${DomainAdmins}:(OI)(CI)(F)" `
            "${Group}:(OI)(CI)(M)" | Out-Null

        $ExistingShare = Get-SmbShare -Name $Name -ErrorAction SilentlyContinue

        if (-not $ExistingShare) {
            New-SmbShare `
                -Name $Name `
                -Path $Path `
                -FullAccess $DomainAdmins `
                -ChangeAccess $Group | Out-Null
        }
        else {
            Grant-SmbShareAccess -Name $Name -AccountName $DomainAdmins -AccessRight Full -Force | Out-Null
            Grant-SmbShareAccess -Name $Name -AccountName $Group -AccessRight Change -Force | Out-Null
        }

        [pscustomobject]@{
            Share       = $Name
            Path        = $Path
            AccessGroup = $Group
        }
    }
}

