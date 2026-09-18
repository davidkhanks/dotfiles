# Laptop thermals (panther)

Hardware-specific notes for the Framework Laptop 13. Everything here was
measured on the machine, not taken from a datasheet. The desktop's fan-curve
notes are in [`thermals.md`](thermals.md) and share nothing with this — that
box has a Super I/O chip and CoolerControl, this one has an EC and Intel DPTF.

## Hardware

| | |
|---|---|
| Model | Framework Laptop 13 Pro (Intel Core Ultra Series 3) |
| CPU | Core Ultra X7 358H, 16 cores, Tjmax ~100°C |
| GPU | Intel Arc B390 (Panther Lake Xe3, `xe` driver) |
| Memory | 62 GiB LPCAMM2 — a single module, but 128-bit, so full bandwidth |
| Fan | one, `acpi_fan` / `cros_ec`, ceiling ~6144 RPM |
| PL1 | 35 W (`intel-rapl:0/constraint_0_power_limit_uw`) |

There is no `nct6775` here, so `thermal-log` does not run on this machine — it
hard-requires the `nct6791` hwmon and exits.

## Clamshell costs ~8.6% sustained clock

Measured 2026-09-18: identical all-core load (`sha256sum /dev/zero` × 16) for
300s in each state, steady state taken as the mean of the final 60s, with a
3-minute settle between runs.

| | clamshell | lid open | delta |
|---|---|---|---|
| sustained clock | 2607 MHz | 2851 MHz | **−8.6%** |
| steady package temp | 82.7°C | 91.0°C | −8.3°C |
| steady fan | 5885 RPM | 6099 RPM | −214 RPM |
| peak package temp | 91°C | 97°C | −6°C |

## The trap: clamshell runs COOLER, and that is the problem

The obvious reading — "closed lid, less airflow, hotter chip" — is wrong here,
and the numbers say so. Clamshell is *cooler* and *slower*.

Per-minute, both start around 2850-2985 MHz and then diverge:

```
  window   clamshell          lid open
   0-60    81.4°C  2847 MHz   85.5°C  2985 MHz
  60-120   82.0°C  2598 MHz   94.6°C  2930 MHz   <- clamshell falls off a cliff
 120-180   82.9°C  2606 MHz   93.6°C  2923 MHz
 180-240   82.7°C  2605 MHz   92.7°C  2874 MHz
 240-300   82.7°C  2607 MHz   91.0°C  2851 MHz
```

Clamshell locks onto 82.7°C and holds it to within 0.2°C for four minutes.
That is a controller hitting a setpoint, not a chip running out of cooling.

The controller is Intel DPTF (`thermal_zone5`, `INT3400 Thermal`), which manages
**chassis skin temperature**, not just die temperature. Lid closed, the display
traps heat against the keyboard deck, the skin sensor rises, and DPTF clamps
package power harder. Less power means both lower clocks *and* a lower die
temperature. Lid open, DPTF has skin headroom and lets the die run to 91°C —
6°C off Tjmax — which buys the extra 244 MHz.

The fan is near its ceiling either way (5885 vs 6099 RPM, both peaking at the
6144 RPM limit), so there is no airflow left to recover. The constraint is
chassis heat dissipation.

**Never read the lower clamshell temperature as headroom.** It is not 17°C from
Tjmax with room to spare; it is sitting exactly on a different limit.

## Practical

- Benchmarks and anything sustained (compiles, games) want the lid open. ~9%.
- Check `powerprofilesctl get` first. `power-saver` sets `EPP=power` and
  `platform_profile=low-power`, stacking another clamp on top of this one.
- Short bursts are unaffected — the divergence only appears after ~60s, once
  DPTF has seen the skin temperature rise.

## Reproducing

No tool in this repo does it; the runs above used a throwaway script. The parts
that matter:

- load: `for i in $(seq $(nproc)); do timeout 300 sha256sum /dev/zero & done`
- package temp: `/sys/class/thermal/thermal_zone12/temp` (`x86_pkg_temp`)
- fan: `/sys/class/hwmon/hwmon1/fan1_input`
- clock: mean of `/sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq`

Sample every 2s and average the last 60s. RAPL energy (`intel-rapl:0/energy_uj`)
would give watts directly and is the better metric, but it needs root.
