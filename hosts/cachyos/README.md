# host: cachyos

CachyOS on the **same physical desktop** as [`../omarchy/`](../omarchy/) — the
third OS on the box, in the slot that host's README calls "second Linux".

| | |
|---|---|
| Board | ASRock Z390 Phantom Gaming-ITX/ac (mini-ITX) |
| CPU | Intel i9-9900K |
| GPU | NVIDIA RTX 3070 |
| Root | WD Blue SN550 1TB, LUKS + btrfs |
| Desktop | KDE Plasma (Wayland) |
| Login shell | fish |

Because it is the same hardware, the fan topology, the sensor traps and the
curve rationale in [`../../docs/thermals.md`](../../docs/thermals.md) all apply
here unchanged — `CPUTIN` still reads −63°C, `fan3` still cannot stop.

## `etc/coolercontrol/config.toml` is identical to the Omarchy copy

Deliberately, and only because it was checked. The `[devices]` table and every
`[device-settings.<uid>]` key is a sha256 UID CoolerControl generates at
runtime; a UID that does not match the running daemon's applies **nothing** —
no error, no log line, fans left on the motherboard's own curves while the GUI
looks correctly configured.

On 2026-09-20, with the daemon running here for the first time, all seven UIDs
it reported matched the Omarchy copy exactly — including the only three any
profile depends on: `nct6791` (the fan headers), the RTX 3070 (the GPU leg of
the case mix) and the i9-9900K (the temp source for the other three profiles).
So the whole file transfers, curves and all, and the two hosts are kept
byte-identical on purpose.

Read the UIDs from the journal, not from `config.toml` — the daemon writes the
config **before** it finishes enumerating, so on a fresh install that table is
empty for one more write:

```bash
journalctl -u coolercontrold.service -o cat \
  | command grep -oE '"name":"[^"]+","uid":"[0-9a-f]{64}"' | sort -u
```

Re-check after any hardware change. If the UIDs ever diverge, rebuild the
profiles against the local ones — the curves themselves (the `speed_profile`
points and the two `[[functions]]`) still transfer, since they are tuned to
these exact fans.

Capture through the normal path rather than editing in place:

```bash
host-config diff       # drift between live /etc and this directory
host-config capture    # pull live -> repo, then commit
```

## What differs from the Omarchy install

- **`liquidctl` is not installed**, while the config carries
  `liquidctl_integration = true` (inherited from Omarchy, which has it as a
  `coolercontrold` optdepend). The daemon logs a `liqctld exited with a
  non-zero exit code: 1` error on every start and then carries on; nothing on
  this box is a liquidctl device. Install `liquidctl` to silence it and keep
  the two hosts' configs identical, rather than setting the flag false here
  and forking the file.
- **No AUR helper.** Neither `yay` nor `paru` is installed. Nothing here needs
  one: `coolercontrol` and `coolercontrold` are in CachyOS's own `cachyos`
  repo, so `bootstrap.sh` installs them with plain `pacman`. See the
  `PKG_COOLERCONTROL` comment in `bootstrap.sh`.
- **KDE Plasma, not Hyprland.** Every Omarchy-shell module is off here —
  there is no `omarchy-shell` process to host the QML plugins.
- **fish, not bash.** The `fish` stow package is what puts starship on the
  prompt here; `bash/.bashrc` is stowed but never sourced.

## Not tracked here

No root-owned files are captured for this host yet beyond the CoolerControl
config described above. The logind drop-in under `../panther/` is laptop-only
and does not apply to a desktop.

**Limine lives on the Omarchy drive, not this one.** This install's ESP was
recreated at 4G by the CachyOS installer, which per
[`../omarchy/README.md`](../omarchy/README.md) means its **PARTUUID changed** —
the previous second-Linux entry in `/boot/limine.conf` over on the Samsung SATA
drive is stale. Regenerate it from Omarchy with `limine-scan`, not from here.
