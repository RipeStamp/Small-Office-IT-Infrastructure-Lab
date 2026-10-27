# Small Office IT Infrastructure Lab — Project Log

## Project overview

Building a small-office IT infrastructure lab to demonstrate practical skills for **Office Admin**, **Network Support Engineer**, and general **IT** roles, building on 2 years of experience as a Technical Support Representative.

**Tools used:**

- VirtualBox (host virtualization)
- Cisco Packet Tracer (network simulation)

**Scope — two phases that mirror each other.** Phase 1 builds a simulated small-office network in Cisco Packet Tracer: four departments (Sales, HR, IT, Servers), each on its own VLAN, routed through a single router, with DHCP addressing and an access control list enforcing a security boundary. Phase 2 builds the matching Windows environment in VirtualBox: a Windows Server 2025 domain controller running Active Directory, with organizational units, users and security groups mirroring the same four departments, plus file shares secured by NTFS permissions and Group Policy for drive mapping and password policy.

The departmental structure is deliberately the same on both sides — four VLANs, the same departments as OUs — so the network design and the directory design describe one organisation rather than two unrelated exercises.

## Phase 1 — Network design

One router (Router0) connects to one switch (Switch0) via a trunk link. The switch distributes four VLANs to end devices: Sales, HR, IT (plus a printer), and Servers.

| VLAN | Department | Subnet | Gateway |
| --- | --- | --- | --- |
| 10 | Sales | 192.168.10.0/24 | 192.168.10.1 |
| 20 | HR | 192.168.20.0/24 | 192.168.20.1 |
| 30 | IT | 192.168.30.0/24 | 192.168.30.1 |
| 99 | Servers | 192.168.99.0/24 | 192.168.99.1 |

**Device-to-port mapping (Switch0):**

| Port | Device | VLAN |
| --- | --- | --- |
| Fa0/1 | PC0 | 10 (Sales) |
| Fa0/2 | PC1 | 10 (Sales) |
| Fa0/3 | PC2 | 20 (HR) |
| Fa0/4 | PC3 | 20 (HR) |
| Fa0/5 | PC4 | 30 (IT) |
| Fa0/6 | PC5 | 30 (IT) |
| Fa0/7 | Printer0 | 30 (IT) |
| Fa0/8 | PC6 | 99 (Servers) |
| Fa0/9 | PC7 | 99 (Servers) |
| Fa0/10 | Server0 | 99 (Servers) |
| Gig0/1 | Router0 (Gig0/0) | Trunk (10,20,30,99) |

## Phase 1 — Switch configuration

All commands run on Switch0.

**Create VLANs:**

```
enable
configure terminal
vlan 10
 name SALES
 exit
vlan 20
 name HR
 exit
vlan 30
 name IT
 exit
vlan 99
 name SERVERS
 exit
```

**Assign access ports to VLANs:**

```
interface range fa0/1 - 2
 switchport mode access
 switchport access vlan 10
 exit
interface range fa0/3 - 4
 switchport mode access
 switchport access vlan 20
 exit
interface range fa0/5 - 7
 switchport mode access
 switchport access vlan 30
 exit
interface range fa0/8 - 10
 switchport mode access
 switchport access vlan 99
 exit
```

**Trunk to the router:**

```
interface gig0/1
 switchport mode trunk
 switchport trunk allowed vlan 10,20,30,99
 exit
end
copy running-config startup-config
```

**Verification commands used:**

- `show vlan brief` — confirms each port sits under the correct VLAN
- `show interfaces gig0/1 switchport` — confirms trunk mode and allowed VLANs (used instead of `show interfaces trunk`, which stays blank until the router side is also up)

## Phase 1 — Router configuration

All commands run on Router0.

**Sub-interfaces (router-on-a-stick):**

```
enable
configure terminal
interface gig0/0
 no shutdown
 exit
interface gig0/0.10
 encapsulation dot1Q 10
 ip address 192.168.10.1 255.255.255.0
 exit
interface gig0/0.20
 encapsulation dot1Q 20
 ip address 192.168.20.1 255.255.255.0
 exit
interface gig0/0.30
 encapsulation dot1Q 30
 ip address 192.168.30.1 255.255.255.0
 exit
interface gig0/0.99
 encapsulation dot1Q 99
 ip address 192.168.99.1 255.255.255.0
 exit
end
copy running-config startup-config
```

