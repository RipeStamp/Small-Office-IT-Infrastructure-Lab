<#
.SYNOPSIS
    Creates and links the Group Policy Objects for drive mapping and password policy.

.DESCRIPTION
    These cmdlets create the GPOs and link them, but leave them EMPTY. Group
    Policy Preferences (which handle drive mapping) are not practically exposed
    to PowerShell, so the settings themselves are configured in the Group Policy
    Management Editor. The manual steps are documented below each section.

.NOTES
    Project : Small Office IT Infrastructure Lab
    Host    : WS2025-DC01
    Run as  : Administrator
#>

$DomainDN = "DC=smalloffice,DC=local"


# ---------------------------------------------------------------------------
# 1. Drive-mapping GPOs - one per department
# ---------------------------------------------------------------------------
# Linked to the OU holding the USERS, not a computers OU, because a drive
# mapping should follow the person: whichever machine they sign in to, they get
# their department's share.

New-GPO -Name "Map Sales Drive" | New-GPLink -Target "OU=Sales,$DomainDN"
New-GPO -Name "Map HR Drive"    | New-GPLink -Target "OU=HR,$DomainDN"
New-GPO -Name "Map IT Drive"    | New-GPLink -Target "OU=IT,$DomainDN"

<#
  MANUAL STEP - configure each GPO in the editor:

    Group Policy Management -> right-click the GPO -> Edit
      User Configuration
        -> Preferences
          -> Windows Settings
            -> Drive Maps
              -> right-click -> New -> Mapped Drive

  Settings per GPO:

    GPO               Action   Drive  Location                   Label
    ---------------   ------   -----  ------------------------   -----------
    Map Sales Drive   Create   S:     \\WS2025-DC01\Sales        Sales Share
    Map HR Drive      Create   H:     \\WS2025-DC01\HR           HR Share
    Map IT Drive      Create   I:     \\WS2025-DC01\IT           IT Share

  All three with Reconnect enabled.

  On the Action setting: Create makes the mapping if absent and leaves an
  existing one alone. Update modifies one that already exists. Replace deletes
  and recreates it every time, which guarantees the settings match and is
  common in production. The dialog DEFAULTS TO UPDATE, so it must be changed.

  Note: Drive Maps live under User Configuration only. Computer Configuration
  has no Drive Maps node at all.
#>


# ---------------------------------------------------------------------------
# 2. Domain password and lockout policy
# ---------------------------------------------------------------------------
# Linked at the DOMAIN ROOT, not an OU. Password and lockout policies only take
# effect domain-wide - a GPO linked to an OU does nothing for domain account
# passwords. There is exactly one domain-wide password policy, which is why the
# built-in Default Domain Policy normally holds it.
#
# (The exception is fine-grained password policies via Password Settings
# Objects, which can target specific groups - typically to give admins stricter
# rules than everyone else.)

New-GPO -Name "Domain Password Policy" | New-GPLink -Target $DomainDN

<#
  MANUAL STEP - configure in the editor:

    Computer Configuration
      -> Policies
        -> Windows Settings
          -> Security Settings
            -> Account Policies

  Password Policy:
    Enforce password history                      5 passwords remembered
    Maximum password age                          90 days
    Minimum password age                          1 day
    Minimum password length                       12 characters
    Password must meet complexity requirements    Enabled
    Store passwords using reversible encryption   Disabled

  Account Lockout Policy:
    Account lockout threshold                     5 invalid logon attempts
    Account lockout duration                      15 minutes
    Reset account lockout counter after           15 minutes

  Why a minimum password age? Without it, a user forced to change their
  password can immediately change it five more times to cycle past the history
  requirement and return to their original password. A one-day minimum makes
  that impractical.

  Link order note: this GPO sits at the domain root with link Order 2, BELOW
  the Default Domain Policy. Where the two disagree, the Default Domain Policy
  wins. Most real environments edit the Default Domain Policy directly.
#>


# ---------------------------------------------------------------------------
# 3. Verify - exports every GPO with its settings and links
# ---------------------------------------------------------------------------
Get-GPOReport -All -ReportType Html -Path "C:\GPOReport.html"
Invoke-Item "C:\GPOReport.html"

Get-GPO -All | Select-Object DisplayName, GpoStatus, ModificationTime
