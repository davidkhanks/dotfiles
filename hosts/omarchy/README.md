# host: omarchy

Machine-specific files for this desktop. **Nothing here is portable.**

| | |
|---|---|
| Board | ASRock Z390 Phantom Gaming-ITX/ac (mini-ITX) |
| CPU | Intel i9-9900K |
| GPU | NVIDIA RTX 3070 |
| Storage | SATA SSD 466G (Omarchy) · Intel 660p 1TB (Windows) · WD Blue SN550 1TB (CachyOS) |

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

## Never identify these drives by kernel name

| Drive | Holds | Layout |
|---|---|---|
| SATA SSD, 465.8G | **Omarchy** | 2G ESP at `/boot`, LUKS + btrfs root |
| Intel SSDPEKNW010T8 (660p), 953.9G | **Windows** | 100M ESP, 16M MSR, NTFS, 509M recovery |
| WDC WDS100T2B0C (Blue SN550), 931.5G | **CachyOS** | 4G ESP, LUKS root |

**`nvmeXn1` numbers are not stable across boots.** They follow PCIe probe order,
so a drive that enumerates slowly — or not at all — renumbers the others. That
has already happened here: the SN550 dropped off the bus, and on the next boot
the Intel drive claimed `nvme0n1` while the SN550 returned as `nvme1n1`. Anything
that had targeted `nvme0n1` from memory would have wiped Windows.

Before partitioning, wiping, or pointing an installer at a disk, resolve it
through a stable identifier:

```bash
ls -l /dev/disk/by-id/ | grep nvme          # model + serial -> kernel name
lsblk -o NAME,SIZE,MODEL,FSTYPE,PARTUUID
```

In a graphical installer, confirm by **model and capacity**, never by device
node. The two NVMe drives differ by ~22G, which is enough to tell them apart at
a glance.

## The SN550 has dropped off the bus once

On 2026-09-18 its controller hung: a `Get Log Page` admin command timed out,
three controller resets failed with `CSTS=0x3` (RDY|CFS — controller fatal
status), and the kernel disabled the device. It then reported 0 bytes and
errored on every read until a **full power-off** — a warm reboot does not clear
a fatal controller state.

It came back intact. A full-surface read afterwards was clean:

```
1000204886016 bytes (1.0 TB, 932 GiB) copied, 591.84 s, 1.7 GB/s    exit 0
```

SMART is spotless — `critical_warning 0`, `media_errors 0`, `available_spare
100%`, `percentage_used 1%` — but **treat that as uninformative**. Because
`num_err_log_entries` is also 0, the controller never logged its own fatal
event, so SMART is structurally blind to whatever happened.

The failure signature — an admin command timing out, not a data transfer — fits
the NVMe deep-power-state (APST) hang, which a sustained read specifically
cannot reproduce, since the drive never goes idle during one. If it recurs, add
to the kernel command line of whatever OS lives there:

```
nvme_core.default_ps_max_latency_us=0
```

The drive was at 43,050 power-on hours (~4.9 years) when this happened. Nothing
irreplaceable should live on it unbacked.

## Not tracked here

**Limine boot entries** (`/boot/limine.conf`) chainload Windows and CachyOS.
Deliberately excluded — the entries embed partition GUIDs unique to these disks,
and `limine-scan` is interactive. Getting it wrong costs a bootloader. Recreate
manually:

```bash
limine-scan          # pick Windows Boot Manager, then CachyOS
```

then set `timeout: no` in `/boot/limine.conf` for a menu that waits for input.
The Omarchy entry is renamed `Quattro`; `comment: kernel-id=linux` is what makes
that survive kernel updates, so leave it in place.

### The second install: CachyOS

Installed 2026-09-22, replacing Bazzite. CachyOS runs its own Limine, so this is
Limine chainloading Limine — which works fine and keeps one config syntax across
both installs. Its entry in `/boot/limine.conf`:

```
/CachyOS
comment: CachyOS
comment: order-priority=20
protocol: efi
path: uuid(4c426829-ef15-4bc5-8205-983acb45f4aa):/EFI/limine/limine_x64.efi
```

That PARTUUID is `nvme1n1p1` as partitioned on 2026-09-22; repartitioning the
drive changes it. Look it up with `lsblk -o NAME,SIZE,PARTUUID` rather than
trusting this value after any disk work.

**The path is lowercase** — `/EFI/limine/limine_x64.efi`. `efibootmgr` prints
UEFI's uppercase form, which is *not* what sits on the FAT filesystem. Mount the
ESP and look rather than copying what `efibootmgr` displays.

Firmware boot order, after correcting what the installer did:

```
0002,000C,0010,0001,0000
  |    |    |    |    `--- Windows
  |    |    |    `-------- CachyOS Limine
  |    |    `------------- CachyOS fallback  \EFI\BOOT\BOOTX64.EFI
  |    `------------------ Omarchy fallback  \EFI\BOOT\BOOTX64.EFI
  `----------------------- Omarchy Limine    <- the top-level menu
```

Omarchy's own fallback sits second on purpose: if `LIMINE_X64.EFI` ever fails to
load, the firmware tries the other binary on the *same* ESP before reaching for
another drive, so a damaged file still lands you in your own menu. The CachyOS
entries are kept rather than deleted — they are a direct route in if Omarchy's
ESP is ever damaged.

### Replacing it again

Entries key on the **PARTUUID** of that install's ESP, not its filesystem UUID:
`path: uuid(<PARTUUID>):/EFI/<vendor>/<loader>.efi`. Reusing the existing ESP
partition keeps the PARTUUID so only the path changes; letting the installer
recreate the partition table yields a new one.

Two precautions before installing. The top-level menu is Omarchy's Limine on the
SATA drive, and the firmware boots it through the **fallback** path
`\EFI\BOOT\BOOTX64.EFI` — exactly the path other installers like to claim.

- Point the installer at the target drive's own ESP. Safest is to physically
  disconnect the other two drives, so only one ESP exists to find.
- A named `Limine` UEFI entry pointing at `\EFI\LIMINE\LIMINE_X64.EFI` also
  exists. If the fallback path gets overwritten, select that from the firmware
  boot menu to get back in.

Afterwards:

```bash
limine-scan                        # generate the new entry
sudo efibootmgr -v                 # find stale entries for the old install
sudo efibootmgr -b <num> -B        # delete each one
```

then edit `/boot/limine.conf` to drop the old OS's block and retitle the new one.
Expect the fresh install to have pushed itself to the front of `BootOrder`;
`efibootmgr -o <order>` puts Limine back in front.

The inner bootloader's identity does not matter to Limine, which chainloads any
EFI binary — GRUB, systemd-boot and Limine are all fine. Limine there keeps one
config syntax across both installs, and `limine-snapper-sync` gives it the same
snapshot-boot behaviour this install has.

**`/etc/modules-load.d/nct6775.conf`** is created by `bootstrap.sh` rather than
tracked here, since it is a single line and the module list is in the script.

See [`../../docs/thermals.md`](../../docs/thermals.md) for the measured fan
topology, sensor traps, and curve rationale.
