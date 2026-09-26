# Working in this repo

Personal dotfiles for an Omarchy (Arch + Hyprland) desktop, managed with GNU
Stow. `README.md` covers layout and usage; this file is the things that will
bite you.

## Ground rules

**Simulate stow before applying, and always pass `--no-folding`.**

```bash
cd ~/dotfiles && stow --no-folding -n -v <package>
```

Without `--no-folding`, stow can replace a whole directory with one symlink.
`~/.config/omarchy` and `~/.config/hypr` hold Omarchy-managed files alongside
ours; folding them would swallow files this repo does not own.

**Do not commit.** The user commits. Leave the working tree for them to review.

**`bootstrap.sh` must stay idempotent.** After any change, verify:

```bash
./bootstrap.sh --dry-run     # then run for real, then dry-run again
```

A second run must report `everything already in place; nothing to do`.

## Shell traps that have already caused bugs here

**`grep -q` in a pipeline under `set -o pipefail` is a race.** `grep -q` exits
on first match, the upstream process dies of SIGPIPE, and `pipefail` turns that
into a false condition. This silently broke a module check and lurked in the
YubiKey checks, which passed only by timing luck. Capture output into a variable
first, or test a sysfs path (`[[ -d /sys/module/$m ]]`).

**`acting "..." && { ... }` trips `set -e`.** In dry-run the guard returns
non-zero, the compound fails, and the whole run aborts. Use `if acting "..."; then`.

**`grep`, `sed` and `find` are shell functions in the user's interactive shell.**
They error on ordinary flags (`grep -q` → `unknown option '-G'`). Inside the
Bash tool use `command grep` / `command sed` / `command find`. Scripts run via
`bash script.sh` get the real binaries, so this affects ad-hoc commands only.

**`bash/.bashrc` is stowed on non-Omarchy machines too.** Anything Omarchy-
specific added to it must be guarded, or it errors on every interactive shell
on those boxes. `source "$OMARCHY_PATH/default/bash/rc"` was unguarded and did
exactly that; it now tests `[[ -r ... ]]` first. The same applies to any new
stow package that only makes sense under Omarchy — gate it in `step_stow`'s
`case` on `have omarchy`, next to `hypr` and `omarchy`. The `fish` package is
gated the same way on `have fish`.

**Anything added to `bash/.bashrc` is invisible on a fish machine.** fish
never reads `.bashrc`, so an export or helper function added there exists on
Omarchy and silently does not on the CachyOS desktop. This already bit
`yk-reload` and `SSH_ASKPASS`: the agent, the socket, pcscd and the key were
all healthy, and the only symptom was `yk-reload: command not found` in the
login shell. When adding to `.bashrc`, ask whether it is bash sugar (stays put)
or environment/a helper (mirror it in the `fish` package):

| bash | fish |
|---|---|
| `export FOO=bar` in `.bashrc` | `set -gx FOO bar` in `fish/…/conf.d/<topic>.fish` |
| `foo() { ...; }` in `.bashrc` | `fish/…/functions/foo.fish`, **named after the function** (fish autoloads by filename) |

`aegis shell-init` is the known gap — it has a bash hook in `.bashrc` and no
fish equivalent here, because whether `aegis shell-init fish` exists has never
been checked. Verify before adding it; an init that errors runs on every shell.

**Nothing but Omarchy's rc used to run `starship init`.** The `starship`
package stowed a config that, off Omarchy, no shell ever read — installed,
correct, and inert, with nothing reporting a problem. There are now two
guarded inits and they must stay mutually exclusive:

| Shell | Where | Guard |
|---|---|---|
| bash | `bash/.bashrc`, just below the Omarchy rc source | `[[ ! -r "${OMARCHY_PATH-}/default/bash/rc" ]]` — the exact negation of the source above it |
| fish | `fish/.config/fish/conf.d/starship.fish` | `type -q starship` |