**DHCP pools (one per VLAN):**

```
configure terminal
ip dhcp excluded-address 192.168.10.1 192.168.10.10
ip dhcp excluded-address 192.168.20.1 192.168.20.10
ip dhcp excluded-address 192.168.30.1 192.168.30.10
ip dhcp excluded-address 192.168.99.1 192.168.99.10

ip dhcp pool SALES
 network 192.168.10.0 255.255.255.0
 default-router 192.168.10.1
 dns-server 8.8.8.8
 exit
ip dhcp pool HR
 network 192.168.20.0 255.255.255.0
 default-router 192.168.20.1
 dns-server 8.8.8.8
 exit
ip dhcp pool IT
 network 192.168.30.0 255.255.255.0
 default-router 192.168.30.1
 dns-server 8.8.8.8
 exit
ip dhcp pool SERVERS
 network 192.168.99.0 255.255.255.0
 default-router 192.168.99.1
 dns-server 8.8.8.8
 exit
end
copy running-config startup-config
```

**Verification:** `show ip interface brief` — confirms all four sub-interfaces are up/up with the correct IPs.

**DHCP verification results — all 10 devices:**

| Device | VLAN | Address received | Gateway |
| --- | --- | --- | --- |
| PC0 | 10 (Sales) | 192.168.10.11 | 192.168.10.1 |
| PC1 | 10 (Sales) | 192.168.10.12 | 192.168.10.1 |
| PC2 | 20 (HR) | 192.168.20.11 | 192.168.20.1 |
| PC3 | 20 (HR) | 192.168.20.12 | 192.168.20.1 |
| PC4 | 30 (IT) | 192.168.30.11 | 192.168.30.1 |
| PC5 | 30 (IT) | 192.168.30.12 | 192.168.30.1 |
| Printer0 | 30 (IT) | 192.168.30.13 | 192.168.30.1 |
| PC6 | 99 (Servers) | 192.168.99.11 | 192.168.99.1 |
| PC7 | 99 (Servers) | 192.168.99.12 | 192.168.99.1 |
| Server0 | 99 (Servers) | 192.168.99.13 | 192.168.99.1 |

All devices received DNS 8.8.8.8. Addressing starts at .11 in each subnet, confirming the .1–.10 exclusions held. PCs configure DHCP under Desktop → IP Configuration; the printer and server use Config → FastEthernet0.

**Inter-VLAN routing tests (run from PC0, Sales, 192.168.10.11):**

| Target | Result | Reading |
| --- | --- | --- |
| 192.168.20.11 (PC2, HR) | 3/4 replies, <1ms, TTL=127 | Sales → HR routing works |
| 192.168.99.13 (Server0, Servers) | 3/4 replies, <1ms–5ms, TTL=127 | Sales → Servers routing works |
| 192.169.20.11 (typo — not a real subnet) | 0/4, "Destination host unreachable" from 192.168.10.1 | Router found no route and said so |

The single initial timeout on each successful ping is ARP resolution, not a fault — the first packet is sent before the MAC address is known, and reopening the Command Prompt resets the ARP cache. Re-running the same ping within one session returned 4/4 replies with 0% loss, confirming this. TTL=127 rather than 128 confirms traffic crossed exactly one router hop.

The failed ping was a useful accident: it shows the difference between the two main ping failures. "Request timed out" means the packet left but nothing answered. "Destination host unreachable", replied by the gateway itself, means the router checked its routing table and found no path at all.

### Access control list (ACL)

An extended ACL blocks the Sales VLAN from reaching the Servers VLAN, while leaving all other paths open.

```
enable
configure terminal
access-list 110 deny ip 192.168.10.0 0.0.0.255 192.168.99.0 0.0.0.255
access-list 110 permit ip any any
interface gig0/0.10
 ip access-group 110 in
 exit
end
copy running-config startup-config
```

**Test results from PC0 (Sales):**

| Target | Result | Meaning |
| --- | --- | --- |
| 192.168.99.13 (Server0) | 0/4, "Destination host unreachable" from 192.168.10.1 | Blocked by the ACL, as intended |
| 192.168.20.11 (HR) | 4/4, 0% loss | Unaffected |
| 192.168.30.11 (IT) | 3/4 (first timeout = ARP) | Unaffected |

