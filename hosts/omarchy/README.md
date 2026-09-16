# host: omarchy

Machine-specific files for this desktop. **Nothing here is portable.**

| | |
|---|---|
| Board | ASRock Z390 Phantom Gaming-ITX/ac (mini-ITX) |
| CPU | Intel i9-9900K |
| GPU | NVIDIA RTX 3070 |
| Storage | sda (Omarchy, LUKS+btrfs), nvme0n1 (Bazzite), nvme1n1 (Windows) |

## What lives here and why

```
etc/coolercontrol/config.toml    fan curves + device settings
```

Stow only targets `$HOME`, so root-owned files are tracked per host instead and
applied with `host-config` rather than symlinked.

`config.toml` is host-locked for two independent reasons:

1. **Device UIDs are hardware-derived.** `[device-settings]` keys on a UID
   computed from the specific device — the nct6791 here is
   `00a4da18…`, and it would differ elsewhere.
2. **The curves are tuned to these exact fans.** They depend on `fan3`'s
   measured ~815 RPM floor and on `fan2` being the quieter of the two CPU fans.
   Applying them to different hardware would be meaningless at best.

Restoring another host's copy here, or this one elsewhere, is always wrong.

## Managing it

```bash
host-config diff       # drift between live /etc and this directory
host-config capture    # pull live -> repo (after tuning in the GUI)
host-config restore    # push repo -> live (stops/starts the daemon)
```

`bootstrap.sh` reports drift but **will not overwrite** the live file, because
CoolerControl rewrites it at runtime and the live copy may hold newer tuning.
`bootstrap.sh --restore-host` is the explicit opt-in to overwrite.

After changing fan curves in the CoolerControl GUI, run `host-config capture`
and commit, or the change exists only on this machine's disk.

## Not tracked here

**Limine boot entries** (`/boot/limine.conf`) chainload Windows and Bazzite.
Deliberately excluded — the entries embed partition GUIDs unique to these disks,
and `limine-scan` is interactive. Getting it wrong costs a bootloader. Recreate
manually:

```bash
limine-scan          # pick Windows Boot Manager, then Fedora
```

then set `timeout: no` in `/boot/limine.conf` for a menu that waits for input.
The Omarchy entry is renamed `Quattro`; `comment: kernel-id=linux` is what makes
that survive kernel updates, so leave it in place.

**`/etc/modules-load.d/nct6775.conf`** is created by `bootstrap.sh` rather than
tracked here, since it is a single line and the module list is in the script.

See [`../../docs/thermals.md`](../../docs/thermals.md) for the measured fan
topology, sensor traps, and curve rationale.