Two inits means two prompt hooks, so do not weaken either guard. In bash the
block must also stay **between** ble.sh's `--noattach` and `ble-attach`, for
the same reason the rc does.

**Do not rename `fish/.config/fish/conf.d/starship.fish`.** fish sources every
`conf.d` — user, system and `vendor_conf.d` — as one alphabetically ordered
list. `starship.fish` sorts after `pure.fish`, which is what keeps CachyOS's
`fish-pure-prompt` from taking the prompt back. Any name sorting before `p`
loses the prompt silently.

**Never enable a CIFS `.mount` unit directly — enable its `.automount`.** A
boot-time CIFS mount that cannot reach its server stalls the boot and hangs
`df`, and on a laptop the tailnet is frequently unreachable. The same goes for
an fstab line without `x-systemd.automount`. See `docs/smb-shares.md`.

**The SMB credentials file is deliberately not in this repo.** `mount.cifs`
needs the password in plaintext at mount time, so age-encrypting it would only
move the problem and would put a YubiKey touch in the path of a filesystem
mount. It is machine-local at `/etc/samba/credentials/<host>`, root-owned, mode
600, and `step_smb_shares` reports its absence rather than creating one.

**`hosts/omarchy/` and `hosts/cachyos/` are the same physical desktop** — two
drives, two OSes, one box, and only one can run at a time. They are separate
directories only because `host-config` keys on hostname. So they can never both
be on the tailnet, and their CoolerControl configs describe identical hardware.
`docs/machines.md` has the full fleet.

**Tailscale is first-party in Omarchy.** There is an `omarchy.tailscale` bar
widget, a Taildrop receive unit and an `omarchy-install-service-tailscale`
script. Do not reach for a third-party Tailscale plugin — the built-in one is
better and carries none of the unsandboxed-QML risk. `step_tailscale` mirrors
Omarchy's installer but deliberately never runs `tailscale up`: that is a
browser auth flow, and running it every bootstrap would also stomp flags set
by hand.

**"Cloned" is not "enabled" for a plugin.** `omarchy plugin add --enable`
clones first and enables second, and the enable needs the running shell --
which a remote `ssh host ./bootstrap.sh` cannot reach. Checking only for
`~/.config/omarchy/plugins/<id>/` therefore reports "plugin present" forever
while the plugin stays disabled. Use `plugin_state <id>`, which returns
`enabled`/`disabled`/`absent`, and `ensure_plugin <id> <url>`, which adds or
enables as appropriate.

**A non-interactive `ssh host ./bootstrap.sh` does not read `~/.bashrc`.** That
is where `OMARCHY_PATH` comes from, so without it every `omarchy` call fails
with "OMARCHY_PATH is not set" -- and because each step reports its own
failure and keeps going, the run still **exits 0** while silently skipping
every plugin and bar step. `bootstrap.sh` now sources
`/usr/share/omarchy/default/bash/env-bootstrap` itself when `OMARCHY_PATH` is
empty. Do not assume the caller's shell has set it.

**Do not pass `-tt` to ssh when running bootstrap remotely.** It forces a PTY,
`configure_modules` then believes it is interactive, and the run blocks
forever on a prompt for any module key the remote `bootstrap.conf` lacks.
Without a TTY it falls back to defaults, which is the documented behaviour.

## Elevation

There is **no passwordless sudo**. Interactive `sudo` hangs in a non-TTY
context. Use `pkexec` for one-off privileged commands (graphical prompt). Tools
that self-elevate and need a terminal — `limine-scan`, `yay` — must be run by
the user; the `!` prefix does not provide a TTY either.

`bootstrap.sh` itself uses `sudo` because a human runs it in a real terminal.

## Package installs

Prefer Omarchy's wrappers, with a fallback:

```bash
omarchy-pkg-add <pkgs>          # repo packages
omarchy-pkg-aur-add <pkgs>      # AUR (wraps yay)
```

