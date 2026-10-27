# Small Office IT Infrastructure Lab

A self-directed infrastructure project building a complete small-office IT environment end to end — a segmented network in Cisco Packet Tracer, and a matching Windows domain in VirtualBox.

The departmental structure is deliberately the same on both sides: four VLANs on the network, the same four departments as organizational units in Active Directory. The two halves describe one organisation rather than two unrelated exercises.

---

## What this project covers

| Phase | Environment | What was built |
| --- | --- | --- |
| **1 — Network** | Cisco Packet Tracer | Four departmental VLANs, 802.1Q trunking, router-on-a-stick inter-VLAN routing, per-VLAN DHCP scopes, an extended ACL enforcing a security boundary |
| **2 — Domain** | Windows Server 2025 on VirtualBox | Domain controller with AD DS and integrated DNS, OUs, users and security groups, SMB shares secured with NTFS permissions, Group Policy for drive mapping and password policy |

---

## Phase 1 — Network design

One router (2911) connects to one switch (2960) over a single 802.1Q trunk. The switch distributes four VLANs to ten end devices.

```
                    Internet
                       |
                   [ Router0 ]  Gig0/0  — sub-interfaces .10 .20 .30 .99
                       |
                   (trunk link)
                       |
                   [ Switch0 ]  Gig0/1
                       |
     ┌─────────┬───────┴───────┬─────────────┐
   Sales       HR             IT          Servers
  VLAN 10    VLAN 20        VLAN 30       VLAN 99
  PC0 PC1    PC2 PC3    PC4 PC5 Printer0  PC6 PC7 Server0
```

### Addressing scheme

| VLAN | Department | Subnet | Gateway | DHCP range |
| --- | --- | --- | --- | --- |
| 10 | Sales | 192.168.10.0/24 | 192.168.10.1 | .11 onward |
| 20 | HR | 192.168.20.0/24 | 192.168.20.1 | .11 onward |
| 30 | IT | 192.168.30.0/24 | 192.168.30.1 | .11 onward |
| 99 | Servers | 192.168.99.0/24 | 192.168.99.1 | .11 onward |

Addresses `.1`–`.10` in each subnet are excluded from DHCP and reserved for gateways and statically assigned devices.

### Port assignment

| Switch port | Device | VLAN |
| --- | --- | --- |
| Fa0/1 – Fa0/2 | PC0, PC1 | 10 (Sales) |
| Fa0/3 – Fa0/4 | PC2, PC3 | 20 (HR) |
| Fa0/5 – Fa0/7 | PC4, PC5, Printer0 | 30 (IT) |
| Fa0/8 – Fa0/10 | PC6, PC7, Server0 | 99 (Servers) |
| Gig0/1 | Router0 (Gig0/0) | Trunk — 10,20,30,99 |

### Access control

An extended ACL blocks the Sales VLAN from reaching the Servers VLAN while leaving all other paths open:

```
access-list 110 deny ip 192.168.10.0 0.0.0.255 192.168.99.0 0.0.0.255
access-list 110 permit ip any any
interface gig0/0.10
 ip access-group 110 in
```

### Verification results

| Test | Result |
| --- | --- |
| DHCP across all 10 endpoints | All received correct subnet, gateway and DNS, starting at `.11` |
| Sales → HR (`ping 192.168.20.11`) | 4/4 replies, TTL=127 |
| Sales → Servers (`ping 192.168.99.13`), post-ACL | Blocked — "Destination host unreachable" from the gateway |
| IT → Servers, post-ACL | Unaffected — replies received |

TTL=127 rather than 128 confirms traffic crossed exactly one router hop, proving inter-VLAN routing rather than same-segment delivery.

---

## Phase 2 — Windows Server and Active Directory

| Item | Value |
| --- | --- |
| Domain | `smalloffice.local` (NetBIOS: SMALLOFFICE) |
| Domain controller | WS2025-DC01, 10.0.2.15/24 |
| OS | Windows Server 2025 Standard (Desktop Experience), Evaluation |
| Functional level | Windows2025Domain |

### Directory structure

| OU | Users | Security group |
| --- | --- | --- |
| Sales | Anita Rao (`arao`), Ben Carter (`bcarter`) | Sales-Staff |
| HR | Clara Diaz (`cdiaz`) | HR-Staff |
| IT | Dev Patel (`dpatel`) | IT-Staff |

### File shares

Each department has an SMB share whose NTFS permissions are scoped to its own security group, with `BUILTIN\Users` removed so other departments cannot browse in.

| Share | Path | NTFS access |
| --- | --- | --- |
| `\\WS2025-DC01\Sales` | C:\Shares\Sales | Sales-Staff — Modify |
| `\\WS2025-DC01\HR` | C:\Shares\HR | HR-Staff — Modify |
| `\\WS2025-DC01\IT` | C:\Shares\IT | IT-Staff — Modify |

### Group Policy

| GPO | Scope | Setting |
| --- | --- | --- |
| Map Sales Drive | OU=Sales | Drive S: → `\\WS2025-DC01\Sales` |
| Map HR Drive | OU=HR | Drive H: → `\\WS2025-DC01\HR` |
| Map IT Drive | OU=IT | Drive I: → `\\WS2025-DC01\IT` |
| Domain Password Policy | Domain root | 12-char minimum, complexity enabled, 90-day max age, 5-password history, lockout at 5 attempts for 15 minutes |

Drive mappings sit under **User** Configuration so they follow the person rather than the machine. The password policy sits under **Computer** Configuration at the domain root, because password and lockout policies only take effect domain-wide.

---

## Repository contents

```
├── README.md
├── docs/
│   ├── project-log.md              Full build log with every command and error encountered
│   ├── cisco-switch-commands.pdf   IOS switch command reference
│   ├── cisco-router-commands.pdf   IOS router command reference
│   └── pc-command-reference.pdf    Windows/PC networking command reference
├── network/
│   ├── small-office-lab.pkt        Packet Tracer topology file
│   ├── switch-config.txt           Switch running configuration
│   ├── router-config.txt           Router running configuration
│   └── screenshots/                Topology, VLAN tables, DHCP leases, ping tests
└── windows-server/
    ├── 01-network-config.ps1       Static IP and DNS configuration
    ├── 02-active-directory.ps1     AD DS install, promotion, OUs, users, groups
    ├── 03-shares-and-permissions.ps1   SMB shares and NTFS permissions
    ├── 04-group-policy.ps1         GPO creation and linking
    ├── GPOReport.html              Exported Group Policy settings report
    └── screenshots/                Server Manager, AD verification, GPO reports
```

---

## Tools used

- Cisco Packet Tracer 8.x
- Oracle VirtualBox 7.2
- Windows Server 2025 Standard (Evaluation)
- PowerShell 5.1

---

## Current state

Both phases are built, and the network half is verified end to end with ICMP testing at each stage.

Two items are configured but not yet exercised by a client: the Group Policy drive mappings and the NTFS folder restrictions. No domain-joined workstation exists in the lab, so neither has run in practice.

**Next step:** add a Windows 10/11 VM, join it to `smalloffice.local`, sign in as a departmental user, and confirm with `gpupdate /force` and `gpresult /r` that policy applies — then verify the mapped drive appears and that access to another department's share is denied.
