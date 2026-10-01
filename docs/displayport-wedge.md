# The USB-C DisplayPort wedge (panther)

## RESOLVED: aquamarine 0.15.0 regression

**Root cause found 2026-09-30. Not a hardware fault.**

[hyprwm/aquamarine#386](https://github.com/hyprwm/aquamarine/issues/386) --
*"0.15.0 regression: CRTC of a removed connector is never disabled in the
kernel; re-plugged outputs then fail every modeset with EINVAL."* Commit
`9d6fed9` added a guard rejecting commits on connectors already marked
disconnected, so the compositor's **disable** commit never reaches the kernel
and the CRTC is orphaned.

Fixed by [PR #410](https://github.com/hyprwm/aquamarine/pull/410) ("drm:
release output on disconnect manually"), merged 15 Sept, shipped in
**aquamarine v0.15.1** on 17 Sept.

**This machine got 0.15.0 on 2026-09-16 at 14:32 -- one day before the fix was
released** -- which is when the wedges started.

### Why Omarchy machines stay broken

`stable-mirror.omarchy.org` pins a tested snapshot, so `pacman -Syu` keeps
offering 0.15.0-2 long after Arch `extra` shipped 0.15.1-1. Installed here
manually from the official Arch binary (signature verified, same SONAME
`libaquamarine.so.14`, so no Hyprland rebuild needed):

```bash
curl -fsSLO https://geo.mirror.pkgbuild.com/extra/os/x86_64/aquamarine-0.15.1-1-x86_64.pkg.tar.zst
sudo pacman -U aquamarine-0.15.1-1-x86_64.pkg.tar.zst
# rollback: sudo pacman -U /var/cache/pacman/pkg/aquamarine-0.15.0-2-x86_64.pkg.tar.zst
```

Pacman will not downgrade it on a normal `-Syu`, so it holds until Omarchy
ships >= 0.15.1 and takes over. **The fix only applies after Hyprland
restarts** -- log out or reboot.

### How the evidence below maps onto it

Everything in this file was gathered before the cause was known, and all of it
fits:

| observed here | #386 |
|---|---|
| `enabled=enabled, dpms=On` on a disconnected connector | the orphaned CRTC |
| no userspace tool could release it | aquamarine refuses the disable commit |
| VT switch prevents it | fbcon disables orphaned CRTCs |
| teardown before unplug prevents it | disable succeeds while still `CONNECTED` |
| hibernate fails, warm reboot works | DRM state restored vs rebuilt |
| every DP layer trains, no image | modeset rejected on the stale CRTC |

The one divergence: #386 reports outputs stuck at `0x0`, while here a real mode
was reported -- probably `hyprmoncfgd` re-applying a profile over the top.

**Two wrong diagnoses were filed upstream before this** (partner alt modes, and
a port 3 `VCONN` correlation); both are retracted in the sections below. The
lesson worth keeping: the PD/Type-C layer was byte-identical in both states the
whole time, and that should have pointed at the compositor far sooner than it
did.

---

## Original investigation (kept for the evidence)

An external display on a USB-C hub stops working: USB data, audio and the
webcam all keep enumerating through the same hub, only video dies. **Only a
warm reboot recovers it.** As of 2026-09-30 the entire software recovery ladder
has been tested against live failures — connector resets, PD reset, driver
rebind, forced link retrain, forced connector, forced low link rate, s2idle and
a full S4 hibernate — and none of them work.

Reproducer: unplug the hub and the charger, wait ~2 minutes, plug both back in.

`dp-state` (in `bin/`) snapshots the whole path so a broken state can be diffed
against a working one instead of re-derived:

```bash
dp-state working     # while it works
dp-state broken      # when it wedges, BEFORE trying any reset
diff ~/reports/dp-state-working-*.txt ~/reports/dp-state-broken-*.txt
```

## Diagnosis (2026-09-30, full instrumented reproduction)

**Every layer of the DisplayPort stack reports success, and no image appears.**
Captured with `drm.debug=0x106` during a DPMS cycle against a live wedge:

```
[LTTPR 1] Clock recovery OK
[LTTPR 1] Channel EQ done. DP Training successful
[LTTPR 1] Link Training passed at link rate = 540000, lane count = 2
[DPRX]    Clock recovery OK
[DPRX]    Channel EQ done. DP Training successful
[DPRX]    Link Training passed at link rate = 540000, lane count = 2
```

`DPRX` is the monitor. It received training patterns **over the main lanes**
and reported success back over AUX. So end to end:

| layer | state while wedged |
|---|---|
| PD / Type-C | `PD Contract: Yes`, `DP Alt Mode: UFP_D Connected, HPD High` |
| kernel typec | irrelevant — see below |
| AUX / SBU | working: full DPCD reads, `SINK_COUNT 0x41`, EDID 256 bytes |
| LTTPR (retimer) | detected, `OUI 98-4f-ee dev-ID GBR HW-rev 10.0`, **trains OK** |
| main lanes | **carry training patterns; monitor locks on** |
| link | HBR2 x 2 lanes, `required 1032000 / available 1080000` (96%) |
| DRM | `connected`, DPMS `On`, native mode set |
| **monitor** | **blank** |

Nothing in the DP protocol stack is failing. The link is up and the sink
acknowledges it. What is missing is the video stream itself, which points at
the display pipe/transcoder in `xe` rather than at any cable, mux, PD or
physical-layer problem.

### Bandwidth is ruled out (tested)

The native mode uses 96% of available link bandwidth, which looks alarming. It
is not the cause. Tested against a live wedge at **32%** utilisation —
1920x1080@60 with the link rate forced to HBR3 x 2 lanes:

```
DP lane count 2 clock 810000 ... required 519000 available 1620000
Link Training passed at link rate = 810000, lane count = 2
```

A 3x margin, training passes at the higher rate, **monitor still blank.** So
the stream is not merely marginal — it is not being produced at all.

**Testing gotcha:** simply selecting a lower mode does not create margin. The
driver picks the lowest link rate that fits, so 1920x1080@60 alone dropped the
link to HBR and landed back at 96%. The rate must be forced high *and* the mode
set low:

```bash
pkexec bash -c 'echo 810000 > /sys/kernel/debug/dri/0/DP-1/i915_dp_force_link_rate
                echo 2      > /sys/kernel/debug/dri/0/DP-1/i915_dp_force_lane_count'
# ... set a low mode, then DPMS cycle to retrain ...
# ALWAYS restore:
pkexec bash -c 'echo auto > /sys/kernel/debug/dri/0/DP-1/i915_dp_force_link_rate
                echo auto > /sys/kernel/debug/dri/0/DP-1/i915_dp_force_lane_count'
```

**Changing the mode requires stopping `hyprmoncfgd` first** — it owns monitor
state and silently re-applies its profile, so `hl.monitor()` via `hyprctl eval`
appears to succeed (`ok`) while nothing changes. `systemctl --user stop
hyprmoncfgd.service`, make the change, then `start` it again to restore. Do not
use `hyprmoncfg unmanage`; it edits the Hyprland config persistently.

### The kernel Type-C layer is not involved

Unbinding `ucsi_acpi` entirely — *zero* typec ports registered — leaves a
working display working. The DP link is held up by the EC and PD controller in
hardware and does not depend on the kernel's UCSI representation at all.

## The VCONN signature — RETRACTED

An earlier revision claimed port 3 `VCONN` tracked the fault across nine
captures. **It does not.** Two independent counterexamples:

- after hibernate resume: `VCONN: On` with a **working** display
- after a UCSI rebind while wedged: `VCONN: Off` with a **broken** display

The original correlation was confounded: every working sample came from a cold
boot (BIOS negotiates the port), every broken one from an unplug/replug (the
OS/EC renegotiates at runtime). VCONN marks *who negotiated last*, not whether
the link works. There is **no known PD-layer discriminator**; only
`card0-DP-1/status` distinguishes the states, and that merely restates the
symptom.

## Hibernate does NOT fix it — and that is the key result

`systemctl hibernate` performs a genuine S4: `Waking up from system sleep state
S4`, `usb usbN: root hub lost power or was reset`, `boot_id` preserved. The
platform fully powers off and BIOS POSTs on the way back.

**It does not clear the wedge.** A warm reboot does.

Since firmware re-initialises in both cases, firmware/retimer init cannot be
what fixes it. The one thing a reboot does that a hibernate resume does not is
**start every driver fresh instead of restoring saved state from the image**.
That places the stuck state in kernel driver state — most plausibly the `xe`
display engine, which also matches the trace above showing every protocol layer
healthy while no stream is produced.

## Recovery ladder — everything except a reboot has now been tested and failed

Tested against live failures on 2026-09-30. Listed so the next wedge goes
straight to a reboot instead of costing an hour.

| | attempt | result |
|---|---|---|
| 1 | `UCSI_CONNECTOR_RESET` con3 (`0x30003`) | no change |
| 2 | `UCSI_CONNECTOR_RESET` con4 (`0x40003`) — the hub's connector | no change |
| 3 | hard connector reset (`0x840003`) | no change |
| 4 | `UCSI_PPM_RESET` (`0x01`) | **rejected**, `Operation not supported` |
| 5 | `framework_tool --pd-reset 1` | no change |
| 6 | `ucsi_acpi` unbind/rebind | no change (VCONN `On`→`Off`, still broken) |
| 7 | `i915_dp_force_link_retrain` | no change, silent |
| 8 | `echo on > .../card0-DP-1/status` | AUX recovers, EDID reads — **still no image** |
| 9 | forced low link rate (RBR) | no change |
| 9b | low mode at forced HBR3 (32% bandwidth) | no change — bandwidth ruled out |
| 10 | suspend/resume (s2idle) | no change |
| 11 | **hibernate (real S4 power-off)** | **no change** |
| 12 | **warm reboot** | **works** |

Step 8 is worth understanding: forcing the connector on made DRM attempt a
modeset, which drove AUX transactions and brought EDID back from 0 bytes to
256. That looks like a recovery in software and is not one — the monitor stays
blank. Do not trust `status=connected` as evidence the display works.

**Side effect of step 5:** the Left controller owns ports 2 and 3 — charger and
hub — so both drop together. The YubiKey lives on the hub and needs replugging
plus `yk-reload` afterwards.

**Do not use `--pd-disable`.** Disabling the controller that powers the machine
leaves no obvious way back except `--pd-enable` or a reboot.

**Do not unbind `xe`** while it drives the only display; in clamshell that is a
guaranteed black screen recoverable only by reboot. If the driver-state theory
is ever tested properly, do it with the lid open and the session stopped.

### Gotchas found the hard way

- `echo unspecified > /sys/kernel/debug/dri/0/DP-1/force` is **rejected**
  (`Invalid argument`). Clear a forced connector with
  `echo detect > /sys/class/drm/card0-DP-1/status`, which also resets the
  debugfs flag.
- **`hyprctl keyword` does nothing under the Lua parser** — it returns
  "keyword can't work with non-legacy parsers. Use eval." Several apparent
  "modeset produced no output" results were really commands that never ran.
  Dispatchers take the form `hl.dsp.<name>({ ... })`, e.g.
  `hyprctl dispatch 'hl.dsp.dpms({ state = "off", monitor = "DP-1" })'`, and
  apply asynchronously — re-read sysfs after a delay, not immediately.
- `drm.debug=0x106` floods the kernel ring buffer fast enough to wrap it.
  Capture with `journalctl -k --since` rather than diffing `dmesg` line counts,
  and always set it back to `0`.

## Possible workaround: tear the output down before unplugging (n=1)

**One successful trial. Not yet confirmed, and no control run has been done.**

The theory: the metadata gap while wedged (`description:`/`make:` empty in
`hyprctl monitors`) is missing EDID, which is missing AUX *at probe time* — not
permanently, since forcing a detect later recovers EDID. So the probe races the
hub's DP path becoming ready, and the driver caches bad state for the TC port.
Tearing the pipeline down before the hardware disappears leaves less stale state
behind.

```bash
systemctl --user stop hyprmoncfgd.service          # or it re-applies the profile
hyprctl eval 'hl.monitor({ output = "DP-1", disabled = true })'
# ... physically unplug hub + charger, wait ~2 min, replug ...
systemctl --user start hyprmoncfgd.service
hyprmoncfg apply docked-and-open --confirm-timeout 0
```

Confirm the teardown really happened before unplugging — `enabled: disabled` in
sysfs, and with `drm.debug=0x106` the pipe releases its transcoder:

```
[CRTC:270:pipe B] cpu_transcoder (expected 1, found -1)
[CRTC:270:pipe B] lane_count     (expected 2, found 0)
[CRTC:270:pipe B] output_types   (expected 0x80, found 0x0)
```

Result of the one trial: EDID 256 bytes and 15 modes on first probe, metadata
populated, display worked. Compare to a wedge, where EDID is 0 bytes and 0
modes and the metadata stays blank even after EDID is recovered.

**Control run done — the teardown is what matters.** Two runs, both with
`hyprmoncfgd` stopped, differing only in whether the output was torn down:

| run | teardown | EDID | modes | result |
|---|---|---|---|---|
| A | yes | 256 bytes | 15 | **working** |
| B | no | 0 bytes | 0 | **wedged** |

So `hyprmoncfgd` is **not** implicated — stopping it changes nothing on its
own. The explicit pipeline teardown before the physical unplug is the
load-bearing step. Still one trial each; repeat before trusting it completely.

**The teardown does not work as a recovery, only as prevention.** Tried against
the fresh wedge from run B: once wedged, the connector reads
`enabled=enabled, dpms=On` while `status=disconnected` and the compositor has
already dropped it — a stale pipeline binding on a dead connector. Neither
`hl.monitor({ disabled = true })` (Hyprland is not holding it) nor
`echo off > /sys/class/drm/card0-DP-1/status` (accepted, nothing released)
clears it. **Userspace has no handle on that binding**, which is the cleanest
explanation yet for why the whole recovery ladder fails: every tool available
operates above a binding held below all of them.

### Confirmed independently by a VT switch

A VT switch drops DRM master, which tears the pipeline down by a completely
different route than the compositor teardown. Prediction made in advance: if
"active pipeline at unplug time" is the cause, this should also prevent the
wedge.

```
Ctrl+Alt+F2 -> unplug -> Ctrl+Alt+F1 -> replug     # display came back fine
```

It did. Two independent mechanisms prevent the fault and the only thing they
share is releasing the pipeline before the hardware disappears. That is the
strongest evidence available for the trigger without reading driver source.

It also argues this is **not a Hyprland bug**: a VT switch is a kernel-level
DRM master handover, so the state that matters is the DRM pipeline binding,
which any compositor creates. `hyprmoncfgd` is likewise cleared -- the control
run wedged with the daemon stopped. Report this against the kernel / `xe`,
not against the compositor.

Useful as a tooling-free workaround on any machine: VT-switch away before
unplugging.

**Use the `dp-undock` script** (in `bin/`) rather than the raw commands; it
verifies the teardown actually took effect, refuses to run when it would leave
no screen, and logs each trial to `~/reports/dp-undock-trials.tsv`.

Everyday workflow, verified working:

```bash
dp-undock prepare    # teardown, stops hyprmoncfgd
#   unplug
dp-undock resume     # hands control back to the daemon
#   replug -- nothing else to run
```

`hyprmoncfgd` handles hot replug by itself. It rescores the profile from 70
(undocked) to 200 on `monitoradded:DP-1` and re-applies it, scaling included:

```
triggered: monitoradded:1,DP-1,Ancor Communications Inc ROG PG348Q ...
best profile "Docked and Open" score=200 lid=open
applied profile: Docked and Open
```

The monitor name appearing in that event means EDID was read at probe time --
exactly what fails in a wedge. Use `dp-undock restore` in place of `resume`
when a trial should be logged; only `restore` reads EDID on the first probe.

**Gotcha:** `hyprmoncfg apply` prompts and auto-reverts after 10s, so without a
TTY it silently reverts and errors `EOF`. Use `--confirm-timeout 0`.

## Reproducing it

Unplug the hub and the charger, wait ~2 minutes, plug both back in. That
produced the wedge reliably — it is how every observed failure started.

## Hardware facts worth not re-deriving

| | |
|---|---|
| machine | Framework Laptop 13 Pro, Core Ultra Series 3, BIOS 03.02, kernel 7.2.5-3-omarchy |
| GPU / driver | Arc B390, `xe` |
| PD controllers | Right → ports 0,1 · Left → ports 2,3 (both CCG, silicon 0x3E81) |
| Intel retimers | Left and Right both 0xCF (207) |
| hub sits on | port 3 (UCSI con4), Left controller |
| charger sits on | port 2 (UCSI con3), Left controller, 20V/5A 100W |
| YubiKey touch timeout | ~15s, if a PIN prompt collides with this |

## Upstream

- [omacom/omarchy#11864](https://github.com/omacom/omarchy/issues/11864) — Dell
  XPS 16, same Core Ultra X7 358H / Arc B390 / `xe`, wedged until reboot.
  Different UCSI signature (`duplicate partner altmode`), same end state.
- FrameworkComputer/SoftwareFirmwareIssueTracker — the report filed from here.
  **Its central claim (partner alt-mode registration failure) is disproved by
  the working-state baseline and needs the follow-up in this file.** An AMD-board
  corroboration on that thread argues against this being Panther Lake silicon.