**Notes on the syntax:**

- Extended ACLs (100–199) match on both source and destination; standard ACLs (1–99) match source only, which would not work here.
- `0.0.0.255` is a wildcard mask, the inverse of a subnet mask: 0 means "must match", 255 means "don't care".
- `permit ip any any` is mandatory — every ACL ends with an implicit deny-all, so without it Sales would lose all connectivity including DHCP.
- Applied inbound on the Sales sub-interface: extended ACLs are best placed close to the traffic source so unwanted traffic is dropped early.
- A blocked packet returns "Destination host unreachable" from the gateway rather than timing out — the router actively rejects and notifies, rather than silently dropping.

## Phase 2 — Windows Server 2025 and Active Directory

Built in VirtualBox on the same host, alongside the Packet Tracer network.

**VM configuration:**

| Setting | Value |
| --- | --- |
| Name | WS2025-DC01 |
| OS | Windows Server 2025 Standard (Desktop Experience), Evaluation |
| RAM / CPU | 4096 MB / 2 cores |
| Disk | 50 GB VDI, dynamically allocated |
| Network | NAT adapter |
| Static IP | 10.0.2.15 /24, gateway 10.0.2.2, DNS 8.8.8.8 |

A domain controller needs a static IP: domain-joined clients locate the DC through DNS, and the DC is itself the DNS server, so a changing address would break logins across the domain.

**Network configuration (PowerShell):**

```
Remove-NetIPAddress -InterfaceAlias "Ethernet" -Confirm:$false
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 10.0.2.15 -PrefixLength 24 -DefaultGateway 10.0.2.2
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 8.8.8.8
```

**Installing and promoting Active Directory:**

```
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
Install-ADDSForest -DomainName "smalloffice.local" -DomainNetbiosName "SMALLOFFICE" -InstallDns
```

Promotion prompts for a DSRM (Directory Services Restore Mode) password, separate from the administrator password, and reboots automatically on completion. The `-InstallDns` flag installs and configures DNS as part of promotion, because AD depends on DNS for clients to locate domain controllers.

**Verification — `Get-ADDomain`:**

| Property | Value |
| --- | --- |
| DNSRoot | smalloffice.local |
| NetBIOSName | SMALLOFFICE |
| DistinguishedName | DC=smalloffice,DC=local |
| DomainMode | Windows2025Domain |
| FSMO roles | All five held by WS2025-DC01 (single-DC domain) |

**Organizational Units:**

```
New-ADOrganizationalUnit -Name "Sales" -Path "DC=smalloffice,DC=local"
New-ADOrganizationalUnit -Name "HR" -Path "DC=smalloffice,DC=local"
New-ADOrganizationalUnit -Name "IT" -Path "DC=smalloffice,DC=local"
```

The OUs deliberately mirror the VLANs from the Packet Tracer build — the same departmental structure, expressed in the directory rather than the network.

**Users:**

```
$pw = ConvertTo-SecureString "<password>" -AsPlainText -Force
New-ADUser -Name "Anita Rao" -GivenName "Anita" -Surname "Rao" -SamAccountName "arao" -UserPrincipalName "arao@smalloffice.local" -Path "OU=Sales,DC=smalloffice,DC=local" -AccountPassword $pw -Enabled $true
```

(Repeated for each user with their own details and OU path.)

| User | Account | OU |
| --- | --- | --- |
| Anita Rao | arao | Sales |
| Ben Carter | bcarter | Sales |
| Clara Diaz | cdiaz | HR |
| Dev Patel | dpatel | IT |

`-Enabled $true` matters: accounts are created disabled if it is omitted, a common gotcha when scripting bulk user creation.

**Security groups:**

```
New-ADGroup -Name "Sales-Staff" -GroupScope Global -GroupCategory Security -Path "OU=Sales,DC=smalloffice,DC=local"
Add-ADGroupMember -Identity "Sales-Staff" -Members arao,bcarter
```

(Repeated for HR-Staff and IT-Staff.)

| Group | Members |
| --- | --- |
| Sales-Staff | Anita Rao, Ben Carter |
| HR-Staff | Clara Diaz |
| IT-Staff | Dev Patel |

