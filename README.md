# dotfiles

Personal configuration for an Omarchy (Arch + Hyprland) desktop, managed with
GNU Stow and reproduced by `bootstrap.sh`.

## Quick start on a new machine

```bash
git clone https://github.com/davidkhanks/dotfiles.git ~/dotfiles
cd ~/dotfiles
./bootstrap.sh --dry-run    # see what it would change
./bootstrap.sh              # do it
```

`bootstrap.sh` is idempotent — re-running it on a configured machine reports
`everything already in place; nothing to do` and changes nothing. Run it freely
after pulling changes.

| Flag | Effect |
|---|---|
| `--dry-run` | Report what would change, modify nothing |
| `--nvim-sync` | Also restore Neovim plugins from `lazy-lock.json` (slow) |
| `--restore-host` | Push `hosts/<hostname>/` files back out to `/etc` (overwrites live) |
| `--reconfigure` | Re-ask which modules should run on this machine |

## Modules (per machine)

First run asks which modules apply here and saves the answers to
`bootstrap.conf` — **git-ignored**, so a desktop and a laptop each keep their
own without re-answering every run.

| Module | Covers |
|---|---|
| `yubikey` | libfido2/ykman/pcscd, `~/.ssh/config`, public key export |
| `coolercontrol` | `coolercontrol-bin`, `nct6775`, the daemon, `hosts/<host>/` config |
| `slack` | `slack-desktop`, the Wayland desktop entry, MIME database |
| `work_repos` | `age` tooling, decrypting the manifest, cloning the repos |
| `work_setup` | dev environment: local tools, worktrees, container homes, images |
| `nvim_default` | symlink `~/.config/nvim` at this config |
| `nvim_sync` | `:Lazy restore` on every run (off by default — slow) |

Turning a module off removes its packages, services, kernel modules and host
files from the run entirely — a laptop with `coolercontrol=no` never installs
CoolerControl, never loads `nct6775`, and never touches `/etc`.

Edit `bootstrap.conf` by hand or re-run with `--reconfigure`. A new module added
later prompts only for itself, leaving existing answers alone. Non-interactive
runs (CI, piped input) fall back to defaults instead of hanging.

## Layout

```
bootstrap.sh          idempotent setup script
bin/                  scripts -> ~/.local/bin
hypr/                 Hyprland keybindings
nvim/                 Neovim config (davidkhanks-nvim)
omarchy/              Omarchy branding + hooks
slack/                Slack desktop entry with Wayland flags
ssh/                  ~/.ssh/config
starship/  tmux/      prompt and tmux
hosts/<hostname>/     machine-specific root-owned files (not stowed)
docs/                 reference notes
```

Every directory at the top level except `hosts/`, `docs/` and `bin`'s contents
is a stow package. `.stowrc` sets `--target=$HOME`.

## Stow

```bash
cd ~/dotfiles
stow --no-folding <package>              # link one package
stow --no-folding --restow <package>     # re-link after changes
stow -D <package>                        # unlink
stow --no-folding -n -v <package>        # simulate (always do this first)
```

**Always pass `--no-folding`.** Without it stow may replace an entire
directory with a single symlink. Under `~/.config/omarchy` and
`~/.config/hypr` — which also hold Omarchy-managed files — that would swallow
files this repo does not own. `bootstrap.sh` always passes it.

## Machine-specific config

Stow only targets `$HOME`, so root-owned files under `/etc` are tracked per
host in `hosts/<hostname>/` and managed with `host-config`:

```bash
host-config diff       # show drift between live files and the repo
host-config capture    # pull live files into the repo, then commit
host-config restore    # push repo files back out (needs sudo)
```

Today that is CoolerControl's fan curves. They are **not portable** — the
config embeds hardware-derived device UIDs and curves tuned to this box's
specific fans. See `docs/thermals.md`.

`bootstrap.sh` deliberately **does not** overwrite a drifted host file, because
the live copy may hold tuning done in a GUI since the last capture. It reports
the drift and leaves it alone; `--restore-host` opts into overwriting.

## Work environment

`work_repos` clones the repositories; `work_setup` prepares them to run. Both
are driven entirely by a manifest — **no employer, project or host name appears
anywhere in this repo outside the encrypted file**. The script provides the
mechanism; the manifest provides every name.

