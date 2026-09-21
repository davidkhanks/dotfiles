# Multi-OS support (planned, not implemented)

Notes for extending this repo to a machine that is not Arch. The concrete case
is an existing MacBook that stays in occasional use after the migration to
Linux, where the goal is a consistent tool set — nvim, tmux, starship, shell —
rather than identical configuration.

**Nothing in this document is implemented as of 2026-09-20.** It exists so the
analysis does not have to be redone. The Arch-derivative work (CachyOS) *is*
done and is described in README under "Non-Omarchy machines".

## Start from the measurement, not the tooling

Counting files that reference `/usr/{lib,share,bin}`, `XDG_RUNTIME_DIR`,
systemd, pacman, `.desktop`, `hyprctl` or `/proc`:

| package | files with Linux-isms |
|---|---|
| `nvim` | 0 / 33 |
| `starship` | 0 / 1 |
| `tmux` | 0 / 1 |
| `ssh` | 4 / 4 — but three are systemd units; `.ssh/config` is portable |
| `bash` | 1 / 1 |
| `bin` | 2 / 2 — `host-config` and `thermal-log` are both Linux-only tools |
| `hypr`, `omarchy`, `slack` | Linux-only by definition |

**36 of 65 tracked files are already OS-agnostic**, and they are exactly the
ones that constitute "the tool set". The portable surface needs no templating
at all; it needs `brew install stow`.

Exactly one tracked file genuinely varies by OS:

```
bash/.bashrc:2   /usr/share/omarchy/default/bash/env-bootstrap
bash/.bashrc:44  _ble_contrib_fzf_base=/usr/share/fzf
bash/.bashrc:63  SSH_AUTH_SOCK="${XDG_RUNTIME_DIR:-/run/user/$UID}/ssh-agent.sock"
bash/.bashrc:64  SSH_ASKPASS=/usr/bin/lxqt-openssh-askpass
bash/.bashrc:71  local lib=/usr/lib/libykcs11.so
```

## The plan: three tiers, and only the first two are needed

**Tier 1 — branch at runtime.** Anything with conditional syntax templates
itself. `.bashrc` with `case "$OSTYPE" in darwin*|linux*)`, `.tmux.conf` with
`if-shell`, git with conditional includes. On macOS the fzf path is
`$(brew --prefix)/opt/fzf/shell` — write it that way, not hardcoded, because
the prefix differs between Apple Silicon and Intel.

This preserves the property that makes stow worth keeping: **the symlink points
at the real tracked file.** Omarchy and OmaSettings write through those
symlinks into the repo (see the table in CLAUDE.md). Generating files would
break that.

**Tier 2 — select stow packages by OS.** The machinery already exists:
`step_stow` has a `case "$pkg"` that gates `slack` on a module and `hypr`/
`omarchy` on `have omarchy`. Add an OS predicate to the same block, roughly 15
lines. Grouping:

- portable: `nvim`, `starship`, `tmux`
- Linux-only: `hypr`, `omarchy`, `slack`, `bin`
- **`ssh` must be split first.** `ssh/.ssh/config` is portable, but the three
  systemd units in the same package are not. Split into `ssh` (config) and
  `ssh-agent` (units, Linux-only).

**Tier 3 — an actual render step.** For a file with no conditional syntax
(JSON, `.desktop`). **There is no such file today. Do not build this until one
forces it.** The moment files are generated, symlinks stop pointing at tracked
content, Omarchy's write-through breaks, and the repo inherits chezmoi's
problem without chezmoi's tooling.

## `bootstrap.sh` on macOS: don't port it

The script is pacman, systemd, udev and PIV. Porting the provisioning is a much
larger job than the configs, and it would be built for a machine being migrated
away from.

The proportionate answer is a **`--stow-only` mode** alongside `--dry-run` and
`--restore-host`: skip provisioning, stow the portable packages, install the
few tools with brew by hand. Roughly 20 lines.

## macOS gotchas to expect

- macOS ships **bash 3.2** and defaults to zsh. ble.sh needs bash 4+, so
  `brew install bash`, and it is not the login shell unless changed.
- Terminal.app runs *login* shells, which read `.bash_profile`, not `.bashrc`.
  A one-line `.bash_profile` that sources `.bashrc` is needed.
- `stow` is not preinstalled.

## Why not chezmoi (evaluated 2026-09-20)

Worth recording so the evaluation is not repeated. chezmoi 2.72.1 is in Arch
`extra`. What it does well, verified against its docs:

- Templates (`text/template`) with `.chezmoi.os`, `.chezmoi.hostname`,
  `.chezmoi.osRelease.id`, and a **templated `.chezmoiignore`** — a cleaner
  version of the per-OS package selection in Tier 2.
- **The age setup ports cleanly.** `age.command`, `age.args` and `age.identity`
  are all configurable, and chezmoi shells out to the real `age` binary when it
  is on `$PATH`. Since age plugins are resolved by `age` itself,
  age-plugin-yubikey keeps working. The current call —
  `age -d -i "$WORK_REPOS_AGE_IDENTITY" -o "$tmp" "$WORK_REPOS_AGE"` — maps 1:1
  onto `[age] identity = ...`. This was the most likely blocker and is not one.
- `.chezmoiexternal.toml` would replace the hand-written ble.sh and plugin
  clone steps.

Why it still loses here:

- **It writes real files, not symlinks.** OmaSettings edits would land in `~`,
  show as drift, and be reverted by the next `chezmoi apply`; every session
  with it would need a `chezmoi re-add`. There is a `symlink_` target type as a
  workaround, but it is the less idiomatic path and forfeits templating on
  exactly those files.
- **`chezmoi apply --dry-run` does not run scripts** — its docs say so
  outright. `./bootstrap.sh --dry-run` narrating 28 steps and ending in
  "everything already in place; nothing to do" is the feature used most often
  here, and chezmoi gives nothing equivalent for the provisioning half.
- **It manages `$HOME` only.** No privilege model, so `hosts/<hostname>/` and
  `host-config` stay either way.
- The repo is 65 files, 33 of them nvim. The value is in `bootstrap.sh`, and
  chezmoi does not replace it — it absorbs it as opaque `run_` scripts, taking
  the module system and the per-step reporting with it.

**What would flip this:** needing to template *many* files across OS families.
One branching file and a 33-file portable nvim config is not that. Revisit if
the portable surface starts needing real per-OS divergence, or past ~4 machines.

## Effort

Tier 1 + Tier 2 + `--stow-only` is about an afternoon, mostly mechanical, and
entirely additive — no behaviour change on the Linux side. Tier 3 is not
scoped because it should not be built yet.