OUs and groups do different jobs: OUs organise objects and are where Group Policy is applied; groups are what permissions are assigned to.

### Departmental file shares

Three shared folders, one per department, each restricted to its own security group.

```
New-Item -Path "C:\Shares\Sales" -ItemType Directory
New-Item -Path "C:\Shares\HR" -ItemType Directory
New-Item -Path "C:\Shares\IT" -ItemType Directory

New-SmbShare -Name "Sales" -Path "C:\Shares\Sales" -FullAccess "SMALLOFFICE\Domain Admins" -ChangeAccess "SMALLOFFICE\Sales-Staff"
New-SmbShare -Name "HR" -Path "C:\Shares\HR" -FullAccess "SMALLOFFICE\Domain Admins" -ChangeAccess "SMALLOFFICE\HR-Staff"
New-SmbShare -Name "IT" -Path "C:\Shares\IT" -FullAccess "SMALLOFFICE\Domain Admins" -ChangeAccess "SMALLOFFICE\IT-Staff"
```

NTFS permissions, applied per folder (shown for Sales; repeated for HR and IT with their own group names):

```
icacls "C:\Shares\Sales" /inheritance:d
icacls "C:\Shares\Sales" /remove "BUILTIN\Users"
icacls "C:\Shares\Sales" /grant "SMALLOFFICE\Sales-Staff:(OI)(CI)M"
```

**Share permissions and NTFS permissions are two separate gates.** A user must pass both, and the effective permission is whichever is more restrictive. Share permissions apply only to network access; NTFS applies always, including local access. Common practice is to leave share permissions broad and let NTFS do the real enforcement.

In the icacls syntax, `(OI)` is object inherit (files inside inherit the permission), `(CI)` is container inherit (subfolders inherit it), and `M` is Modify. `/inheritance:d` must run first: it converts inherited permissions into explicit ones so that removing `BUILTIN\Users` actually takes effect.

Verified with `Get-SmbShare` and `icacls "C:\Shares\Sales"`.

### Group Policy — mapped drives

One GPO per department, each linked to that department's OU so the mapping follows the user rather than the machine.

```
New-GPO -Name "Map Sales Drive" | New-GPLink -Target "OU=Sales,DC=smalloffice,DC=local"
New-GPO -Name "Map HR Drive"    | New-GPLink -Target "OU=HR,DC=smalloffice,DC=local"
New-GPO -Name "Map IT Drive"    | New-GPLink -Target "OU=IT,DC=smalloffice,DC=local"
```

The cmdlets create and link the GPOs but leave them empty. The drive mapping itself is configured in the Group Policy Management Editor, because Group Policy Preferences are not practically exposed through PowerShell:

**Tools → Group Policy Management →** right-click the GPO **→ Edit →** User Configuration → Preferences → Windows Settings → Drive Maps → right-click → New → Mapped Drive.

| GPO | Drive | Location | Label | Linked OU |
| --- | --- | --- | --- | --- |
| Map Sales Drive | S: | \\WS2025-DC01\Sales | Sales Share | OU=Sales |
| Map HR Drive | H: | \\WS2025-DC01\HR | HR Share | OU=HR |
| Map IT Drive | I: | \\WS2025-DC01\IT | IT Share | OU=IT |

All three use Action: Create with Reconnect enabled.

**User Configuration, not Computer Configuration.** Drive mappings follow the user, so they apply wherever that person signs in, and the GPO links to the OU holding the users rather than a computers OU. Computer Configuration has no Drive Maps node at all.

**On the Action setting:** Create makes the mapping if it is absent and leaves an existing one alone; Update modifies one that already exists; Replace deletes and recreates it every time, which is common in production because it guarantees the settings match. The dialog defaults to Update, so it has to be changed for a first-time setup.

**Verification:** rather than opening three editor windows, a single report covers all three GPOs with their settings and links:

```
Get-GPOReport -All -ReportType Html -Path "C:\GPOReport.html"
Invoke-Item "C:\GPOReport.html"
```

The report confirmed all three drive maps configured as above, with Computer Configuration showing "No settings defined" in each.

### Group Policy — password and lockout policy

