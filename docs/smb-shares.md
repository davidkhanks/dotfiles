# SMB shares over the tailnet

Mounting Windows shares from `spartacus` on this laptop. Everything here was
measured against the real machines on 2026-09-22.

## Why this works from anywhere

`spartacus` is on the tailnet, so the share is reachable wherever both machines
have internet — not just at home:

```
tailscale ping spartacus   pong via 192.168.x.y:41641 in 28ms
getent hosts spartacus     100.x.y.z    spartacus.<tailnet>.ts.net
port 445                   OPEN
negotiated dialect         SMB3_11
```

Two caveats that are easy to forget:

- The path above was **direct over the LAN** because both machines were home.
  Away from home Tailscale will NAT-traverse to a direct path or fall back to a
  DERP relay. Both work; relayed throughput on a multi-terabyte share is
  painful. `tailscale status` shows `direct` or `relay` per peer.
- The short name `spartacus` resolves only because MagicDNS is on
  (`tailscale set --accept-dns=true`). The mount unit uses the short name on
  purpose, to keep the tailnet identifier out of this public repo. With MagicDNS
  off, the unit needs the `100.x` address instead.

The Windows firewall already permits SMB on the Tailscale interface. That is
the single most common blocker for this and it needed no changes.

## What is set up

| | |
|---|---|
| shares on the server | `6TB_Storage`, `backup_images` (plus the `C$`/`D$`/`S$` admin shares) |
| mounted | `//spartacus/6TB_Storage` → `/mnt/spartacus/6TB_Storage` |
| account | a dedicated local Windows account, **not** an administrator (`C$` returns `ACCESS_DENIED`) |
| units | `hosts/panther/etc/systemd/system/mnt-spartacus-6TB_Storage.{mount,automount}` |
| module | `smb_shares`, **off by default** |

### automount, not fstab, and not the .mount

**Enable the `.automount`, never the `.mount`.** The mount is triggered by first
access to the path and released after `TimeoutIdleSec`. Enabling the `.mount`
directly, or adding an fstab line without `x-systemd.automount`, mounts at boot
— and a boot-time CIFS mount that cannot reach its server stalls the boot and
hangs `df`. On a laptop that is frequently off the tailnet or asleep, that is
the difference between a share that is occasionally unavailable and a machine
that will not finish booting.

Unit names are derived from the mount path and must match exactly:

```bash
systemd-escape -p --suffix=mount /mnt/spartacus/6TB_Storage
# -> mnt-spartacus-6TB_Storage.mount
```

### The credentials file is not in this repo

`/etc/samba/credentials/spartacus`, root-owned, mode 600:

```
username=<share account>
password=<the password>
```

`mount.cifs` reads the password in **plaintext at mount time**, so encrypting it
with age would only move the problem — and would put a YubiKey touch in the path
of a filesystem mount, which is a recipe for flaky mounts. It stays machine
local. `step_smb_shares` reports when it is missing rather than inventing one,
the same shape as the YubiKey steps.

Because the password lands in a plaintext file, the account it belongs to should
be worth as little as possible: a dedicated local account with access to only
the shares it needs, never a Microsoft account (whose password also guards
email, identity and potentially device encryption keys) and never an
administrator.

## Decoding SMB failures

The `NT_STATUS_*` code says precisely which half of the problem you have. This
took three attempts to work through and is worth not re-deriving:

| code | means | fix |
|---|---|---|
| `NT_STATUS_ACCESS_DENIED` on an anonymous (`-N`) connect | normal — modern Windows refuses anonymous enumeration | supply credentials |
| `NT_STATUS_LOGON_FAILURE` | **username or password is wrong** | find the real account with `Get-SmbShareAccess -Name <share>`, whose `AccountName` column names it |
| `NT_STATUS_PASSWORD_EXPIRED` | **username and password are both correct**; the account's password has aged out | on Windows: `Set-LocalUser -Name <account> -PasswordNeverExpires $true` |
| `NT_STATUS_ACCESS_DENIED` on a tree connect after a successful session setup | authenticated, but no rights to that share | `Grant-SmbShareAccess`, plus NTFS rights on the folder |

