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
| `brave` | Brave via Omarchy's installer, set as the default browser |
| `webapps` | launchers for sites with no Linux desktop app (Linear) |
| `airpods` | third-party shell plugin plus its compiled `librepods` daemon |
| `hyprmoncfg` | third-party plugin + AUR binary for auto-switching monitor profiles |
| `omasettings` | third-party settings GUI for Omarchy config |
| `omastats` | third-party system monitor bar widget (CPU/GPU/mem/net/temp) |
| `blesh` | `ble.sh` — fish-style autosuggestions and highlighting for bash |
| `gaming` | Steam, `gamescope`, MangoHud (off by default — large download) |
| `herdr_nav` | `C-h/j/k/l` navigation between herdr panes and Neovim |
| `work_repos` | `age` tooling, decrypting the manifest, cloning the repos |
| `work_setup` | dev environment: `aws-cli-v2`, local tools, worktrees, container homes, images |
| `nvim_default` | symlink `~/.config/nvim` at this config |
| `nvim_sync` | `:Lazy restore` on every run (off by default — slow) |

Turning a module off removes its packages, services, kernel modules and host
files from the run entirely — a laptop with `coolercontrol=no` never installs
CoolerControl, never loads `nct6775`, and never touches `/etc`.

Each third-party plugin (`airpods`, `hyprmoncfg`, `omasettings`, `omastats`)
is its own module because its QML runs **unsandboxed inside the long-lived
`omarchy-shell` process** — `omarchy plugin add` refuses without `--yes` for
exactly that reason, and three of them declare a `service` kind so they run
continuously rather than only when opened. A crash there takes the bar and
notifications with it, so each one is an explicit opt-in rather than a default.

The `airpods` module additionally compiles a C++/Qt6 daemon. Two behaviours are worth knowing: a newly added plugin does not render
until `omarchy restart shell`, and the widget hides itself unless AirPods are
connected (`omarchy bar set <id> hideWhenDisconnected false --json` pins it).

Edit `bootstrap.conf` by hand or re-run with `--reconfigure`. A new module added
later prompts only for itself, leaving existing answers alone. Non-interactive
runs (CI, piped input) fall back to defaults instead of hanging.

`gaming` installs the tools but does not configure them — nothing here reads a
Steam launch option. Under Hyprland a game generally wants `gamescope`, which
decouples its render resolution from the desktop's, matters on a fractionally
scaled output, and can cap the framerate to the panel:

```
gamescope -W 3440 -H 1440 -r 50 -f --backend wayland --mangoapp -- %command%
```

`--backend wayland` is required when Hyprland is already the display server,
and `--mangoapp` replaces wrapping the game in `mangohud` rather than adding to
it. `lib32-mangohud` is in the list because the overlay silently does nothing in
a 32-bit Proton prefix without it.

