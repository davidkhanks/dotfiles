#!/usr/bin/env bash
#
# bootstrap.sh -- bring a fresh Omarchy machine up to this dotfiles setup.
#
# Safe to re-run: every step checks the current state before changing anything,
# and reports what it did. Re-running on a configured machine changes nothing.
#
#   ./bootstrap.sh              run everything
#   ./bootstrap.sh --dry-run    show what would change, touch nothing
#   ./bootstrap.sh --nvim-sync  also install/sync Neovim plugins (slow)
#   ./bootstrap.sh --restore-host  push hosts/<hostname>/ files back to /etc
#   ./bootstrap.sh --reconfigure   re-ask which modules to run on this machine
#
# On first run it asks which modules apply to this machine and remembers the
# answers in bootstrap.conf (git-ignored, so each machine keeps its own).
#   ./bootstrap.sh --help
#
# NOT covered (deliberately -- machine-specific and destructive to get wrong):
#   * Limine boot entries for other OSes. Partition GUIDs differ per machine.
#     Use `limine-scan` interactively, then set `timeout: no` in
#     /boot/limine.conf if you want the menu to wait for input.
#   * Anything needing a PIN (YubiKey PIV/FIDO2). Public keys are read freely;
#     private operations stay interactive by design.

set -euo pipefail

# ── Configuration ───────────────────────────────────────────────────────────
DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/davidkhanks/dotfiles.git}"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"

# Stow packages, in the order they should be applied.
STOW_PACKAGES=(bash bin hypr nvim omarchy slack ssh starship tmux)

# Pacman packages this setup depends on.
#   stow             -- symlink farm manager for the dotfiles
#   libfido2         -- REQUIRED for OpenSSH hardware-key support; without it
#                       ssh-sk-helper fails with "libfido2.so.1 => not found"
#   yubikey-manager  -- ykman, for inspecting/managing the YubiKey
#   yubico-piv-tool  -- provides libykcs11.so, the PKCS#11 module ssh uses
#   pcsclite         -- PC/SC daemon; PIV/CCID access needs it running
#   age              -- decrypts the work-repo manifest (secrets/*.age)
#   age-plugin-yubikey -- lets age use the YubiKey PIV retired-slot identities
PACKAGES_CORE=(stow)
#   lxqt-openssh-askpass -- Wayland-native GUI PIN prompt for the hotplug
#                           reload; gcr-ssh-askpass refuses to run standalone
PACKAGES_YUBIKEY=(libfido2 yubikey-manager yubico-piv-tool pcsclite lxqt-openssh-askpass)
PACKAGES_AGE=(age age-plugin-yubikey)   # decrypting the work-repo manifest

# AUR packages, installed with yay (Omarchy ships it). Left interactive on
# purpose -- yay shows PKGBUILDs for review and needs your sudo password, and
# it must never be run as root.
#   slack-desktop     -- official native Slack client
#   coolercontrol-bin -- prebuilt CoolerControl; the plain `coolercontrol`
#                        package compiles a Tauri app for 10-20 minutes
AUR_SLACK=(slack-desktop)
AUR_COOLERCONTROL=(coolercontrol-bin)

# Third-party Omarchy shell plugin providing an AirPods bar widget. `plugin add`
# only clones files; the plugin's own `setup` script compiles a C++/Qt6 daemon
# and enables a user service, so the build dependencies must exist first.
# Monitor profiles keyed on make/model/serial rather than port, re-applied on
# hotplug, lid events and resume. The plugin is pure QML, but it drives an
# external hyprmoncfg binary, so the AUR package must exist before it is useful.
HYPRMONCFG_PLUGIN_URL="https://github.com/crmne/omarchy-hyprmoncfg.git"
HYPRMONCFG_PLUGIN_ID="crmne.hyprmoncfg"
AUR_HYPRMONCFG=(hyprmoncfg)

AIRPODS_PLUGIN_URL="https://github.com/thisisgm/omarchy-pods"
AIRPODS_PLUGIN_ID="io.github.thisisgm.omapods"
PACKAGES_AIRPODS=(cmake ninja qt6-connectivity qt6-tools qt6-declarative pkgconf libpulse)

# Kernel modules that must be present at every boot.
#   nct6775 -- Nuvoton NCT6791D Super I/O on this ASRock board. Without it
#              there are no fan/PWM hwmon entries at all and CoolerControl has
#              nothing to drive. A one-off `modprobe` does NOT survive reboot.
KERNEL_MODULES=(nct6775)

# System units to enable + start. Skipped silently when the unit is absent, so
# this stays safe before the AUR packages are installed.
#   pcscd.socket          -- PC/SC daemon; YubiKey PIV/CCID access needs it
#   coolercontrold.service -- CoolerControl daemon that owns the fan headers
SERVICES=(pcscd.socket coolercontrold.service)

# Machine-specific root-owned files, tracked under hosts/<hostname>/ because
# stow only targets $HOME. Paths are relative to /. These are NOT portable:
# CoolerControl's config embeds hardware-derived device UIDs and fan curves
# tuned to this box's specific fans, so another machine must never get them.
HOST_FILES=(
  "etc/coolercontrol/config.toml"
)

# Work repositories are described by a manifest kept OUTSIDE this repo, because
# this repo is public and internal project names are not for publishing. The
# mechanism lives here; the list does not. Absent manifest => step is skipped.
# Encrypted in the repo (age, YubiKey PIV + a backup recipient) so the list can
# live alongside everything else without publishing it. Decrypting needs the
# YubiKey and a touch. A plaintext file at WORK_REPOS_MANIFEST, if present,
# takes precedence -- handy for editing without a touch per run.
# Per-machine module selection. Git-ignored: this desktop and a laptop want
# different things (no fan control on a laptop, for instance), and neither
# should have to re-answer the prompts on every run.
BOOTSTRAP_CONF="${BOOTSTRAP_CONF:-$DOTFILES_DIR/bootstrap.conf}"
MODULE_KEYS=(yubikey coolercontrol slack airpods hyprmoncfg work_repos work_setup nvim_default nvim_sync)
declare -A MODULE_ENABLED=()