They add a post-install `pacman -Q` verification pass that catches the case
where the installer exits 0 but the package never landed. Both imply
`--noconfirm`. Omarchy does not track AUR packages in a registry —
`omarchy-update-aur-pkgs` just runs `yay -Sua` over `pacman -Qem` — so nothing
is lost by installing outside the wrapper.

**Do not assume an AUR helper exists.** The CachyOS desktop has neither `yay`
nor `paru`, so anything routed through `step_aur_packages` there is skipped
with a note and never installed. CoolerControl used to be exactly that: the
package silently missing while `nct6775`, the service and the host files all
reported success around the gap.

Where a distro ships a package in its own repos, prefer that channel. Use
`repo_has <pkg>` (a `pacman -Si` probe) to decide per machine rather than
hardcoding one — `PKG_COOLERCONTROL` / `AUR_COOLERCONTROL` is the worked
example, and the two call sites must stay complementary so the package is
never requested from both.

## Omarchy writes through our symlinks

Several stowed files are targets of Omarchy commands that do a plain `cp`:

| Command | Overwrites |
|---|---|
| `omarchy branding screensaver reset` | `omarchy/.config/omarchy/branding/screensaver.txt` |
| `omarchy refresh config hypr/bindings.lua` | `hypr/.config/hypr/bindings.lua` |
| `omarchy refresh config foot/foot.ini` | `foot/.config/foot/foot.ini` |
| OmaSettings GUI (third-party plugin) | `hypr/bindings.lua`, `hypr/looknfeel.lua`, `.tmux.conf`, `.bashrc` |

They land in the repo, not just in `~`. The `omarchy` commands overwrite with
defaults (destructive -- flag before suggesting either). OmaSettings makes
targeted edits, so a dirty working tree after the user opens it is expected
rather than a problem.

## This repo is public

Treat every file here as world-readable. Before suggesting anything be
committed:

- **Never add secrets, tokens, private keys or credentials**, even commented
  out or "temporarily". `.gitignore` covers the obvious shapes but cannot catch
  a secret pasted into a tracked file.
- **Do not add machine-identifying detail that has no documentation value** —
  device serial numbers are the example that already had to be removed once.
  Hardware model names in `hosts/<hostname>/` are a deliberate exception; the
  config does not work without them.
- **`ssh/.ssh/config` is tracked and currently safe** (github/gitlab only).
  When work hosts are added it stops being safe — flag moving the `ssh`
  package to a private repo rather than redacting it in place.
- Run `git add -An .` to see exactly what would be staged before recommending a
  commit.

## Modules

`bootstrap.conf` (git-ignored, per machine) records which modules run here.
`enabled <key>` gates each optional step; keys are in `MODULE_KEYS`.

Adding a module: append to `MODULE_KEYS`, add a `module_desc` case, a
`module_default` case if it should default off, and guard the relevant steps
with `enabled <key> || return 0`. Existing machines are prompted only for the
new key — do not invalidate their saved answers.

Never make `configure_modules` block without a TTY; it must fall back to
defaults so non-interactive runs cannot hang.

## Work environment: no names in this repo

`bootstrap.sh` contains **zero** employer, project or host names, and it must
stay that way. Every such name lives in the work manifest
(`~/.config/dotfiles/work-repos`, encrypted as `secrets/work-repos.age`).

When adding work behaviour, add a **manifest directive** and a generic loop —
never a hardcoded name. Existing directives: `root`, `tool`, `shared`,
`pinfile`, `worktree`, `devhome`, `settings`, `image`, `services`, `credtool`,
`webapp`. If a step needs a new fact about the work setup, that fact belongs in
the manifest.

A URL is a name. An internal link like a Bitbucket pull-request page carries
the employer in its path, so it belongs in the manifest as a `webapp`
directive, not in the `WEBAPPS` array at the top of `bootstrap.sh` — that
array is for generic product URLs (linear.app) with no org in them.

The credentials gate in `step_work_setup` is deliberate: mechanical work runs
unconditionally, and only image builds and container startup sit behind a
loaded credential profile. Do not move work above or below that line without
reason.

