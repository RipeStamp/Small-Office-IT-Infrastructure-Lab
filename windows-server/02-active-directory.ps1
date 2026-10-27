<#
.SYNOPSIS
    Installs Active Directory Domain Services, promotes the server to a domain
    controller, and builds the OU, user and group structure.

.DESCRIPTION
    The directory structure deliberately mirrors the VLAN segmentation from the
    Packet Tracer half of this project: the same four departments appear as
    organizational units.

    OUs and groups do different jobs. OUs organise objects and are the only
    thing a Group Policy Object can be linked to. Groups are what permissions
    are assigned to. You cannot link a GPO to a group, and you do not grant
    file access to an OU.

.NOTES
    Project : Small Office IT Infrastructure Lab
    Host    : WS2025-DC01
    Run as  : Administrator
    Warning : The server reboots automatically after promotion. Run the
              sections below the reboot marker in a new session.
#>

# ---------------------------------------------------------------------------
# 1. Install the AD DS role
# ---------------------------------------------------------------------------
# -IncludeManagementTools adds ADUC and Group Policy Management. Without it you
# get the role with no GUI way to manage it.

Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools


# ---------------------------------------------------------------------------
# 2. Promote to domain controller
# ---------------------------------------------------------------------------
# -InstallDns installs and configures DNS as part of promotion. Active Directory
# depends entirely on DNS: clients find domain controllers by querying for SRV
# records, not by broadcast. No DNS, no domain.
#
# Prompts for a DSRM (Directory Services Restore Mode) password - a recovery
# password separate from the administrator password, used to boot into a mode
# where the AD database can be repaired offline.

Install-ADDSForest -DomainName        "smalloffice.local" `
                   -DomainNetbiosName "SMALLOFFICE" `
                   -InstallDns

# >>> SERVER REBOOTS HERE. Sign back in as SMALLOFFICE\Administrator. <<<


# ---------------------------------------------------------------------------
# 3. Verify the domain
# ---------------------------------------------------------------------------
Get-ADDomain


# ---------------------------------------------------------------------------
# 4. Organizational Units
# ---------------------------------------------------------------------------
$DomainDN = "DC=smalloffice,DC=local"

New-ADOrganizationalUnit -Name "Sales" -Path $DomainDN
New-ADOrganizationalUnit -Name "HR"    -Path $DomainDN
New-ADOrganizationalUnit -Name "IT"    -Path $DomainDN

Get-ADOrganizationalUnit -Filter * | Select-Object Name, DistinguishedName


# ---------------------------------------------------------------------------
# 5. Users
# ---------------------------------------------------------------------------
# A single shared password is used here because this is a lab. In a real build
# each account gets a unique password with change-at-next-logon set, and the
# password is never written into a script.
#
# -Enabled $true is required. Accounts are created DISABLED if it is omitted -
# a common gotcha when scripting bulk user creation.

$pw = Read-Host -AsSecureString -Prompt "Enter the lab password for new accounts"

$Users = @(
    @{ Name = "Anita Rao";  Given = "Anita"; Surname = "Rao";    Sam = "arao";    OU = "Sales" }
    @{ Name = "Ben Carter"; Given = "Ben";   Surname = "Carter"; Sam = "bcarter"; OU = "Sales" }
    @{ Name = "Clara Diaz"; Given = "Clara"; Surname = "Diaz";   Sam = "cdiaz";   OU = "HR"    }
    @{ Name = "Dev Patel";  Given = "Dev";   Surname = "Patel";  Sam = "dpatel";  OU = "IT"    }
)

foreach ($u in $Users) {
    New-ADUser -Name              $u.Name `
               -GivenName         $u.Given `
               -Surname           $u.Surname `
               -SamAccountName    $u.Sam `
               -UserPrincipalName "$($u.Sam)@smalloffice.local" `
               -Path              "OU=$($u.OU),$DomainDN" `
               -AccountPassword   $pw `
               -Enabled           $true
}

Get-ADUser -Filter * -SearchBase $DomainDN |
    Select-Object Name, SamAccountName, DistinguishedName


# ---------------------------------------------------------------------------
# 6. Security groups
# ---------------------------------------------------------------------------
# -GroupCategory Security: can be assigned permissions. A Distribution group
#   cannot - it is only an email list.
# -GroupScope Global: members from this domain, usable for permissions anywhere
#   in the forest. The enterprise pattern is AGDLP - Accounts into Global
#   groups, Global into Domain Local, Domain Local gets Permissions. This lab
#   uses the simplified Global-group-direct-to-resource model, which is normal
#   at small-office scale.

$Groups = @(
    @{ Name = "Sales-Staff"; OU = "Sales"; Members = @("arao", "bcarter") }
    @{ Name = "HR-Staff";    OU = "HR";    Members = @("cdiaz")           }
    @{ Name = "IT-Staff";    OU = "IT";    Members = @("dpatel")          }
)

foreach ($g in $Groups) {
    New-ADGroup -Name          $g.Name `
                -GroupScope    Global `
                -GroupCategory Security `
                -Path          "OU=$($g.OU),$DomainDN"

    Add-ADGroupMember -Identity $g.Name -Members $g.Members

    Get-ADGroupMember -Identity $g.Name | Select-Object Name, SamAccountName
}