module_desc() {
  case "$1" in
    yubikey)       echo "YubiKey PIV SSH (libfido2, pcscd, ssh config, key export)" ;;
    coolercontrol) echo "CoolerControl fan curves (nct6775 module, daemon, host config)" ;;
    slack)         echo "Slack desktop app with Wayland flags" ;;
    airpods)       echo "AirPods bar widget (third-party shell plugin + compiled daemon)" ;;
    hyprmoncfg)    echo "Monitor profiles that auto-switch on hotplug (third-party plugin)" ;;
    work_repos)    echo "Clone work repositories (age-encrypted manifest)" ;;
    work_setup)    echo "Prepare the work dev environment (tools, worktrees, containers)" ;;
    nvim_default)  echo "Make this Neovim config the default (~/.config/nvim)" ;;
    nvim_sync)     echo "Restore Neovim plugins from lazy-lock.json (slow)" ;;
    *)             echo "$1" ;;
  esac
}
# Anything hardware- or host-specific defaults to asking; nvim_sync is slow so
# it defaults off.
module_default() { case "$1" in nvim_sync) echo no ;; *) echo yes ;; esac; }

enabled() { [[ "${MODULE_ENABLED[$1]:-no}" == yes ]]; }

load_modules() {
  local line k v
  [[ -r "$BOOTSTRAP_CONF" ]] || return 0
  while IFS= read -r line; do
    line="${line%%#*}"
    [[ $line == *=* ]] || continue
    k="${line%%=*}"; v="${line#*=}"
    k="${k//[[:space:]]/}"; v="${v//[[:space:]]/}"
    [[ -n $k ]] && MODULE_ENABLED[$k]="$v"
  done < "$BOOTSTRAP_CONF"
}

save_modules() {
  { printf '# Per-machine module selection for bootstrap.sh -- git-ignored.\n'
    printf '# Regenerate the prompts with: ./bootstrap.sh --reconfigure\n'
    printf '# Host: %s   Written: %s\n\n' "$HOSTNAME_SHORT" "$(date -Is)"
    for k in "${MODULE_KEYS[@]}"; do
      printf '# %s\n%s=%s\n\n' "$(module_desc "$k")" "$k" "${MODULE_ENABLED[$k]}"
    done
  } > "$BOOTSTRAP_CONF"
  chmod 600 "$BOOTSTRAP_CONF"
}

# Ask about any module not already answered. Only prompts on a real terminal;
# non-interactive runs fall back to defaults rather than hanging.
configure_modules() {
  local k ans missing=() default
  (( RECONFIGURE )) && MODULE_ENABLED=()
  for k in "${MODULE_KEYS[@]}"; do
    [[ -n "${MODULE_ENABLED[$k]:-}" ]] || missing+=("$k")
  done
  (( ${#missing[@]} )) || return 0

  if [[ ! -t 0 ]]; then
    for k in "${missing[@]}"; do MODULE_ENABLED[$k]="$(module_default "$k")"; done
    note "not a terminal, so module prompts were skipped; used defaults. Run ./bootstrap.sh --reconfigure from a terminal to choose."
    return 0
  fi

  printf '\n%sWhich modules should run on this machine (%s)?%s\n' "$C_BOLD" "$HOSTNAME_SHORT" "$C_OFF"
  printf '%sSaved to %s -- you will not be asked again.%s\n\n' \
    "$C_DIM" "${BOOTSTRAP_CONF/#$HOME/~}" "$C_OFF"
  for k in "${missing[@]}"; do
    default="$(module_default "$k")"
    while true; do
      printf '  %-14s %s\n' "$k" "$(module_desc "$k")"
      read -r -p "    enable? [$( [[ $default == yes ]] && echo 'Y/n' || echo 'y/N' )] " ans || ans=""
      ans="${ans,,}"
      case "${ans:-$default}" in
        y|yes) MODULE_ENABLED[$k]=yes; break ;;
        n|no)  MODULE_ENABLED[$k]=no;  break ;;
        *)     printf '    please answer y or n\n' ;;
      esac
    done
  done
  printf '\n'
  (( DRY_RUN )) || save_modules
}

WORK_REPOS_AGE="${WORK_REPOS_AGE:-$DOTFILES_DIR/secrets/work-repos.age}"
# age-plugin-yubikey cannot discover the token on its own; it needs an identity
# file. This one is a hardware stub (serial + slot, no key material), so it is
# safe to commit. Override to decrypt with a backup key instead.
# Where the work repos live and which projects need a dev environment. Read
# from the manifest's "root" line at runtime; this is only the fallback.
# Clone root comes from the manifest; no default is hardcoded here.
WORK_REPOS_AGE_IDENTITY="${WORK_REPOS_AGE_IDENTITY:-$DOTFILES_DIR/secrets/yubikey-identity.txt}"
WORK_REPOS_MANIFEST="${WORK_REPOS_MANIFEST:-$HOME/.config/dotfiles/work-repos}"

# Neovim: the repo ships the config as `davidkhanks-nvim` so it can live
# alongside another config; this symlink makes it the default for plain `nvim`.
NVIM_APPDIR="davidkhanks-nvim"

# YubiKey PIV SSH
PIV_SLOT="9a"
PKCS11_MODULE="/usr/lib/libykcs11.so"
SSH_DIR="$HOME/.ssh"
SSH_PUBKEY="$SSH_DIR/id_yubikey_piv.pub"
SSH_CONFIG="$SSH_DIR/config"

# ── Output helpers ──────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  C_OK=$'\033[32m'; C_CHANGE=$'\033[33m'; C_ERR=$'\033[31m'
  C_DIM=$'\033[90m'; C_BOLD=$'\033[1m'; C_OFF=$'\033[0m'
else
  C_OK=""; C_CHANGE=""; C_ERR=""; C_DIM=""; C_BOLD=""; C_OFF=""
fi

DRY_RUN=0
NVIM_SYNC=0
RESTORE_HOST=0
RECONFIGURE=0
HOSTNAME_SHORT="$(hostnamectl hostname 2>/dev/null || hostname)"
CHANGES=0
declare -a NOTES=()

section() { printf '\n%s== %s ==%s\n' "$C_BOLD" "$1" "$C_OFF"; }
ok()      { printf '  %s✓%s %s\n' "$C_OK" "$C_OFF" "$1"; }
changed() { printf '  %s→%s %s\n' "$C_CHANGE" "$C_OFF" "$1"; CHANGES=$((CHANGES + 1)); }
skip()    { printf '  %s·%s %s\n' "$C_DIM" "$C_OFF" "$1"; }
fail()    { printf '  %s✗%s %s\n' "$C_ERR" "$C_OFF" "$1" >&2; }
note()    { NOTES+=("$1"); }
die()     { fail "$1"; exit 1; }