## Host-specific files

Root-owned files under `/etc` cannot be stowed. They live in
`hosts/<hostname>/` and are managed with `host-config` (`diff` / `capture` /
`restore`).

**Never overwrite a drifted host file automatically.** CoolerControl rewrites
its config at runtime, so the live copy may hold tuning done in a GUI since the
last capture. `bootstrap.sh` reports drift and leaves it; `--restore-host` is
the explicit opt-in.

**A CoolerControl config is keyed to UIDs, not to hardware.** A UID that does
not match the running daemon's applies **nothing** — no error, no log line,
fans left on the motherboard's own curves while the GUI looks correctly
configured. Never copy a config between hosts without checking the UIDs first.

**For `omarchy` ↔ `cachyos` specifically, that check has been done.** They are
the same physical desktop, and on 2026-09-20 all seven UIDs the CachyOS daemon
reported were byte-identical to the Omarchy copy, including the only three any
profile depends on (`nct6791`, the RTX 3070, the i9-9900K). The two
`config.toml` files are deliberately identical, so CoolerControl's UIDs are
reproducible across distros on one machine. Re-verify after a hardware change
rather than assuming it still holds:

```bash
journalctl -u coolercontrold.service -o cat \
  | command grep -oE '"name":"[^"]+","uid":"[0-9a-f]{64}"' | sort -u
```

**The `[devices]` table lags the first start by one write.** The daemon writes
`config.toml` before it finishes enumerating (config at `…:42`, `Initialization
Complete` at `…:44`), so immediately after a first install that table is empty
and a naive `host-config capture` would record a config with no devices in it.
It is a generated comment block — "ANY CHANGES WILL BE OVERWRITTEN" — so this
costs nothing, but do not read an empty `[devices]` as "the daemon found no
hardware". Read the journal instead.

## Hardware facts that are easy to get wrong

Full detail in `docs/thermals.md` and `docs/yubikey-ssh.md`. The short version:

- **On the laptop, clamshell runs COOLER and SLOWER.** Measured: 82.7°C /
  2607 MHz closed vs 91.0°C / 2851 MHz open, same load. Intel DPTF manages
  chassis skin temperature, so a closed lid traps heat against the keyboard,
  DPTF clamps package power, and both clocks and die temperature fall together.
  Never read the lower closed-lid temperature as spare headroom — it is sitting
  on a different limit. See `docs/laptop-thermals.md`.
- **`CPUTIN` reads −63°C.** Unwired header, ASRock quirk. Never use it as a fan
  curve source. Use `CPU Temp Package Id 0` or `PECI Agent 0`.
- **`fan3` cannot stop.** Hard floor ~815 RPM at any duty including 0. It is the
  thin secondary CPU fan and the loudest thing in the case. Its curve pins it
  there until 95°C, and a 20-minute gaming session never moved it off the floor
  (0 of 397 samples; peak CPU 89°C). Curves are validated to 89°C -- see
  `docs/thermals.md`.
- **The SSH key is PIV slot 9A, not FIDO2.** `ssh-keygen -K` asks for the wrong
  PIN and burns a FIDO2 attempt. PIV has **3** attempts; FIDO2 has 8 and a reset
  destroys credentials that have no backup. Never guess a PIN.
- **Never add `PKCS11Provider` to `~/.ssh/config`.** The module is loaded into
  `ssh-agent` instead. Both at once opens competing PIV sessions and signing
  fails with `agent refused operation`. Keep `IdentitiesOnly` — the agent now
  offers **seven** identities (slot 9A, five retired slots, attestation)
  against a default `MaxAuthTries` of 6, so it is over the limit rather than
  exactly at it. Re-count with `ssh-add -l` rather than trusting this number.
- **The `-P` whitelist needs `libykcs11.so*`, not `libykcs11*.so`.** OpenSSH
  canonicalises to `libykcs11.so.2.7.3`, which a trailing-`.so` pattern cannot
  match; `ssh-add -s` then fails with `agent refused operation` despite a
  correct PIN.