Local Windows accounts inherit a **42-day maximum password age** unless
`-PasswordNeverExpires` is set. A share-only service account has no human to
prompt, so expiry just silently breaks the mount six weeks later. That is what
`PASSWORD_EXPIRED` above was.

**Do not brute-force variants.** Windows 11 locks a local account after 10
failed attempts in 10 minutes (`net accounts` shows the policy). Diagnose on the
Windows side instead of guessing.

### Finding the account name on Windows

```powershell
Get-SmbShare | Where-Object { $_.Name -notlike "*$" } | Format-Table Name, Path
Get-SmbShareAccess -Name "6TB_Storage"      # AccountName column is the answer
Get-LocalUser | Format-Table Name, Enabled, LastLogon, Description
```

An account created only for file sharing has usually never logged in
interactively, so it has no folder under `C:\Users` and a blank `LastLogon` —
which distinguishes it from the accounts you actually use.

## What actually happens when spartacus is unavailable

Measured 2026-09-22 with a throwaway automount pointed at an unreachable host:

| situation | result |
|---|---|
| boot with the share unreachable | **unaffected.** The `.automount` touches no network; it only arms the autofs point |
| `df -h` while unmounted | **0.0s, and the mount is not even listed.** autofs points do not get stat'd |
| accessing the path while unreachable | **blocks ~10s, then fails** with `No such device` |
| idle for `TimeoutIdleSec` (180s) | unmounts itself |
| server vanishes mid-use | the mount is `soft`, so I/O returns errors instead of parking processes in uninterruptible sleep |

So it degrades, it does not hang — but "no issues" overstates it. **An access
while the share is down costs about ten seconds before it errors.** In a file
manager that looks like a freeze. The case to watch for is anything that walks
the whole filesystem — `find /`, a backup job, a desktop indexer — because that
*will* trigger the mount attempt and pay the ten seconds. `du`, `df` and
`lsblk` do not.

`soft` is a trade-off worth naming: an interrupted write can fail and return an
error rather than blocking until the server returns. For a media and backup
share that is the right side of the trade; for something holding a live
database it would not be.

## Getting it into Nautilus

A kernel CIFS mount under `/mnt` is not a "device", so Nautilus never discovers
it on its own — it shows removable and GVFS network mounts, not arbitrary
kernel mounts. The fix is a sidebar bookmark:

```
~/.config/gtk-3.0/bookmarks        # Nautilus 50.x still reads the gtk-3.0 path
file:///mnt/spartacus/6TB_Storage Spartacus 6TB
file:///mnt/spartacus/6TB_Storage/Data Spartacus Data
```

Format is `<uri> <label>`; the label may contain spaces, the URI may not.

That file is **owned and rewritten by Nautilus** every time bookmarks are
dragged around, so it is not stowed. `step_nautilus_bookmarks` reapplies the
entries instead — the same arrangement `step_bar_settings` uses for
`shell.json`. The step is gated on the `smb_shares` module rather than on the
paths existing, because a `[[ -d ]]` test against an autofs path would
**trigger the automount** and stall for the mount timeout whenever the server
is unreachable.

Clicking the bookmark is what triggers the mount, so the first click after an
idle period takes a moment. That is the automount working, not a hang.

An alternative to bookmarks is `gio mount smb://spartacus/6TB_Storage`, which
gives Nautilus a GVFS mount it *does* show natively — but it lands under
`/run/user/1000/gvfs/smb-share:server=…`, which is awkward from a shell and
breaks anything needing real file locking or `mmap`. The kernel mount plus a
bookmark gives both a normal path and a sidebar entry.

## Everything on the drive is already mounted

`6TB_Storage` is the whole drive, so every top-level folder on it — `Data`,
`backup_images`, `ISOs`, and the rest — is already reachable under
`/mnt/spartacus/6TB_Storage/`. Nothing extra to mount for those.

Windows separately exposes `backup_images` as its **own share**, which is why it
appears twice in `smbclient -L`. Mounting that share as well would just be a
second path to the same files.

## Adding another share

`backup_images` is not mounted. To add it: copy the two units, changing `What=`,
`Where=`, `Description` and the filenames (`systemd-escape` as above), add both
to `HOST_FILES` in `bootstrap.sh` and to `FILES` in `host-config`, and add the
automount to `SMB_AUTOMOUNTS`. The same credentials file covers it.