# Would-change guard. Returns 0 when the caller should actually act.
acting() {
  if (( DRY_RUN )); then
    printf '  %s→%s [dry-run] %s\n' "$C_CHANGE" "$C_OFF" "$1"
    CHANGES=$((CHANGES + 1))
    return 1
  fi
  return 0
}

have() { command -v "$1" >/dev/null 2>&1; }

# Back up a path that exists and is not already the symlink we want.
backup_path() {
  local path="$1" stamp
  stamp="$(date +%s)"
  mv "$path" "$path.bak.$stamp"
  printf '%s' "$path.bak.$stamp"
}

# Idempotent symlink: ensure $link points at $target.
ensure_link() {
  local target="$1" link="$2" label="${3:-$2}" resolved
  # A relative target is relative to the link's own directory, not $PWD.
  if [[ "$target" == /* ]]; then
    resolved="$target"
  else
    resolved="$(dirname "$link")/$target"
  fi
  if [[ -L "$link" ]]; then
    if [[ "$(readlink -f "$link")" == "$(readlink -f "$resolved")" ]]; then
      ok "$label already linked"
      return 0
    fi
    acting "relink $label" || return 0
    ln -sfn "$target" "$link"
    changed "$label relinked -> $target"
    return 0
  fi
  if [[ -e "$link" ]]; then
    acting "back up existing $label and link it" || return 0
    local backup; backup="$(backup_path "$link")"
    ln -sfn "$target" "$link"
    changed "$label linked (previous saved to ${backup##*/})"
    return 0
  fi
  acting "link $label" || return 0
  mkdir -p "$(dirname "$link")"
  ln -sfn "$target" "$link"
  changed "$label linked -> $target"
}

# ── Steps ───────────────────────────────────────────────────────────────────

step_preflight() {
  section "Preflight"
  [[ -f /etc/arch-release ]] || die "This script targets Arch/Omarchy."
  (( EUID != 0 )) || die "Run as your normal user, not root (it calls sudo where needed)."
  have sudo || die "sudo not found."
  ok "Arch system, running as $USER"
}