- **`age -d` with a YubiKey identity needs a real TTY** for the PIN prompt, so
  it cannot be driven from a non-interactive tool call.
- **Never `:Lazy sync`/`:Lazy update`** in Neovim — use `:Lazy restore`.

## Unfinished

- `gopls` is enabled but cannot install without the Go toolchain.
- **Untested lid edge case on AC.** `hosts/panther/` sets
  `HandleLidSwitchExternalPower=ignore` so losing the external display in
  clamshell does not suspend the laptop. The side effect is that on AC a lid
  close is never acted on at all. Unknown: whether closing the lid while the
  machine is *already* suspended wakes it. If it does, it would now stay awake
  with the lid shut instead of going back to sleep — a hot laptop in a bag.
  The journal cannot answer it: all 12 suspends recorded so far were triggered
  BY a lid close, so the sequence never occurred. The nearest evidence is
  reassuring but indirect — on 2026-09-16 it held s2idle from 17:50 to 19:21
  with the lid shut. To settle it: `systemctl suspend`, close the lid once
  asleep, wait ~15s, open it, then
  `journalctl -b | grep -iE 'PM: suspend (entry|exit)|Lid (opened|closed)'`.
  Two `suspend entry` lines means closing the lid woke it and the rule needs
  narrowing; one means it behaved.
- **VPN.ac alongside Tailscale is undecided.** Tailscale is set up and works.
  Whether a commercial full-tunnel VPN can run beside it — kill switches are
  the decider, exit nodes are mutually exclusive — plus the fact that a
  WireGuard `.conf` carries a **private key that cannot go in this public
  repo**, are written up in `docs/vpn.md`. Settle the kill-switch question
  before writing a `vpn` module.
- **`hosts/` has no concept of a file shared between machines.** Both
  `host-config` (`HOST="$(hostnamectl hostname)"`) and `step_host_files`
  (`hosts/$HOSTNAME_SHORT`) resolve everything under one per-hostname
  directory, so a file wanted on two machines has to exist twice. Today that
  is the pair of SMB mount units, byte-identical in `hosts/panther/` and
  `hosts/omarchy/` — same share, same mount point, both boxes on uid/gid 1000,
  nothing hardware-derived. The risk is silent drift: edit one, forget the
  other, and nothing complains. Options when it becomes worth fixing: a
  `hosts/_common/` layer applied before the host directory; repo-internal
  symlinks (check whether `host-config` copies or follows them first); or keep
  duplicating and add a cheap guard that warns when same-named files differ
  across host directories. The guard alone would remove most of the risk for
  very little code.
- **macOS support is designed but not built.** An existing MacBook stays in
  occasional use and wants the same tool set. The plan, the measurement it
  rests on (36 of 65 tracked files are already OS-agnostic; exactly one file,
  `bash/.bashrc`, genuinely varies) and a recorded evaluation of chezmoi are in
  `docs/multi-os.md`. Two things to keep in mind before touching this: the
  portable surface needs **no** templating, and **nothing should generate
  files** — Omarchy writes through the stow symlinks into this repo, which only
  works while a symlink points at real tracked content.
- **Wake-on-LAN is not armed** on the laptop's USB ethernet adapter (Realtek
  `0bda:8153`). Closing the lid on battery suspends to s2idle, and plugging in
  AC cannot wake it — `ACAD` exposes no `wakeup` attribute at all. The only
  working wake today is a keypress on the external USB keyboard (Massdrop ALT,
  `04d8:eed3`), whose USB-level wakeup is already enabled, same as the LAN
  adapter's. A magic packet would add waking the machine from another host with
  the lid shut. Unverified whether the adapter supports it: `ethtool` is not
  installed, so `ethtool <if> | grep Wake-on` has never been run. If it does,
  arming it is a udev rule, and being root-owned that belongs in
  `hosts/<hostname>/` rather than a stow package.
