<#
.SYNOPSIS
    Creates departmental SMB shares and locks them down with NTFS permissions.

.DESCRIPTION
    Share permissions and NTFS permissions are two separate gates. A user must
    pass BOTH, and the effective permission is whichever is more restrictive.

    The important difference: share permissions apply only to access over the
    network, while NTFS applies always - including to someone sitting at the
    console. Because of that, common practice is to leave share permissions
    broad and let NTFS do the real enforcement: one place to manage, and it
    covers local access too.

.NOTES
    Project : Small Office IT Infrastructure Lab
    Host    : WS2025-DC01
    Run as  : Administrator
#>

$Departments = @(
    @{ Name = "Sales"; Group = "SMALLOFFICE\Sales-Staff" }
    @{ Name = "HR";    Group = "SMALLOFFICE\HR-Staff"    }
    @{ Name = "IT";    Group = "SMALLOFFICE\IT-Staff"    }
)

foreach ($d in $Departments) {

    $Path = "C:\Shares\$($d.Name)"

    # -----------------------------------------------------------------------
    # Folder
    # -----------------------------------------------------------------------
    New-Item -Path $Path -ItemType Directory -Force

    # -----------------------------------------------------------------------
    # SMB share
    # -----------------------------------------------------------------------
    # -FullAccess   : read, write, and change permissions. Admins only.
    # -ChangeAccess : read and write, but cannot alter permissions. Normal users.
    # -ReadAccess   : read only (not used here).
    New-SmbShare -Name         $d.Name `
                 -Path         $Path `
                 -FullAccess   "SMALLOFFICE\Domain Admins" `
                 -ChangeAccess $d.Group

    # -----------------------------------------------------------------------
    # NTFS permissions
    # -----------------------------------------------------------------------
    # /inheritance:d  MUST run first. It converts inherited ACL entries into
    #                 explicit ones. Inherited entries cannot be removed
    #                 directly, so without this the next line silently fails.
    # /remove         strips BUILTIN\Users, which would otherwise let any
    #                 authenticated user browse into the folder.
    # (OI)            Object Inherit  - files inside inherit the permission
    # (CI)            Container Inherit - subfolders inherit it
    # M               Modify (read, write, delete). Others: R, RX, F.
    icacls $Path /inheritance:d
    icacls $Path /remove "BUILTIN\Users"
    icacls $Path /grant "$($d.Group):(OI)(CI)M"
}

# ---------------------------------------------------------------------------
# Verify
# ---------------------------------------------------------------------------
Get-SmbShare | Where-Object { $_.Name -in "Sales", "HR", "IT" }

foreach ($d in $Departments) {
    icacls "C:\Shares\$($d.Name)"
}