```
New-GPO -Name "Domain Password Policy" | New-GPLink -Target "DC=smalloffice,DC=local"
```

Configured in the editor at **Computer Configuration → Policies → Windows Settings → Security Settings → Account Policies**.

| Password Policy | Value |
| --- | --- |
| Enforce password history | 5 passwords remembered |
| Maximum password age | 90 days |
| Minimum password age | 1 day |
| Minimum password length | 12 characters |
| Password must meet complexity requirements | Enabled |
| Store passwords using reversible encryption | Disabled |

| Account Lockout Policy | Value |
| --- | --- |
| Account lockout threshold | 5 invalid logon attempts |
| Account lockout duration | 15 minutes |
| Reset account lockout counter after | 15 minutes |

**Password and lockout policies only take effect at the domain level**, from a GPO linked to the domain root — linking one to an OU does nothing for domain accounts. There is exactly one domain-wide password policy, which is why the built-in Default Domain Policy normally holds it. (Fine-grained password policies via Password Settings Objects are the exception, and target specific groups.)

This GPO was created as a second GPO at the domain root with link **Order: 2**, below the Default Domain Policy, so the Default Domain Policy wins on any setting where the two disagree. Real environments usually edit the Default Domain Policy directly; keeping a separate GPO here makes GPO precedence visible and explainable.

Note the contrast with the drive-map GPOs: those are **User** Configuration linked to departmental OUs, these are **Computer** Configuration linked to the domain root.

## Errors encountered and fixes

### Phase 1 — Network

| Error | Cause | Fix |
| --- | --- | --- |
| `% Invalid input detected` on `vlan 10/ name SALES` | Typed `/` as a literal character instead of running each command on its own line | Split into separate lines: `vlan 10` then `name SALES` |
| `% Invalid input detected` on `switchport truck allowed vlan ...` | Typo: "truck" instead of "trunk" | Corrected spelling to `switchport trunk allowed vlan ...` |
| `% Invalid input detected` on `switchport trunk allowed vlan 10, 20, 30, 99` | Spaces after commas in the VLAN list | Removed spaces: `10,20,30,99` |
| `% Invalid input detected` on `show interfaces trunk` / `show vlan brief` while inside `Switch(config)#` | `show` commands only work from privileged EXEC (`Switch#`), not from config mode | Ran `end` first to return to `Switch#`, then the `show` command |
| `show interfaces trunk` returned blank | The Router0–Switch0 link was still down (router side not yet configured), so there was nothing to display | Used `show interfaces gig0/1 switchport` instead, which shows trunk config regardless of link state |
| `% Invalid input detected` on `ip dhcp excluded-address 192.168.10.1 192 168.10.10` | Typo: a space instead of a period in the second IP address | Corrected to `192.168.10.10` |
| Accidentally deleted a device cable | The Delete tool was active instead of the Select tool when clicking near a link | Switched to the Select tool, then reconnected via the Connections tool |

### Phase 2 — Windows Server and Active Directory

| Error | Cause | Fix |
| --- | --- | --- |
| Computer name was WIN-EKLS6COU3AF, not WS2025-DC01 | The name entered in VirtualBox's unattended-install fields never reached the OS, because unattended install was disabled | Renamed in Server Manager → Local Server → Computer name, then restarted |
| Guest OS froze; mouse and keyboard did nothing | A VirtualBox "mouse capture" dialog was sitting on top, swallowing input; the guest later hung outright (VM clock stopped advancing) | Machine → Reset, then used PowerShell instead of the network GUI dialogs |
| `A parameter cannot be found that matches parameter name 'DeafaultGateway'` | Typo in `-DefaultGateway` | Corrected spelling; tab completion avoids this |
| `Instance MSFT_NetIPAddress already exists` | The interface already had a DHCP-assigned address, and `New-NetIPAddress` only creates, never replaces | Ran `Remove-NetIPAddress` first, then re-ran `New-NetIPAddress` |
| `Set-Variable : A parameter cannot be found that matches parameter name 'DnsClientServerAddress'` | A space was typed after `Set`, so PowerShell read it as the `Set-Variable` cmdlet | Retyped `Set-DnsClientServerAddress` as one unbroken word |
| `A positional parameter cannot be found that accepts argument '-'` | A space between the hyphen and the parameter name (`- SamAccountName`) | Removed the space |
| `The password does not meet the length, complexity, or history requirement` | `$pw` was empty — the `ConvertTo-SecureString` line had not run successfully in that session | Re-ran the assignment, confirmed with `$pw` returning `System.Security.SecureString` |
| `'Get-ADDomain' is not recognized` | The command was run in Command Prompt, not PowerShell | Typed `powershell` to switch shells. PowerShell prompts start with `PS`; hyphenated cmdlets are PowerShell-only |