The manifest lives at `~/.config/dotfiles/work-repos` (plaintext, outside this
repo) and as `secrets/work-repos.age` (encrypted to a YubiKey identity plus a
backup key, safe to commit). Plaintext wins when present; otherwise the
encrypted copy is decrypted to a `600` temp file and shredded after use.

Directives:

```
root <path>                     where repos are cloned
<git-url> [dirname]             a repo to clone
tool <dir>                      repo to build+install with `make install`
shared <dir>                    repo whose ./dev creates per-project worktrees
pinfile <name>                  file in each project naming its pinned ref
worktree <wt-dir> <project>     worktree to create, pinned by that project
devhome <project>               project needing a container home directory
settings <project> <src> <dst>  per-developer settings file to seed
image <project> <dev-subcmd>    container image to build
services <project>              project providing shared services; started first
credtool <command>              credential manager named in help text
```

`work_setup` stops at a **credentials gate**: everything mechanical (docker,
tools, worktrees, container homes, settings) runs unconditionally, then it
checks for a loaded credential profile before building images or starting
containers. Without one it prints what to run and exits cleanly, so a fresh
machine still gets fully prepared in one pass.

## Docs

- [`docs/thermals.md`](docs/thermals.md) — fan topology, sensor traps, curve design
- [`docs/yubikey-ssh.md`](docs/yubikey-ssh.md) — YubiKey PIV SSH setup
- [`docs/neovim.md`](docs/neovim.md) — Neovim config and plugin pinning
- [`hosts/omarchy/README.md`](hosts/omarchy/README.md) — this desktop's specifics

## This repo is public

Before committing, remember that everything here is world-readable.

- **`ssh/.ssh/config` is tracked.** Today it only names github/gitlab. The
  moment work hosts, bastions or internal hostnames go in, they are public.
  When that time comes, move the `ssh` package to a private repo rather than
  redacting piecemeal.
- **`hosts/<hostname>/` discloses hardware.** CoolerControl's config names the
  CPU, GPU, drives and WiFi chip, plus stable device UIDs. Required for the
  config to work, and low risk, but it is a machine fingerprint.
- **No secrets, ever** — not even "temporarily". `.gitignore` blocks the
  obvious shapes (`*.pem`, `*.key`, `id_*`, `.env`, `known_hosts`, `*.csv`),
  but it cannot catch a secret pasted into a tracked file.
- **`thermal-log` output is ignored** (`*.csv`); it records hardware behaviour,
  not secrets, but there is no reason to publish it.

Check what you are about to publish:

```bash
git add -An .        # exactly what would be staged
git diff --cached    # after staging, read it before pushing
```

## Gotchas worth knowing

**Omarchy commands write through symlinks.** `omarchy branding screensaver
reset` does a plain `cp` over `~/.config/omarchy/branding/screensaver.txt`,
which is now a symlink into this repo — so it overwrites the repo file. Same
for `omarchy refresh config hypr/bindings.lua`. Recoverable with git, but do
not reach for them casually.

**`~/.config/nvim` is a symlink to `davidkhanks-nvim`.** The nvim package
installs to `~/.config/davidkhanks-nvim`; bootstrap links `~/.config/nvim` at
it so plain `nvim` picks it up everywhere. Omarchy's stock LazyVim was moved to
`~/.config/nvim.lazyvim.bak`.

**SSH goes through `ssh-agent`, not `PKCS11Provider`.** `~/.ssh/config`
deliberately has no `PKCS11Provider` line — the PKCS#11 module is loaded into
`ssh-agent` instead (`ssh-agent.service`, with the `-P` whitelist the stock
Arch unit lacks). Loading it in both places opens competing sessions on the
token and signing fails with `agent refused operation`. `IdentitiesOnly` stays,
because the agent offers six identities and servers default to `MaxAuthTries 6`.

Replugging the key auto-reloads the module (udev + `yubikey-ssh-reload.service`,
GUI PIN prompt). `yk-reload` is the manual equivalent. The PIN is needed once
per agent lifetime; after that it is a touch per signature.

**Never run `:Lazy sync` or `:Lazy update`.** Use `:Lazy restore`, which pins to
`lazy-lock.json`. See `docs/neovim.md`.