`blesh` builds [ble.sh](https://github.com/akinomyoga/ble.sh) from source into
`~/.local` — no root, and deliberately not the AUR package, which needs `yay`
(and therefore a terminal for its sudo prompt) and lags the source tree.

The stowed `.bashrc` sources it in **two parts, and the order is not optional**:
early with `--noattach`, before Omarchy's rc runs `starship init bash`, then
`ble-attach` as the last line of the file once every prompt hook is registered.
Attaching first, or sourcing after starship, leaves the two fighting over the
display. Both lines are guarded, so a machine with `blesh=no` just gets a plain
bash line editor.

## Non-Omarchy machines

This runs on any Arch derivative, not only Omarchy — the case it was built for
is a CachyOS box used purely for gaming. Four things make that work, none of
which need a flag:

- **Preflight accepts derivatives.** `/etc/arch-release` is tried first, then
  `ID=arch` or an `ID_LIKE` containing `arch` from `/etc/os-release`. CachyOS
  passes on the second test.
- **`hypr` and `omarchy` are not stowed** when the `omarchy` command is absent;
  their configs have nothing to attach to. Auto-detected rather than made a
  module, so existing `bootstrap.conf` answers stay valid.
- **AUR installs use `yay` or `paru`,** whichever is present — Omarchy ships the
  first, CachyOS the second. With neither, the step skips and names the packages
  it did not install.
- **`PACKAGES_CORE` installs the base tools** (`git starship tmux fzf neovim`)
  rather than assuming Omarchy's base image already provided them. On Omarchy
  that is a no-op.

Everything else is already gated. For a gaming-only box, turn off the
Omarchy-flavoured modules in `bootstrap.conf` (`brave`, `webapps`, `airpods`,
`hyprmoncfg`, `omasettings`, `omastats`, `herdr_nav`, `slack`) and leave
`gaming` and `coolercontrol` on. What is left is stow, bash, starship, tmux,
nvim and the fan curves.

Note that fan curves are keyed by hostname under `hosts/<hostname>/`, so a
second distro on the same desktop needs either the same hostname or its own
directory — `hosts/omarchy/` will not be found under a new one.

Genuinely Omarchy-only, and not worth porting: the bar widgets in
`~/.config/omarchy/shell.json`, the plugin system, and the theme hooks feeding
nvim's colorscheme (which already falls back to onedark on its own).

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

Entries are `<path>|<module>`; an empty module means always, a named one ties
the file to that module so turning it off removes the file from the run too.

- `hosts/omarchy/` — CoolerControl's fan curves, gated on `coolercontrol`.
  **Not portable**: the config embeds hardware-derived device UIDs and curves
  tuned to that box's fans. See `docs/thermals.md`.
- `hosts/panther/` — a logind drop-in setting
  `HandleLidSwitchExternalPower=ignore`, so losing the external display in
  clamshell mode does not suspend the laptop while it is on AC. logind resolves
  a lid close as docked → external power → default, and the middle rule is
  *ignored unless explicitly set*, so the machine otherwise falls through to
  `HandleLidSwitch=suspend` the moment it stops counting as docked.

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
webapp <name>|<url>[|<icon>]    launcher for an internal URL (pipe-delimited,
                                because the name may contain spaces)
```

`work_setup` stops at a **credentials gate**: everything mechanical (docker,
tools, worktrees, container homes, settings) runs unconditionally, then it
checks for a loaded credential profile before building images or starting
containers. Without one it prints what to run and exits cleanly, so a fresh
machine still gets fully prepared in one pass.

## Own shell plugins

Plugins written here (as opposed to the third-party ones the modules install)
live in the `omarchy` stow package under
`.config/omarchy/plugins/<user>.<name>/`. Currently that is a screenshot
button: left-click captures a region, right-click captures fullscreen.

Stow ships the files, but whether a plugin is *enabled* and where it sits in
the bar lives in `shell.json`, which is not tracked — Omarchy rewrites it
whenever you use `omarchy bar` or the settings UI. `bootstrap.sh` closes that
gap by enabling anything matching the `<user>.` id prefix, so a new plugin is
picked up just by being stowed.

Widget *properties* have the same problem, and `BAR_SETTINGS` in
`bootstrap.sh` closes it the same way — a list of `<widget-id>|<key>|<json>`
reapplied on every run:

```
omarchy.clock|format|"dddd h:mm AP"
```

Today that is the 12-hour clock. Values are JSON (passed with `--json`), so a
multi-line one like `verticalFormat` can carry `\n`. Note the clock's format
string is Qt's, not strftime: `h` is the 12-hour hour but **only** when `AP` is
present, and `HH` is always 24-hour. Right-clicking the clock cycles Omarchy's
presets and writes the result back, so the bar can drift out of step with this
list — a run puts it back.

Writing one: model it on a first-party widget in
`/usr/share/omarchy/shell/plugins/bar/widgets/`, then
`omarchy plugin validate <dir>` before enabling. Note `BarIconButton` has no
`acceptedButtons` property — its base `WidgetButton` already accepts
left/right/middle and emits `pressed(int button)`. A new plugin needs
`omarchy restart shell` before it renders; edits to an existing one hot-reload.

## Docs

- [`docs/thermals.md`](docs/thermals.md) — fan topology, sensor traps, curve design
- [`docs/laptop-thermals.md`](docs/laptop-thermals.md) — clamshell throttling, DPTF skin-temperature limits
- [`docs/yubikey-ssh.md`](docs/yubikey-ssh.md) — YubiKey PIV SSH setup
- [`docs/neovim.md`](docs/neovim.md) — Neovim config and plugin pinning
- [`docs/multi-os.md`](docs/multi-os.md) — planned macOS support, and why not chezmoi
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

**tmux loads two configs, and ours loses.** tmux's compiled-in search path is
`/etc/tmux.conf : ~/.tmux.conf : $XDG_CONFIG_HOME/tmux/tmux.conf :
~/.config/tmux/tmux.conf` — a *sequence*, not first-match. Omarchy ships a full
config at the last of those, so our `~/.tmux.conf` loads **first** and anything
Omarchy also sets silently overrides it. This bit for months unnoticed:
`prefix k` was bound here to "resize pane up" and was actually running
Omarchy's `kill-window`. Ours is now trimmed to only what Omarchy does not
provide.

**tpm cannot work on Omarchy**, and nothing here needs it. The plugin manager
discovers plugins by parsing exactly one config file and prefers
`~/.config/tmux/tmux.conf` when it exists. On Omarchy that file always exists
and carries no `@plugin` lines, so tpm finds nothing, installs nothing and exits
0 without a word — and its runtime loader uses the same lookup, so a
hand-installed plugin is never sourced either.

**Split navigation is `smart-splits.nvim`, not `vim-tmux-navigator`.** Same
`C-h/j/k/l`, but it speaks both tmux *and* herdr, and adds `M-h/j/k/l` resize
across the same boundary. The two halves work differently:

| | how |
|---|---|
| tmux | no plugin at all — Neovim sets a pane-local `@pane-is-vim` and the stowed tmux config reads it |
| herdr | a herdr plugin shipped *inside* the Neovim plugin's repo, linked with `herdr plugin link` |

Because the herdr plugin lives inside the Neovim one, it can only be linked
after Neovim has cloned it — so `herdr_nav` skips cleanly until `nvim_sync` (or
`--nvim-sync`, or opening nvim once) has run. The herdr keybindings live in
Omarchy's untracked `~/.config/herdr/config.toml`, so `step_herdr_navigation`
reapplies them, the same way `BAR_SETTINGS` handles `shell.json`.

`HERDR_KEY_APPENDS` puts herdr's Alt+arrow navigation on the home row by
appending to its own binding lists, so the `prefix ?` popup shows both. The
letters keep the arrows' axes: `Alt+H/L` moves tab as `Alt+←/→` does, and
`Alt+J/K` moves workspace as `Alt+↓/↑` does. `HERDR_KEY_SETS` sets options herdr knows but Omarchy leaves
unbound — today agent cycling on `Alt+Shift+J`/`Alt+Shift+K`, deliberately Shift
of the workspace keys. Those are *inserted inside* `[keys]`, before the next
table header: the file ends with `[[keys.command]]` blocks, so a bare key
appended at EOF would belong to that table instead. Resizing deliberately stays on herdr's `Ctrl+Alt+Shift+arrows`,
which is what leaves `Alt+h/j/k/l` free for this.

`HERDR_KEYS_DISABLE` + `HERDR_SHELL_KEYS` halve the resize step. herdr has no
step-size option and its built-in moves the split by `0.05` per press, so the
built-ins are commented out and the same keys rebound to
`herdr pane resize --amount 0.025`. The `0.05` is measured, not assumed:
`herdr pane layout` reports the split ratio, and one default press moved it
`0.50 -> 0.55`. Order matters — herdr resolves a key collision by keeping the
built-in and *disabling* the override, so the keys must be freed first or the
rebinding is silently inert.

**Do not lazy-load `smart-splits.nvim`.** The tmux half depends on
`@pane-is-vim` being set at load; lazy-load it and tmux swallows the keys
instead of forwarding them.

**Things write through our symlinks.** Several stowed files are edited by
tooling that does not know they are symlinks into this repo, so writes land
here rather than only in `~`:

| What | Writes to |
|---|---|
| `omarchy branding screensaver reset` | `omarchy/.config/omarchy/branding/screensaver.txt` |
| `omarchy refresh config hypr/bindings.lua` | `hypr/.config/hypr/bindings.lua` |
| **OmaSettings** (settings GUI) | `hypr/bindings.lua`, `hypr/looknfeel.lua`, `.tmux.conf`, `.bashrc` |

The `omarchy` commands *overwrite* with defaults, which is destructive —
recoverable with git, but do not reach for them casually. OmaSettings makes
targeted edits, which is arguably what you want (they get tracked), but expect
`git status` to be dirty after using it.

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