## Key concepts learned

### Networking

- **Layer 2 vs Layer 3 separation.** VLANs isolate traffic at Layer 2, but routing between them at Layer 3 reconnects those segments. An ACL selectively re-imposes isolation. The three work together rather than duplicating each other — this one idea explains the whole network build.
- **Access vs trunk ports.** An access port belongs to one VLAN and carries untagged traffic to a single end device. A trunk carries many VLANs and tags each frame with 802.1Q so the far end knows which is which.
- **Router-on-a-stick.** Sub-interfaces let one physical router port serve every VLAN, avoiding one port per network. The trade-off is that all inter-VLAN traffic shares one link; a Layer 3 switch is the answer at scale.
- **Wildcard masks and the implicit deny.** Cisco ACLs match with wildcard masks (the inverse of a subnet mask), and every ACL ends with an invisible deny-all — so an explicit `permit ip any any` is mandatory.
- **DHCP exclusions** prevent a pool from leasing an address already assigned statically, which would otherwise cause a duplicate-IP conflict.
- **Reading failures precisely.** "Request timed out" means nothing answered. "Destination host unreachable" replied by the gateway means a router actively rejected the packet. A first-ping timeout is usually ARP resolution, not a fault. TTL=127 rather than 128 proves exactly one router hop.

### Active Directory and Windows

- **AD depends on DNS.** Clients locate domain controllers through DNS SRV records, which is why DNS installs as part of promotion and why a domain controller needs a static IP.
- **OUs are for Group Policy; groups are for permissions.** You cannot link a GPO to a group, and you do not grant file access to an OU. They look similar in the console and do entirely different jobs.
- **Group scopes and AGDLP.** Global, Domain Local and Universal differ in who can be a member and where permissions apply. The enterprise pattern is Accounts → Global groups → Domain Local groups → Permissions.
- **FSMO roles.** AD is multi-master, but five operations cannot safely be — so they are assigned to specific domain controllers. A single-DC domain holds all five.
- **Share and NTFS permissions are two separate gates.** A user must pass both, the more restrictive wins, and NTFS also governs local access. Common practice is broad share permissions with NTFS doing the real enforcement.
- **`/inheritance:d` must run before removing an inherited ACL entry**, or the removal silently fails.
- **GPO precedence (LSDOU):** Local, Site, Domain, OU, with lower link order winning within a level. Enforced overrides everything; Block Inheritance stops higher-level GPOs, but Enforced beats Block Inheritance.
- **Policies vs Preferences.** Policies are enforced and revert when the GPO stops applying; Preferences set an initial state the user can usually change. Drive Maps are a Preference.
- **Password policy is domain-wide**, applied from a GPO at the domain root — fine-grained password policies via Password Settings Objects are the only way to vary it per group.

### Working practice

- **Verify each layer before building the next.** `show vlan brief`, `show ip interface brief`, `show interfaces <if> switchport` and `Get-ADDomain` were used throughout to confirm configuration matched intent rather than assuming success.
- **A blank result is not always a failure.** `show interfaces trunk` returned nothing because it lists only operational trunks and the far end was not yet configured — the configuration itself was correct.
- **PowerShell over GUI dialogs** for network and directory configuration: faster, scriptable, and it avoided the modal dialogs that froze the GUI path.

## Current state and next steps

Both phases are built and the network half is fully verified end to end. Two things are configured but not yet proven: the Group Policy drive mappings and the NTFS folder restrictions have never been exercised by a client, because no domain-joined workstation exists in the lab.

Closing that gap means adding a Windows 10/11 VM, joining it to `smalloffice.local`, signing in as one of the departmental users, and confirming with `gpupdate /force` and `gpresult /r` that the policy applies — then checking that the mapped drive appears and that access to another department's share is denied.
