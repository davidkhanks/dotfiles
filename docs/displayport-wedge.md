# The USB-C DisplayPort wedge (panther)

An external display on a USB-C hub sometimes stops working: USB data, ethernet
and the webcam all keep enumerating, only video dies, and so far only a reboot
has brought it back. Seen twice.

`dp-state` (in `bin/`) snapshots everything relevant so a broken state can be
diffed against a working one instead of re-derived:

```bash
dp-state working     # while it works
dp-state broken      # when it wedges, BEFORE trying any reset
diff ~/reports/dp-state-working-*.txt ~/reports/dp-state-broken-*.txt
```

## What is actually diagnostic

**The local port's DisplayPort alt mode.** Not the partner's:

```
/sys/class/typec/portN/portN.1    svid=ff01   active=yes|no
```

`active=yes` means the mux entered DP mode and the lanes carry video. If it
reads `no` while `framework_tool --pdports` still reports `HPD High`, the PD
controller has the link and the kernel never entered DP alt mode — that is the
fault.

Note `find` will not see these without `-L`: `/sys/class/typec/port*` are
symlinks and a plain walk goes straight past every alt mode under them.

## What is a red herring

These fire constantly on this hardware:

```
ucsi_acpi USBC000:00: unknown error 256          (UCSI_ERROR_UNDEFINED, BIT(8))
ucsi_acpi USBC000:00: GET_CABLE_PROPERTY failed (-5)
ucsi_acpi USBC000:00: con3: failed to register partner alt modes (-5)
```

**A baseline captured while the display was working shows all of them**, and
shows zero partner alt modes registered on any port. The display works anyway,
because the local alt mode is what carries video; the partner's is how the
kernel *describes* what the hub supports.

This corrects the first diagnosis, which treated the partner-alt-mode failure
as the cause and went into a Framework report on that basis. It is not the
cause. The genuinely odd observation — the EC reporting `HPD High` while every
DRM connector reads `disconnected` — still stands.

## Recovery, in order of blast radius

Untested against a live failure; try lowest first and capture `dp-state broken`
before each so it is known which one worked.

| | command | notes |
|---|---|---|
| 1 | `echo 0x30003 > /sys/kernel/debug/usb/ucsi/USBC000:00/command` | `UCSI_CONNECTOR_RESET` (0x03) + connector 3 (`<<16`). Add `BIT(23)` → `0x830003` for a hard reset. Spec-defined renegotiation, same path the driver uses. |
| 2 | `echo 0x01 > .../command` | `UCSI_PPM_RESET`. Resets the policy manager, which the driver already does at probe. |
| 3 | `framework_tool --pd-reset left` | Soft device reset over HPI — `ResetRequest` register, **no flash written**. |
| 4 | reboot | The only thing known to work so far. |

**Blast radius for step 3:** the Left controller owns ports **2 and 3** — the
charger *and* the hub — so both drop together. Fine on battery. Do it with the
lid open: in clamshell the external display is the only screen.

**Do not use `--pd-disable`.** Disabling the controller that powers the machine
leaves no obvious way back except `--pd-enable` or a reboot.

Nothing above writes firmware. The PD controllers carry a bootloader plus two
images (`FW1` backup, `FW2` main, both 1.0.0A here), so a reset restarts into
MainFw and a corrupt MainFw would fall back to the bootloader. Worst realistic
case is ports dead until a reboot, not a dead controller.

## Hardware facts worth not re-deriving

| | |
|---|---|
| PD controllers | Right → ports 0,1 · Left → ports 2,3 (both CCG, silicon 0x3E81) |
| hub sits on | port 3, Left controller |
| charger sits on | port 2, Left controller, 20V/5A 100W |
| YubiKey touch timeout | ~15s, if a PIN prompt collides with this |

## Upstream

- [omacom/omarchy#11864](https://github.com/omacom/omarchy/issues/11864) — Dell
  XPS 16, same Core Ultra X7 358H / Arc B390 / `xe`, wedged until reboot.
  Different UCSI signature (`duplicate partner altmode`), same end state.
- FrameworkComputer/SoftwareFirmwareIssueTracker — the report filed from here,
  plus an AMD-board corroboration, which argues against this being Panther Lake
  silicon specifically.
