<#
.SYNOPSIS
    Configures a static IP address and DNS on the domain controller.

.DESCRIPTION
    A domain controller must have a static IP. Domain-joined clients locate
    domain controllers through DNS SRV records, and the DC is itself the DNS
    server - if its address changed, clients could not find it and
    authentication would fail across the whole domain.

    The 10.0.2.x addressing matches VirtualBox's NAT network, which always
    uses 10.0.2.0/24 with the gateway at 10.0.2.2.

.NOTES
    Project : Small Office IT Infrastructure Lab
    Host    : WS2025-DC01
    Run as  : Administrator
#>

$InterfaceAlias = "Ethernet"
$IPAddress      = "10.0.2.15"
$PrefixLength   = 24
$DefaultGateway = "10.0.2.2"
$DnsServer      = "8.8.8.8"

# Remove the existing DHCP-assigned address first.
# New-NetIPAddress only creates - it will not replace an existing address,
# and fails with "Instance MSFT_NetIPAddress already exists" if one is present.
Remove-NetIPAddress -InterfaceAlias $InterfaceAlias -Confirm:$false -ErrorAction SilentlyContinue
Remove-NetRoute     -InterfaceAlias $InterfaceAlias -Confirm:$false -ErrorAction SilentlyContinue

New-NetIPAddress -InterfaceAlias $InterfaceAlias `
                 -IPAddress      $IPAddress `
                 -PrefixLength   $PrefixLength `
                 -DefaultGateway $DefaultGateway

Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $DnsServer

# Verify
ipconfig
Test-Connection -ComputerName 8.8.8.8 -Count 4
