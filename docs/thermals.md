# Fan control and thermals

Hardware-specific notes for this desktop. Everything here was measured on the
machine, not taken from a datasheet. The laptop shares none of this — it has no
Super I/O and no CoolerControl; see [`laptop-thermals.md`](laptop-thermals.md).

## Hardware

| | |
|---|---|
| Board | ASRock Z390 Phantom Gaming-ITX/ac (mini-ITX), BIOS 5.13 |
| CPU | Intel i9-9900K, Tjmax **100°C** |
| GPU | NVIDIA RTX 3070, 220W limit |
| Super I/O | Nuvoton NCT6791D @ `0x2e:0x290`, driver `nct6775` |

## The `nct6775` module

Without it there are **no fan or PWM hwmon entries at all** and CoolerControl
sees nothing to drive. It is not auto-loaded, so `/etc/modules-load.d/nct6775.conf`
pins it (installed by `bootstrap.sh`).

A one-off `modprobe` is not enough — it silently disappears on the next reboot
and takes all fan control with it.

**No `acpi_enforce_resources=lax` needed.** The usual ASRock fix for this chip
is a kernel cmdline change, but on this board the chip binds cleanly on its own.
`sensors-detect` confirms it independently at confidence 9. Do not add the
kernel parameter; it isn't necessary here.

## Fan topology (measured)

Each PWM drives exactly one tach — no ganged headers. Confirmed by driving each
header alone and watching all three tachs.

| Header | Fans | Max RPM | Stops at duty 0? |
|---|---|---|---|
| `fan1` | **top case pair**, on a Y-splitter | 2030 | yes |
| `fan2` | **main CPU fan** | 1748 | yes |
| `fan3` | **thin secondary CPU fan** | 2824 | **no — floor ~815 RPM** |

`fan4`/`fan5` are empty headers.

A Y-splitter reports only one tach, so it is indistinguishable from a single
fan in sysfs. `fan1` was confirmed as the pair by stopping it and watching both
top fans stop together.

### duty → RPM

| duty | fan1 (case) | fan2 (CPU main) | fan3 (thin) |
|---|---|---|---|
| 12% | 293 | 288 | **829** |
| 25% | 587 | 551 | **929** |
| 37% | 878 | 810 | **1332** |
| 50% | 1146 | 1035 | 1670 |
| 62% | 1391 | 1220 | 1967 |
| 75% | 1626 | 1390 | 2231 |
| 100% | 2057 | 1700 | 2694 |