step_packages() {
  section "Packages"
  local -a want=("${PACKAGES_CORE[@]}")
  enabled yubikey    && want+=("${PACKAGES_YUBIKEY[@]}")
  enabled airpods    && want+=("${PACKAGES_AIRPODS[@]}")
  enabled work_repos && want+=("${PACKAGES_AGE[@]}")
  local missing=()
  for p in "${want[@]}"; do
    pacman -Qq "$p" >/dev/null 2>&1 || missing+=("$p")
  done

  if (( ${#missing[@]} == 0 )); then
    ok "all ${#want[@]} packages present"
    return 0
  fi

  acting "install: ${missing[*]}" || return 0
  # Sync databases first: a fresh Omarchy install ships only an offline repo,
  # so `pacman -S` fails with "target not found" until the real dbs exist.
  if [[ ! -f /var/lib/pacman/sync/core.db ]]; then
    note "pacman databases were missing; ran a full sync. Consider 'omarchy update'."
    sudo pacman -Syu --noconfirm
  fi
  # Prefer Omarchy's wrapper: same --needed semantics, but it re-checks with
  # `pacman -Q` afterwards and fails loudly if a package silently did not land.
  # Fall back to pacman so this still works on a plain Arch box.
  if have omarchy-pkg-add; then
    omarchy-pkg-add "${missing[@]}"
  else
    sudo pacman -S --needed --noconfirm "${missing[@]}"
  fi
  changed "installed: ${missing[*]}"
}

step_aur_packages() {
  section "AUR packages"
  if ! have yay; then
    note "yay not found; skipped AUR packages: ${AUR_PACKAGES[*]}"
    skip "yay not installed"
    return 0
  fi
  local -a want=()
  enabled slack         && want+=("${AUR_SLACK[@]}")
  enabled coolercontrol && want+=("${AUR_COOLERCONTROL[@]}")
  enabled hyprmoncfg    && want+=("${AUR_HYPRMONCFG[@]}")
  if (( ${#want[@]} == 0 )); then
    skip "no AUR packages selected"
    return 0
  fi
  local missing=()
  for p in "${want[@]}"; do
    pacman -Qq "$p" >/dev/null 2>&1 || missing+=("$p")
  done
  if (( ${#missing[@]} == 0 )); then
    ok "all ${#want[@]} AUR packages present"
    return 0
  fi
  acting "install from AUR: ${missing[*]}" || return 0
  # Omarchy's wrapper adds a post-install `pacman -Q` verification pass, which
  # catches the case where yay exits 0 but the package is not actually there.
  # Note it hardcodes --noconfirm, so PKGBUILDs are NOT shown. To review one
  # first, run `yay -S <pkg>` by hand before running this script; the step then
  # sees it as present and skips it.
  if have omarchy-pkg-aur-add; then
    omarchy-pkg-aur-add "${missing[@]}"
  else
    yay -S --needed --noconfirm "${missing[@]}"
  fi
  changed "installed from AUR: ${missing[*]}"
}

step_dotfiles() {
  section "Dotfiles repo"
  if [[ -d "$DOTFILES_DIR/.git" ]]; then
    ok "repo present at $DOTFILES_DIR"
    # Deliberately not pulling: a surprise fast-forward mid-bootstrap can
    # change what gets stowed underneath you. Update it yourself.
    return 0
  fi
  if [[ -e "$DOTFILES_DIR" ]]; then
    die "$DOTFILES_DIR exists but is not a git repo; move it aside first."
  fi
  acting "clone $DOTFILES_REPO -> $DOTFILES_DIR" || return 0
  git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
  changed "cloned $DOTFILES_DIR"
}

step_ssh_dir() {
  section "SSH directory"
  # Must run before stow: if ~/.ssh does not exist, stow creates it with the
  # umask default (typically 755) and ssh refuses a loose ~/.ssh.
  if [[ -d "$SSH_DIR" ]]; then
    ok "~/.ssh exists"
  elif acting "create ~/.ssh (700)"; then
    mkdir -p "$SSH_DIR"
    changed "created ~/.ssh"
  fi
  if [[ -d "$SSH_DIR" && "$(stat -Lc '%a' "$SSH_DIR")" != "700" ]]; then
    if acting "chmod 700 ~/.ssh"; then
      chmod 700 "$SSH_DIR"
      changed "tightened ~/.ssh to 700"
    fi
  fi
}

step_stow() {
  section "Stow packages"
  have stow || { skip "stow not installed yet (dry-run?)"; return 0; }
  [[ -d "$DOTFILES_DIR" ]] || { skip "no dotfiles dir yet (dry-run?)"; return 0; }

  for pkg in "${STOW_PACKAGES[@]}"; do
    # A couple of packages only make sense when their module is enabled.
    case "$pkg" in
      slack) enabled slack || { skip "$pkg (module off)"; continue; } ;;
    esac
    if [[ ! -d "$DOTFILES_DIR/$pkg" ]]; then
      fail "package '$pkg' missing from repo"
      continue
    fi

    # --no-folding keeps stow from replacing a whole directory with one link.
    # That matters under ~/.config/omarchy and ~/.config/hypr, which also hold
    # Omarchy-managed files we must not swallow.
    local sim
    if ! sim="$(cd "$DOTFILES_DIR" && stow --no-folding --target="$HOME" --simulate --verbose "$pkg" 2>&1)"; then
      fail "$pkg: stow conflict"
      printf '%s\n' "$sim" | sed 's/^/      /'
      continue
    fi

    if ! grep -q '^LINK:' <<<"$sim"; then
      ok "$pkg already stowed"
      continue
    fi

    acting "stow $pkg" || continue
    (cd "$DOTFILES_DIR" && stow --no-folding --restow --target="$HOME" "$pkg")
    changed "stowed $pkg"
  done
}

step_desktop_db() {
  enabled slack || return 0
  section "Desktop entries"
  local dir="$HOME/.local/share/applications"
  # The stowed slack.desktop registers the x-scheme-handler/slack MIME type;
  # that only takes effect once the cache is rebuilt.
  if [[ ! -e "$dir/slack.desktop" ]]; then
    skip "no slack.desktop (stow the slack package first)"
    return 0
  fi
  if grep -q 'slack.desktop' "$dir/mimeinfo.cache" 2>/dev/null; then
    ok "desktop database up to date"
    return 0
  fi
  acting "update desktop database" || return 0
  update-desktop-database "$dir" 2>/dev/null || true
  changed "rebuilt desktop database"
}

step_nvim_default() {
  enabled nvim_default || return 0
  section "Neovim as default config"
  local target="$HOME/.config/$NVIM_APPDIR"
  if [[ ! -e "$target" ]]; then
    skip "$NVIM_APPDIR not present yet (stow the nvim package first)"
    return 0
  fi
  # Relative link: ~/.config/nvim -> davidkhanks-nvim, which stow owns.
  ensure_link "$NVIM_APPDIR" "$HOME/.config/nvim" "~/.config/nvim"
}

step_kernel_modules() {
  # nct6775 exists only for CoolerControl here.
  enabled coolercontrol || return 0
  section "Kernel modules"
  for m in "${KERNEL_MODULES[@]}"; do
    local conf="/etc/modules-load.d/$m.conf"
    if [[ -f "$conf" ]]; then
      ok "$m persisted ($conf)"
    else
      if acting "persist $m via $conf"; then
        printf '%s\n' "$m" | sudo tee "$conf" >/dev/null
        changed "$m will now load at boot"
      fi
    fi
    # `lsmod | grep -q` is unreliable under `set -o pipefail`: grep -q exits
    # early, lsmod takes SIGPIPE, and the pipeline reports failure.
    if [[ -d "/sys/module/$m" ]]; then
      ok "$m loaded"
    else
      if acting "modprobe $m"; then
        sudo modprobe "$m"
        changed "$m loaded"
      fi
    fi
  done
}

step_host_files() {
  enabled coolercontrol || return 0
  section "Host-specific files ($HOSTNAME_SHORT)"
  local root="$DOTFILES_DIR/hosts/$HOSTNAME_SHORT"
  if [[ ! -d "$root" ]]; then
    skip "no hosts/$HOSTNAME_SHORT in the repo"
    return 0
  fi
  for f in "${HOST_FILES[@]}"; do
    if [[ ! -e "$root/$f" ]]; then
      skip "$f not captured for this host"
      continue
    fi
    if [[ ! -e "/$f" ]]; then
      if acting "install /$f from repo"; then
        sudo install -D -m 644 -o root -g root "$root/$f" "/$f"
        changed "installed /$f"
      fi
      continue
    fi
    if cmp -s "$root/$f" "/$f"; then
      ok "$f matches repo"
    elif (( RESTORE_HOST )); then
      if acting "restore /$f from repo (overwrites live)"; then
        # CoolerControl rewrites its config while running.
        [[ $f == etc/coolercontrol/* ]] && sudo systemctl stop coolercontrold.service || true
        sudo install -m 644 -o root -g root "$root/$f" "/$f"
        [[ $f == etc/coolercontrol/* ]] && sudo systemctl start coolercontrold.service || true
        changed "restored /$f"
      fi
    else
      # Deliberately NOT overwriting: the live file may hold tuning done in a
      # GUI since the last capture. `host-config capture` pulls it into the
      # repo; `--restore-host` pushes the repo copy out.
      note "/$f differs from the repo copy. Run 'host-config diff' to see it, then either 'host-config capture' (keep the live version) or bootstrap --restore-host (keep the repo version)."
      skip "$f drifted -- left untouched"
    fi
  done
}

step_services() {
  section "Services"
  local -a units=()
  enabled yubikey       && units+=(pcscd.socket)
  enabled coolercontrol && units+=(coolercontrold.service)
  if (( ${#units[@]} == 0 )); then
    skip "no services selected"
    return 0
  fi
  for unit in "${units[@]}"; do
    # `systemctl cat` fails cleanly for a unit that does not exist.
    if ! systemctl cat "$unit" >/dev/null 2>&1; then
      skip "$unit not installed"
      continue
    fi
    # enabled and active are separate questions: a unit can be running now and
    # still be absent at the next boot. pcscd was exactly that.
    if [[ "$(systemctl is-enabled "$unit" 2>/dev/null)" == "enabled" ]]; then
      ok "$unit enabled"
    else
      if acting "enable $unit"; then
        sudo systemctl enable "$unit"
        changed "$unit enabled at boot"
      fi
    fi
    if [[ "$(systemctl is-active "$unit" 2>/dev/null)" == "active" ]]; then
      ok "$unit active"
    else
      if acting "start $unit"; then
        sudo systemctl start "$unit"
        changed "$unit started"
      fi
    fi
  done
}

step_yubikey_ssh() {
  enabled yubikey || return 0
  section "YubiKey PIV SSH"
  mkdir -p "$SSH_DIR"; chmod 700 "$SSH_DIR"

  if ! have ykman; then
    skip "ykman not installed yet"
    return 0
  fi
  # Capture first: piping into `grep -q` under pipefail is a SIGPIPE race.
  local yk_list; yk_list="$(ykman list 2>/dev/null || true)"
  if [[ -z "$yk_list" ]]; then
    skip "no YubiKey detected -- plug it in and re-run to finish SSH setup"
    return 0
  fi

  # Public keys are readable without any PIN.
  local tmp exported
  tmp="$(mktemp)"
  if ! ykman piv keys export "$PIV_SLOT" "$tmp" >/dev/null 2>&1; then
    rm -f "$tmp"
    fail "no key in PIV slot ${PIV_SLOT^^}"
    return 0
  fi
  exported="$(ssh-keygen -i -m PKCS8 -f "$tmp" 2>/dev/null) ${USER}-yubikey-piv-${PIV_SLOT}"
  rm -f "$tmp"

  if [[ -f "$SSH_PUBKEY" ]] && [[ "$(cat "$SSH_PUBKEY")" == "$exported" ]]; then
    ok "public key matches slot ${PIV_SLOT^^}"
  else
    if acting "write $SSH_PUBKEY"; then
      printf '%s\n' "$exported" > "$SSH_PUBKEY"
      # ssh treats an IdentityFile as a private key and refuses 0644 with
      # "UNPROTECTED PRIVATE KEY FILE", even though this is only a public key.
      chmod 600 "$SSH_PUBKEY"
      changed "exported slot ${PIV_SLOT^^} public key"
    fi
  fi

  # ~/.ssh/config comes from the `ssh` stow package, not from this script, so
  # edits stay version-controlled. We only verify and tighten permissions.
  if [[ ! -e "$SSH_CONFIG" ]]; then
    fail "$SSH_CONFIG missing -- the 'ssh' stow package should provide it"
  elif grep -q 'IdentitiesOnly' "$SSH_CONFIG"; then
    # Deliberately NOT looking for PKCS11Provider: the module is loaded into
    # ssh-agent instead, and having both open competing PIV sessions on the
    # token ("agent refused operation"). What we do want is IdentitiesOnly,
    # which keeps the agent's six identities from tripping MaxAuthTries.
    ok "ssh config pins identities to the YubiKey key"
    # stat -L / chmod follow the symlink, so this acts on the file in the repo.
    if [[ "$(stat -Lc '%a' "$SSH_CONFIG")" != "600" ]]; then
      if acting "chmod 600 $SSH_CONFIG"; then
        chmod 600 "$SSH_CONFIG"
        changed "tightened ssh config to 600"
      fi
    fi
  else
    note "$SSH_CONFIG has no IdentitiesOnly line. Add to the ssh stow package:
        IdentityFile   $SSH_PUBKEY
        IdentitiesOnly yes
     (do NOT add PKCS11Provider -- the module belongs in ssh-agent only)"
    skip "ssh config present but not YubiKey-aware"
  fi

  # Sanity check: can OpenSSH actually see the key? Needs no PIN.
  local pkcs11_keys; pkcs11_keys="$(ssh-keygen -D "$PKCS11_MODULE" 2>/dev/null || true)"
  if [[ "$pkcs11_keys" == *"PIV Authentication"* ]]; then
    ok "OpenSSH can read the key via PKCS#11"
  else
    fail "PKCS#11 module did not return the PIV key (is pcscd running?)"
  fi
}

step_hyprmoncfg() {
  enabled hyprmoncfg || return 0
  section "Monitor profile manager"

  # The AUR package is installed by step_aur_packages, which runs earlier, so
  # the binary the plugin drives is already present by the time we get here.
  if have hyprmoncfg; then
    ok "hyprmoncfg binary present"
  else
    fail "hyprmoncfg binary missing (AUR install did not run or failed)"
  fi

  local dir="$HOME/.config/omarchy/plugins/$HYPRMONCFG_PLUGIN_ID"
  if [[ -d "$dir" ]]; then
    ok "plugin present"
  elif ! have omarchy; then
    skip "omarchy not available"
  elif acting "add plugin from $HYPRMONCFG_PLUGIN_URL"; then
    # Third-party QML, and it declares a service kind, so it runs continuously
    # inside the shell process rather than only when opened. Opt-in on purpose.
    omarchy plugin add "$HYPRMONCFG_PLUGIN_URL" --enable --yes && changed "plugin added" \
      || fail "plugin add failed"
  fi

  note "A newly added plugin needs 'omarchy restart shell' before it renders.
     Monitor profiles are stored by the hyprmoncfg binary, not in this repo."
}

step_airpods() {
  enabled airpods || return 0
  section "AirPods bar widget"

  local dir="$HOME/.config/omarchy/plugins/$AIRPODS_PLUGIN_ID"
  if [[ -d "$dir" ]]; then
    ok "plugin present"
  elif ! have omarchy; then
    skip "omarchy not available"
    return 0
  elif acting "add plugin from $AIRPODS_PLUGIN_URL"; then
    # Third-party QML runs inside the shell process; this is a deliberate
    # opt-in, which is why it is its own module.
    omarchy plugin add "$AIRPODS_PLUGIN_URL" --enable --yes && changed "plugin added" \
      || { fail "plugin add failed"; return 0; }
  fi

  # The daemon is compiled, so a fresh clone has no binary until setup runs.
  if [[ -x "$HOME/.local/bin/librepods" ]]; then
    ok "daemon built"
  elif [[ ! -x "$dir/setup" ]]; then
    skip "plugin has no setup script"
  elif acting "run the plugin setup (compiles the daemon, several minutes)"; then
    # setup's first line installs build deps with sudo; they are already in
    # PACKAGES_AIRPODS so that step is a no-op by the time we get here.
    ("$dir/setup") && changed "daemon built and service enabled" || fail "plugin setup failed"
  fi

  if systemctl --user list-unit-files librepods.service >/dev/null 2>&1; then
    if [[ "$(systemctl --user is-enabled librepods.service 2>/dev/null)" == "enabled" ]]; then
      ok "librepods.service enabled"
    elif acting "enable librepods.service"; then
      systemctl --user enable --now librepods.service; changed "librepods.service enabled"
    fi
    if [[ "$(systemctl --user is-active librepods.service 2>/dev/null)" == "active" ]]; then
      ok "librepods.service active"
    elif acting "start librepods.service"; then
      systemctl --user start librepods.service; changed "librepods.service started"
    fi
  else
    skip "librepods.service not installed yet"
  fi

  # The widget hides itself when nothing is connected, which reads as a broken
  # install. Worth saying once rather than rediscovering it.
  note "The AirPods icon stays hidden unless AirPods are connected. To pin it:
       omarchy bar set $AIRPODS_PLUGIN_ID hideWhenDisconnected false --json
     A newly added plugin needs 'omarchy restart shell' before it renders."
}

step_ssh_agent() {
  enabled yubikey || return 0
  section "SSH agent (YubiKey)"

  # Arch's stock ssh-agent.socket starts the agent with no -P whitelist, so
  # `ssh-add -s` is refused outright. Our unit (ssh stow package) adds it.
  if [[ "$(systemctl --user is-enabled ssh-agent.socket 2>/dev/null)" == "enabled" ]]; then
    if acting "disable stock ssh-agent.socket (no PKCS#11 whitelist)"; then
      systemctl --user disable --now ssh-agent.socket >/dev/null 2>&1 || true
      changed "disabled stock ssh-agent.socket"
    fi
  else
    ok "stock ssh-agent.socket not in use"
  fi

  if [[ ! -e "$HOME/.config/systemd/user/ssh-agent.service" ]]; then
    skip "ssh-agent.service missing (stow the ssh package first)"
    return 0
  fi
  if [[ "$(systemctl --user is-enabled ssh-agent.service 2>/dev/null)" == "enabled" ]]; then
    ok "ssh-agent.service enabled"
  elif acting "enable ssh-agent.service"; then
    systemctl --user daemon-reload
    systemctl --user enable --now ssh-agent.service
    changed "ssh-agent.service enabled"
  fi
  if [[ "$(systemctl --user is-active ssh-agent.service 2>/dev/null)" == "active" ]]; then
    ok "ssh-agent.service active"
  elif acting "start ssh-agent.service"; then
    systemctl --user start ssh-agent.service
    changed "ssh-agent.service started"
  fi

  # udev -> systemd bridge: replugging the key reloads the PKCS#11 module.
  local rule=/etc/udev/rules.d/85-yubikey-ssh-reload.rules
  if [[ -f "$rule" ]]; then
    ok "hotplug udev rule installed"
  elif acting "install $rule"; then
    sudo tee "$rule" >/dev/null <<'RULE'
# Reload the YubiKey PKCS#11 module into the user's ssh-agent on insert.
# 1050 is Yubico's USB vendor id (all models). SYSTEMD_USER_WANTS is the
# udev -> systemd user-session bridge, so no sudo is needed at event time.
ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="1050", TAG+="systemd", ENV{SYSTEMD_USER_WANTS}+="yubikey-ssh-reload.service"
RULE
    sudo udevadm control --reload-rules
    changed "installed hotplug udev rule"
  fi

  # Informational: the PIN is needed once per agent lifetime, so an empty
  # agent right after boot is normal, not an error.
  local ids
  ids="$(SSH_AUTH_SOCK="${XDG_RUNTIME_DIR}/ssh-agent.sock" ssh-add -l 2>&1 || true)"
  if [[ "$ids" == *"no identities"* ]]; then
    note "ssh-agent holds no identities. Replug the YubiKey, or run 'yk-reload' (one PIN, then a touch per signature)."
    skip "agent empty -- load it before any git-over-SSH step"
  elif [[ "$ids" == *"PIV"* ]]; then
    ok "agent holds the YubiKey identities"
  else
    skip "agent not reachable yet"
  fi
}

step_work_repos() {
  enabled work_repos || return 0
  section "Work repositories"

  local manifest="" tmp_manifest=""
  if [[ -r "$WORK_REPOS_MANIFEST" ]]; then
    manifest="$WORK_REPOS_MANIFEST"
    ok "using plaintext manifest ${WORK_REPOS_MANIFEST/#$HOME/\~}"
  elif [[ -r "$WORK_REPOS_AGE" ]]; then
    if ! have age; then
      fail "age not installed; cannot read ${WORK_REPOS_AGE##*/}"
      return 0
    fi
    if [[ ! -r "$WORK_REPOS_AGE_IDENTITY" ]]; then
      fail "no age identity at ${WORK_REPOS_AGE_IDENTITY##*/}"
      return 0
    fi
    # Slot 1's touch policy is "always", so this blocks until you touch the key.
    printf '  %s·%s decrypting %s -- TOUCH YOUR YUBIKEY\n' "$C_DIM" "$C_OFF" "${WORK_REPOS_AGE##*/}"
    tmp_manifest="$(mktemp)"; chmod 600 "$tmp_manifest"
    if age -d -i "$WORK_REPOS_AGE_IDENTITY" -o "$tmp_manifest" "$WORK_REPOS_AGE" 2>/dev/null; then
      manifest="$tmp_manifest"
      ok "decrypted ${WORK_REPOS_AGE##*/}"
    else
      rm -f "$tmp_manifest"
      fail "could not decrypt ${WORK_REPOS_AGE##*/} (YubiKey plugged in? touched in time?)"
      return 0
    fi
  else
    skip "no work-repo manifest (plaintext or .age)"
    return 0
  fi
  # Shred the decrypted copy however this function exits.
  [[ -n $tmp_manifest ]] && trap 'rm -f "$tmp_manifest"' RETURN

  local root="" url dir line
  local -a pending=()
  while read -r line; do
    line="${line%%#*}"; line="${line#"${line%%[![:space:]]*}"}"
    [[ -z $line ]] && continue
    read -r a b <<<"$line"
    if [[ $a == root ]]; then
      root="${b/#\~/$HOME}"
      continue
    fi
    [[ -n $root ]] || { fail "manifest sets a repo before 'root'"; return 0; }
    url="$a"
    dir="${b:-$(basename "${url%.git}")}"
    if [[ -d "$root/$dir/.git" ]]; then
      ok "$dir present"
    elif [[ -e "$root/$dir" ]]; then
      fail "$root/$dir exists but is not a git repo"
    else
      pending+=("$url|$dir")
    fi
  done < "$manifest"

  (( ${#pending[@]} )) || return 0

  # Cloning over SSH needs the YubiKey. With the provider loaded into the agent
  # that is one touch per repo; without it, a PIN prompt per repo.
  if ! ssh-add -l >/dev/null 2>&1; then
    note "ssh-agent holds no identities. Run 'ssh-add -s /usr/lib/libykcs11.so' first (one PIN), then each clone needs only a touch."
  fi

  for line in "${pending[@]}"; do
    url="${line%%|*}"; dir="${line##*|}"
    if acting "clone $dir"; then
      mkdir -p "$root"
      if git clone --quiet "$url" "$root/$dir"; then
        changed "cloned $dir"
      else
        fail "clone failed: $dir (YubiKey plugged in and agent loaded?)"
      fi
    fi
  done
}

# Parse the work manifest once into globals. Every work-specific name lives in
# that file (encrypted in secrets/, plaintext outside this repo), so nothing in
# this script names an employer, a project or a host.
WORK_ROOT=""
declare -a WORK_REPOS=() WORK_TOOLS=() WORK_WORKTREES=() WORK_DEVHOMES=()
declare -a WORK_SETTINGS=() WORK_IMAGES=() WORK_SERVICES=()
WORK_VLIB=""
WORK_PINFILE="version"   # file in each project naming the shared-lib ref
WORK_CREDTOOL="the credential manager"
WORK_PARSED=0

parse_work_manifest() {
  (( WORK_PARSED )) && return 0
  local file="$1" line a b c d
  [[ -r "$file" ]] || return 1
  while IFS= read -r line; do
    line="${line%%#*}"
    [[ -z "${line//[[:space:]]/}" ]] && continue
    read -r a b c d <<<"$line"
    case "$a" in
      root)      WORK_ROOT="${b/#\~/$HOME}" ;;
      shared)    WORK_VLIB="$b" ;;                    # repo whose ./dev makes worktrees
      pinfile)   WORK_PINFILE="$b" ;;                 # per-project file naming the pinned ref
      credtool)  WORK_CREDTOOL="$b" ;;                # command that loads credential profiles
      tool)      WORK_TOOLS+=("$b") ;;                # repo to build+install via make
      worktree)  WORK_WORKTREES+=("$b|$c") ;;         # <worktree-dir>|<project pinning it>
      devhome)   WORK_DEVHOMES+=("$b") ;;
      settings)  WORK_SETTINGS+=("$b|$c|$d") ;;       # <project>|<template>|<target>
      image)     WORK_IMAGES+=("$b|$c") ;;            # <project>|<dev subcommand>
      services)  WORK_SERVICES+=("$b") ;;             # project providing shared services
      *)         [[ "$a" == *:* || "$a" == git@* || "$a" == http* ]] && WORK_REPOS+=("$a|${b:-}") ;;
    esac
  done < "$file"
  WORK_PARSED=1
}

step_work_setup() {
  enabled work_setup || return 0
  section "Work dev environment"

  local manifest="" tmp=""
  if [[ -r "$WORK_REPOS_MANIFEST" ]]; then
    manifest="$WORK_REPOS_MANIFEST"
  elif [[ -r "$WORK_REPOS_AGE" ]] && have age && [[ -r "$WORK_REPOS_AGE_IDENTITY" ]]; then
    tmp="$(mktemp)"; chmod 600 "$tmp"
    printf '  %s·%s decrypting manifest -- TOUCH YOUR YUBIKEY\n' "$C_DIM" "$C_OFF"
    age -d -i "$WORK_REPOS_AGE_IDENTITY" -o "$tmp" "$WORK_REPOS_AGE" 2>/dev/null \
      && manifest="$tmp" || { rm -f "$tmp"; fail "could not decrypt manifest"; return 0; }
  fi
  [[ -n $manifest ]] || { skip "no work manifest"; return 0; }
  parse_work_manifest "$manifest"
  [[ -n $tmp ]] && rm -f "$tmp"

  local root="$WORK_ROOT"
  [[ -d "$root" ]] || { skip "clone root not present yet"; return 0; }

  # --- docker -------------------------------------------------------------
  if have docker; then
    if [[ "$(systemctl is-enabled docker.service 2>/dev/null)" == "enabled" ]]; then
      ok "docker enabled"
    elif acting "enable docker.service"; then
      sudo systemctl enable --now docker.service; changed "docker enabled"
    fi
    if id -nG "$USER" | grep -qw docker; then
      ok "in the docker group"
    elif acting "add $USER to the docker group"; then
      sudo usermod -aG docker "$USER"
      note "Added to the docker group; log out and back in for it to take effect."
      changed "added to docker group"
    fi
  else
    fail "docker not installed"
  fi

  # --- locally built tools (e.g. the credential manager) ------------------
  # Built from a cloned repo so no pre-existing API token is needed -- the
  # chicken-and-egg of needing credentials to fetch the credential tool.
  local t
  for t in "${WORK_TOOLS[@]}"; do
    if have "$t"; then
      ok "$t installed"
    elif [[ ! -d "$root/$t" ]]; then
      skip "$t repo not cloned"
    elif ! have go; then
      fail "go not installed; cannot build $t"
    elif acting "build + install $t from source"; then
      (cd "$root/$t" && make install >/dev/null) && changed "$t installed" || fail "$t build failed"
    fi
  done

  # --- shared-library worktrees -------------------------------------------
  # Each consuming project pins its own version, so one checkout cannot serve
  # them all. The shared repo's own ./dev owns this; fall back to git worktree
  # directly when that script is absent.
  if [[ -n "$WORK_VLIB" && -d "$root/$WORK_VLIB" ]]; then
    local pair wt proj ref missing=()
    for pair in "${WORK_WORKTREES[@]}"; do
      wt="${pair%%|*}"; proj="${pair##*|}"
      [[ -f "$root/$proj/$WORK_PINFILE" ]] || continue
      [[ -d "$root/$wt" ]] || missing+=("$pair")
    done
    if (( ${#missing[@]} == 0 )); then
      ok "shared-library worktrees present"
    elif acting "create ${#missing[@]} worktree(s)"; then
      if [[ -x "$root/$WORK_VLIB/dev" ]]; then
        (cd "$root/$WORK_VLIB" && ./dev setup)
      else
        for pair in "${missing[@]}"; do
          wt="${pair%%|*}"; proj="${pair##*|}"; ref="$(<"$root/$proj/$WORK_PINFILE")"
          git -C "$root/$WORK_VLIB" worktree add "../$wt" "$ref" >/dev/null 2>&1 \
            && printf '    %s -> %s\n' "$wt" "$ref"
        done
        note "the shared repo has no ./dev script; created worktrees directly"
      fi
      changed "worktrees created"
    fi
  fi

  # --- per-project container home -----------------------------------------
  # Bind-mounted as /root inside each container. SSL certs are deliberately not
  # copied: the projects fetch and refresh their own at container start.
  local dh
  for proj in "${WORK_DEVHOMES[@]}"; do
    [[ -d "$root/$proj" ]] || continue
    dh="$root/$proj/.devhome"
    if [[ -d "$dh" ]]; then ok "$proj/.devhome present"; continue; fi
    if acting "create $proj/.devhome"; then
      mkdir -p "$dh"; touch "$dh/.env" "$dh/.zshrc"
      [[ -d "$HOME/.ssh" ]] && cp -R "$HOME/.ssh" "$dh/" 2>/dev/null
      [[ -d "$HOME/.aws" ]] && cp -R "$HOME/.aws" "$dh/" 2>/dev/null
      changed "created $proj/.devhome"
    fi
  done

  # --- per-project local settings -----------------------------------------
  local spec src dst
  for spec in "${WORK_SETTINGS[@]}"; do
    IFS='|' read -r proj src dst <<<"$spec"
    [[ -d "$root/$proj" ]] || continue
    if [[ -f "$root/$proj/$dst" ]]; then
      ok "$proj/$dst present"
    elif [[ -f "$root/$proj/$src" ]] && acting "create $proj/$dst"; then
      cp "$root/$proj/$src" "$root/$proj/$dst"; changed "created $proj/$dst"
    fi
  done

  # --- credentials gate ---------------------------------------------------
  # Everything above is mechanical. Everything below needs credentials, which
  # come from a loaded profile in the credential manager.
  if [[ -z "${AEGIS_LOADED_KEYS:-}" ]]; then
    note "No credential profile is loaded, so image builds and container startup were skipped.
     On a new machine:  $WORK_CREDTOOL setup
                        $WORK_CREDTOOL import bundle <file exported from your other machine>
     Then:              $WORK_CREDTOOL load <profile>   &&   ./bootstrap.sh"
    skip "no credential profile loaded -- stopping before builds"
    return 0
  fi
  ok "credential profile loaded"

  # --- images -------------------------------------------------------------
  local sub
  for spec in "${WORK_IMAGES[@]}"; do
    proj="${spec%%|*}"; sub="${spec##*|}"
    [[ -x "$root/$proj/dev" ]] || continue
    if docker image inspect "$proj" >/dev/null 2>&1; then
      ok "$proj image present"
    elif acting "build $proj image (several minutes, ~2.5GB)"; then
      (cd "$root/$proj" && ./dev "$sub") && changed "built $proj image" || fail "$proj image build failed"
    fi
  done

  # --- bring up the project that provides shared services -----------------
  for proj in "${WORK_SERVICES[@]}"; do
    [[ -x "$root/$proj/dev" ]] || continue
    if docker compose --file "$root/$proj/.devcontainer/docker-compose.yml" ps --status running -q "$proj" 2>/dev/null | grep -q .; then
      ok "$proj containers running"
    elif acting "start $proj containers and initialize"; then
      (cd "$root/$proj" && ./dev up -d && sleep 10 && ./dev initialize) \
        && changed "$proj up and initialized" || fail "$proj startup failed"
    fi
  done
}

step_nvim_sync() {
  (( NVIM_SYNC )) || enabled nvim_sync || return 0
  section "Neovim plugins"
  have nvim || { skip "nvim not installed"; return 0; }
  acting "sync plugins via lazy.nvim" || return 0
  # `restore` pins to lazy-lock.json. Do NOT use `sync`/`update` here: that
  # walks plugins forward off their pinned commits.
  nvim --headless "+Lazy! restore" +qa 2>/dev/null || true
  changed "Neovim plugins restored to lazy-lock.json"
}

usage() {
  sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

main() {
  while (( $# )); do
    case "$1" in
      --dry-run)   DRY_RUN=1 ;;
      --nvim-sync) NVIM_SYNC=1 ;;
      --restore-host) RESTORE_HOST=1 ;;
      --reconfigure)  RECONFIGURE=1 ;;
      -h|--help)   usage ;;
      *) die "Unknown option: $1 (try --help)" ;;
    esac
    shift
  done

  (( DRY_RUN )) && printf '%s[dry run -- nothing will be modified]%s\n' "$C_DIM" "$C_OFF"

  step_preflight
  load_modules
  configure_modules

  section "Modules ($HOSTNAME_SHORT)"
  for k in "${MODULE_KEYS[@]}"; do
    if enabled "$k"; then ok "$k"; else skip "$k (disabled)"; fi
  done

  step_packages
  step_aur_packages
  step_dotfiles
  step_ssh_dir
  step_stow
  step_desktop_db
  step_nvim_default
  step_kernel_modules
  step_host_files
  step_services
  step_airpods
  step_hyprmoncfg
  step_yubikey_ssh
  step_ssh_agent
  step_work_repos
  step_work_setup
  step_nvim_sync

  section "Summary"
  if (( CHANGES == 0 )); then
    ok "everything already in place; nothing to do"
  else
    printf '  %s%d change(s)%s\n' "$C_CHANGE" "$CHANGES" "$C_OFF"
  fi
  if (( ${#NOTES[@]} )); then
    printf '\n%sNotes:%s\n' "$C_BOLD" "$C_OFF"
    for n in "${NOTES[@]}"; do printf '  - %s\n' "$n"; done
  fi
  printf '\n'
}

main "$@"
