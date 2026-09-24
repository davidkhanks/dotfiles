# Machines

What exists, what runs on it, and what is on the tailnet. Written down because
the desktop's arrangement is not guessable from the repo layout, and because
`hosts/` directories look like machines when two of them are not.

## The fleet

| | what it is | role |
|---|---|---|
| **panther** | Framework Laptop 13 Pro, Core Ultra X7 358H | daily driver, Omarchy |
| **desktop** | ASRock Z390 Phantom Gaming-ITX/ac · i9-9900K · RTX 3070 | three OSes, see below |
| **spartacus** | much older Windows box | file server: the SMB share, and Plex |
| **MacBook Pro M2** | older work laptop | occasional; being migrated away from |
| **iPhone 16 Pro** | phone | tailnet only |

## The desktop is one box with three drives

Each drive holds a different OS, and **only one can be running at a time.**

| drive | OS | `hosts/` dir | purpose |
|---|---|---|---|
| SATA SSD, 466G | Omarchy | [`hosts/omarchy/`](../hosts/omarchy/) | productivity, alongside panther |
| WD Blue SN550 1TB | CachyOS (KDE, fish) | [`hosts/cachyos/`](../hosts/cachyos/) | gaming |
| Intel 660p 1TB | Windows 10 | — | rarely booted |

Two consequences that are easy to get wrong:

- **`hosts/omarchy/` and `hosts/cachyos/` are the same physical computer.** Their
  CoolerControl configs describe identical hardware, so
  [`thermals.md`](thermals.md) applies to both. They are separate directories
  only because `host-config` keys on hostname.
- **`omarchy` and `cachyos` can never both be on the tailnet.** Booting one
  takes the other offline. Tailnet nodes are not physical machines here.

The `fish` stow package exists for the CachyOS drive — CachyOS uses fish as its
login shell. `step_stow` skips that package wherever fish is not installed, so
it costs the Omarchy machines nothing.

## Tailnet membership

| node | on the tailnet | notes |
|---|---|---|
| panther | yes | |
| omarchy (desktop) | yes | SSH in works; key already authorized |
| spartacus | yes | SMB 445 and RDP 3389 reachable; no SSH server |
| MacBook Pro | yes | no SSH server enabled |
| iPhone | yes | |
| cachyos (desktop) | **not yet** | would replace `omarchy` on the tailnet when booted |
| Windows 10 (desktop) | no | not worth setting up |

## What bootstrap.sh targets

`panther`, `omarchy` and `cachyos` are bootstrap machines. See
[`multi-os.md`](multi-os.md) for why the MacBook is not, and what it would take.
spartacus and the Windows drive never will be — access to spartacus is
documented in [`smb-shares.md`](smb-shares.md) and
[`remote-desktop.md`](remote-desktop.md) instead.