**`fan3` has a hard floor.** It ignores duty below ~25% entirely — even duty 0
still spins ~813 RPM. That is spec-compliant 4-wire behaviour (0% means the
manufacturer's minimum, not off). All three headers report `pwm_mode = 1` (PWM),
so this is the fan's own minimum, not a DC/PWM mismatch that could be tuned
around. **fan3 cannot be made silent.**

`fan3` is also the noise source at every operating point: at 37% duty it spins
1332 RPM while `fan2` does 810. Under the stock BIOS curve it idled at ~1400.

## Sensor trap

**Never use `CPUTIN` as a curve source. It reads −63°C.** The CPU thermal diode
header is unwired on this board — a known ASRock quirk. A curve bound to it will
hold fans at minimum forever and let the CPU cook under load. It is temptingly
named, which is exactly the problem.

Use either:

- `CPU Temp Package Id 0` (the `coretemp` package sensor) — what the curves use
- `PECI Agent 0` on the nct6791 — cross-validates within 1°C

CoolerControl already filters `CPUTIN` out of its exposed temps, but raw sysfs
and `sensors` still show it.

## Curve design

The core idea: **shift cooling work onto `fan2` so `fan3` can sit at its floor.**
`fan2` is a bigger, slower, quieter fan, so buying cooling from it costs far
less noise than the same cooling from the thin high-RPM `fan3`.

| Profile | Fan | Source | Curve (°C → duty%) |
|---|---|---|---|
| CPU Secondary (quiet) | fan3 | CPU package | 30→15, **95→15**, 97→60, 100→100 |
| CPU Main | fan2 | CPU package | 30→20, 50→30, 65→50, 75→70, 85→100 |
| Case (CPU leg) | — | CPU package | 30→15, 50→25, 65→40, 80→65, 90→90 |
| Case (GPU leg) | — | GPU Temp | 30→15, 50→25, 65→45, 75→70, 85→100 |
| Case Mix | fan1 | `Max` of the two legs | — |

Functions (hysteresis + response delay) matter more than curve shape for the
original complaint, which was fans hunting up and down. A 9900K spikes ~20°C for
a few hundred milliseconds on any background task, and the BIOS curve chased
every one of those:

| Function | Applied to | Settings |
|---|---|---|
| `Smooth (hysteresis+delay)` | fan1, fan2 | deviance 3°C, response delay 8s |
| `Responsive (fan3 emergency)` | fan3 | deviance 1°C, response delay 2s |

`fan3` gets the responsive one deliberately: its curve is flat below 95°C so
smoothing buys nothing there, but once it does engage you want it immediate.

### Idle result

| Fan | BIOS Smart Fan IV | These curves |
|---|---|---|
| fan1 | ~880 | 460 |
| fan2 | ~810 | 549 |
| fan3 | ~1400 | **818** (its floor) |

## Validated under load (2026-09-20)

`fan3` is pinned to its floor until 95°C by explicit choice, which removes it
from normal cooling entirely: `fan2` and the case pair must carry everything.
That design was unproven above ~42°C until this session.

Measured over 20 minutes of HITMAN 3 under Proton — 397 samples at 3s
intervals, GPU averaging 195W:

| Metric | min | mean | max |
|---|---|---|---|
| `cpu_c` | 60 | 74.9 | **89** |
| `gpu_c` | 57 | 75.9 | 80 |
| `gpu_w` | 39.6 | 194.9 | 219.6 |
| `fan1_duty` | 41 | 71.5 | 76 |
| `fan2_duty` | 47 | 69.8 | 87 |
| `fan3_duty` | **14** | **14** | **14** |

**`fan3` never left its floor** — 0 of 397 samples above 14% duty. The 95°C
release point was never approached; the CPU peaked at 89°C and never reached
90. The quiet-secondary design holds under the workload it was built for.

**The system reaches equilibrium rather than creeping.** Per 5-minute block,
loaded samples only (`gpu_w > 150`):

| Block | CPU avg | CPU max | GPU avg | `fan2` |
|---|---|---|---|---|
| 0–5 min | 73.9 | 84 | 77.3 | 64.5% |
| 5–10 min | 77.2 | 89 | 77.8 | 72.4% |
| 10–15 min | 77.4 | 89 | 77.5 | 73.9% |
| 15–20 min | 75.5 | 87 | 77.3 | 73.4% |

It climbs ~3°C over the first ten minutes and then plateaus — the last block is
cooler than the two before it. `fan2` settles near 73% with 13 points of duty
still unused, so the curve holds reserve even at its worst moment. The GPU sits
flat at ~77.5°C against a ~83°C throttle point.

### Transient spikes are the smoothing, not the curve

7 samples (1.8%) reached 85°C. All are single-interval spikes on a load
transition: a loading screen drops GPU draw, the fans wind down, and a CPU
burst lands before they recover.

```
t=421  cpu=71  gpu_w=206  fan1=43%  fan2=54%
t=424  cpu=72  gpu_w=216  fan1=43%  fan2=54%
t=427  cpu=89  gpu_w=75   fan1=43%  fan2=54%   <- spike; fans still low
t=430  cpu=79  gpu_w=220  fan1=54%  fan2=61%
t=439  cpu=76  gpu_w=217  fan1=65%  fan2=81%
```

`CPU Main` specifies 85°C → 100%, but `Smooth` carries `response_delay = 8`, so
a temperature must hold roughly 8s before the duty moves. A 3-second spike is
over before `fan2` is permitted to react. That is the function behaving as
configured, not a curve error.

**Do not lower `response_delay` to chase these.** It would make the fans surge
on every load transition — precisely the noise the smoothing exists to prevent
— for no thermal benefit, since 89°C sits 11°C below Tjmax. If the peaks ever
do matter, raise the `CPU Main` knee instead (75°C → 80% rather than 70%) so a
spike starts from a higher baseline.

### Still unmeasured

Sessions longer than 20 minutes, and ambient temperatures other than that
evening's. Equilibrium arrived by minute 10 and held, so extended play is
unlikely to differ, but it has not been observed.

A synthetic CPU-only stress test remains **not** a valid substitute: the
case-fan curve has a GPU leg, and a 3070 pushing 220W into a mini-ITX case is
most of the heat. A CPU-only test exercises none of that and would falsely
reassure.

## CoolerControl daemon API

Useful for scripting profiles instead of clicking through the GUI.

```bash
curl -sS -X POST -u 'CCAdmin:coolAdmin' -c /tmp/cc.jar http://localhost:11987/login
curl -sS -b /tmp/cc.jar http://localhost:11987/devices
curl -sS -b /tmp/cc.jar http://localhost:11987/profiles
```

Endpoints: `/devices`, `/profiles`, `/functions`, `/status`, and
`PUT /devices/<uid>/settings/<channel>/profile` with `{"profile_uid": "..."}`.

Two traps:

- **UUIDs are client-supplied.** Posting `"uid": ""` creates an unusable record
  that the API then refuses to delete (405/500). Always send a real UUID.
- **`POST` returns 200 with an empty body**, not the created object. Re-`GET`
  the collection to confirm what landed.

### Editing `config.toml` by hand

`/etc/coolercontrol/config.toml` is root-owned and the daemon rewrites it at
runtime, so stop the service before editing or your changes are overwritten.

Be careful removing a `[[...]]` block: a naive regex once consumed the trailing
comment block **and the entire `[settings]` table**, and the daemon then failed
to start with `Error: Setting table not found in configuration file`. Prefer a
line-based edit that stops at the next line beginning with `[` or `#`, and diff
before applying.
