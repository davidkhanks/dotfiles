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

## Omarchy writes through our symlinks

Several stowed files are targets of Omarchy commands that do a plain `cp`:

| Command | Overwrites |
|---|---|
| `omarchy branding screensaver reset` | `omarchy/.config/omarchy/branding/screensaver.txt` |
| `omarchy refresh config hypr/bindings.lua` | `hypr/.config/hypr/bindings.lua` |
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

## Hardware facts that are easy to get wrong

Full detail in `docs/thermals.md` and `docs/yubikey-ssh.md`. The short version:

- **`CPUTIN` reads −63°C.** Unwired header, ASRock quirk. Never use it as a fan
  curve source. Use `CPU Temp Package Id 0` or `PECI Agent 0`.
- **`fan3` cannot stop.** Hard floor ~815 RPM at any duty including 0. It is the
  thin secondary CPU fan and the loudest thing in the case.
- **The SSH key is PIV slot 9A, not FIDO2.** `ssh-keygen -K` asks for the wrong
  PIN and burns a FIDO2 attempt. PIV has **3** attempts; FIDO2 has 8 and a reset
  destroys credentials that have no backup. Never guess a PIN.
- **Never add `PKCS11Provider` to `~/.ssh/config`.** The module is loaded into
  `ssh-agent` instead. Both at once opens competing PIV sessions and signing
  fails with `agent refused operation`. Keep `IdentitiesOnly` — the agent
  offers six identities and the default `MaxAuthTries` is 6.
- **The `-P` whitelist needs `libykcs11.so*`, not `libykcs11*.so`.** OpenSSH
  canonicalises to `libykcs11.so.2.7.3`, which a trailing-`.so` pattern cannot
  match; `ssh-add -s` then fails with `agent refused operation` despite a
  correct PIN.
- **`age -d` with a YubiKey identity needs a real TTY** for the PIN prompt, so
  it cannot be driven from a non-interactive tool call.
- **Never `:Lazy sync`/`:Lazy update`** in Neovim — use `:Lazy restore`.

## Unfinished

- Fan curves are **unvalidated above ~42°C**. `fan3` is pinned to its floor
  until 95°C by explicit user choice, leaving 5°C to Tjmax. Needs a real
  workload logged with `thermal-log` before it can be trusted.
- `gopls` is enabled but cannot install without the Go toolchain.
