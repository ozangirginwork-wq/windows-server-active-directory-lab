# Troubleshooting Notes

## 1. CLIENT01 could not reach DC01

### Symptoms

- CLIENT01 had `10.0.2.20/24`
- DC01 had `10.0.2.15/24`
- Both systems returned `Destination host unreachable`
- `Resolve-DnsName dc01.ozanlab.test` failed because the DNS server could not be reached

### Investigation

1. Confirmed static addressing with `Get-NetIPConfiguration` on both machines.
2. Confirmed that CLIENT01 used `10.0.2.15` as its DNS server.
3. Tested ICMP in both directions to separate DNS failure from basic network failure.
4. Compared the VirtualBox Adapter 1 configuration on both VMs.

### Root cause

The two adapters were not attached to the same effective VirtualBox internal network, even though their displayed names appeared similar.

### Resolution

1. Shut down both VMs cleanly.
2. Set Adapter 1 on both VMs to **Internal Network**.
3. Selected the exact same `OzanLabNet` value from the dropdown on each VM.
4. Confirmed **Virtual Cable Connected**.
5. Started DC01 first, followed by CLIENT01.
6. Repeated ICMP and DNS tests successfully.

### Validation

```powershell
ping 10.0.2.15
Resolve-DnsName dc01.ozanlab.test
```

## 2. Obsolete NAT gateway remained on DC01

### Symptom

After changing DC01 from NAT to Internal Network, `Get-NetIPConfiguration` still showed the old `10.0.2.2` default gateway.

### Resolution

```powershell
Remove-NetRoute `
    -InterfaceAlias 'Ethernet' `
    -DestinationPrefix '0.0.0.0/0' `
    -Confirm:$false
```

### Validation

`10.0.2.15` remained assigned while `IPv4DefaultGateway` became blank. A gateway is unnecessary for communication inside this single isolated subnet.

## 3. Standard domain user received a UAC credential prompt

### Symptom

Opening PowerShell with **Run as administrator** while signed in as `amorgan` requested an administrator username and password.

### Explanation

This was expected behavior, not a fault. `amorgan` is a standard domain user and was intentionally not added to the workstation's local Administrators group.

### Resolution

Opened PowerShell normally for nonprivileged identity and group-membership checks:

```powershell
whoami
whoami /groups | Select-String 'GG_IT_Users'
```

The result confirmed least privilege: the employee account could complete ordinary work but could not elevate without separate administrative credentials.

## 4. Separating connectivity, DNS, and domain problems

The diagnostic sequence used throughout the lab was:

1. Verify local IP configuration.
2. Ping the domain controller by IP address.
3. Resolve the domain controller's DNS name.
4. Verify the AD secure channel.
5. Verify applied Group Policy.

```powershell
Get-NetIPConfiguration
ping 10.0.2.15
Resolve-DnsName dc01.ozanlab.test
Test-ComputerSecureChannel
gpresult /r /scope computer
```

This order prevents a basic network failure from being misdiagnosed as an Active Directory or Group Policy failure.

