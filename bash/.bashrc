# Omarchy environment (OMARCHY_PATH + PATH), needed even for non-interactive shells
[[ -r /usr/share/omarchy/default/bash/env-bootstrap ]] && source /usr/share/omarchy/default/bash/env-bootstrap

# If not running interactively, don't do anything else (leave this above the rc source)
[[ $- != *i* ]] && return

# --- ble.sh (Bash Line Editor) ----------------------------------------------
# Fish-style autosuggestions: a greyed-out completion from history appears as
# you type, and Right / End accepts it. Also syntax highlighting and a better
# completion menu. Installed user-local under ~/.local by bootstrap.sh -- no
# root, no AUR.
#
# This is a two-part load and the order is not optional. ble.sh must be sourced
# EARLY, before anything that installs a PROMPT_COMMAND -- Omarchy's rc runs
# `starship init bash` -- but with --noattach so it does not take over the line
# editor yet. It then attaches at the very END of this file, once every prompt
# hook is registered. Attaching first, or sourcing after starship, leaves ble.sh
# fighting the prompt for control of the display.
[[ -r "$HOME/.local/share/blesh/ble.sh" ]] && source "$HOME/.local/share/blesh/ble.sh" --noattach

# All the default Omarchy aliases and functions
# (don't mess with these directly, just overwrite them here!)
#
# Guarded because this file is stowed on non-Omarchy machines too (the CachyOS
# gaming box). There OMARCHY_PATH is unset, line 2 above never fires, and an
# unguarded source expands to "/default/bash/rc" -- an error printed on every
# single interactive shell.
[[ -r "${OMARCHY_PATH-}/default/bash/rc" ]] && source "$OMARCHY_PATH/default/bash/rc"

# --- starship ---------------------------------------------------------------
# Omarchy's rc (just above) runs `starship init bash` itself. Nothing does on a
# non-Omarchy machine, so before this the stowed ~/.config/starship.toml was
# installed on every box and read on exactly one of them -- the config was
# there, the prompt was the plain bash default, and nothing reported a problem.
#
# The guard is the same test as the source above, deliberately: if that line
# fired, starship is already initialised and doing it twice would register two
# PROMPT_COMMAND hooks.
#
# Position matters for the same reason the rc does. This must stay AFTER the
# ble.sh --noattach near the top of the file and BEFORE ble-attach at the very
# bottom; starship installs a prompt hook, and ble.sh has to see it.
if [[ ! -r "${OMARCHY_PATH-}/default/bash/rc" ]] && command -v starship >/dev/null 2>&1; then
  eval "$(starship init bash)"
fi

# --- ble.sh x fzf ------------------------------------------------------------
# Omarchy's default/bash/init sources fzf's raw completion.bash and
# key-bindings.bash unconditionally. ble.sh's manual is explicit that fzf
# settings loaded elsewhere must be disabled in a ble.sh session, and ships
# replacement modules that do the same job in a way the line editor understands.
#
# These therefore go HERE, after Omarchy's rc, rather than in ~/.blerc where the
# manual suggests. .blerc is read when ble.sh is sourced -- which is above, and
# so before Omarchy loads the raw bindings -- and the raw ones would then win.
# Loading after the rc lets the ble.sh versions take the keys instead.
#
# Arch installs fzf's shell files flat in /usr/share/fzf rather than in a
# shell/ subdirectory, which is where the module looks by default.
if [[ ${BLE_VERSION-} ]]; then
  _ble_contrib_fzf_base=/usr/share/fzf
  ble-import -d integration/fzf-completion
  ble-import -d integration/fzf-key-bindings
fi

# Add your own exports, aliases, and functions here.
#
# Make an alias for invoking commands you use constantly
# alias p='python'

# --- YubiKey ssh-agent -------------------------------------------------------
# PIV slot 9A is PIN-NEVER / TOUCH-CACHED, so the key itself only wants a touch.
# The PIN prompt comes from the PKCS#11 layer logging into the token. Loading
# the provider into a long-lived agent means that PIN is entered once per login
# instead of once per git operation.
#
#   ssh-add -s /usr/lib/libykcs11.so   # once per login: PIN, then touch per use
#   ssh-add -L                         # what the agent currently holds
#   ssh-add -e /usr/lib/libykcs11.so   # unload (e.g. after unplugging)
export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR:-/run/user/$UID}/ssh-agent.sock"
export SSH_ASKPASS=/usr/bin/lxqt-openssh-askpass

# Reload the PKCS#11 module after unplugging/replugging the YubiKey. The agent
# keeps a stale PIV session handle otherwise and signing fails with
# "agent refused operation". The udev rule + yubikey-ssh-reload.service do this
# automatically on insert; this is the manual equivalent.
yk-reload() {
  local lib=/usr/lib/libykcs11.so
  ssh-add -e "$lib" 2>/dev/null
  ssh-add -s "$lib"
}

# --- aegis ------------------------------------------------------------------
# Encrypted env-var profiles unlocked by the YubiKey. The hook wraps `aegis` so
# load/unload can modify the current shell's environment.
#   aegis list            what profiles exist
#   aegis load <profile>  export its vars into this shell (touch)
#   aegis status          what is loaded and when it expires
command -v aegis >/dev/null 2>&1 && eval "$(aegis shell-init bash)"

# --- llama.cpp ---------------------------------------------------------------
# Keep downloaded GGUF models in ~/models rather than ~/.cache, where a cache
# cleaner would happily delete 20+ GB. Read by llama.cpp's own -hf downloader.
export LLAMA_CACHE="$HOME/models"

# --- pk ----------------------------------------------------------------------
# Pick processes with fzf and kill them. `pk` sends TERM, `pk KILL` sends -9.
# Tab multi-selects; the preview pane shows the full command line of whatever is
# highlighted, which is how you catch yourself aiming at the wrong PID.
#
# This is the inverse of pkill: pkill takes a pattern up front and kills
# immediately, so there is no point at which fzf could choose for you.
pk() {
  local sig="${1:-TERM}" pids
  pids=$(
    ps -eo pid,user,%cpu,%mem,etime,comm,args --sort=-%cpu \
      | fzf --header-lines=1 --multi --reverse --height=60% \
            --prompt="kill -$sig > " \
            --preview='ps -p $(echo {} | awk "{print \$1}") -o pid,ppid,user,etime,rss,args --no-headers 2>/dev/null' \
            --preview-window=down:4:wrap \
      | awk '{print $1}'
  )
  [ -z "$pids" ] && { echo "pk: nothing selected"; return 1; }
  echo "$pids" | xargs -r kill -"$sig" && echo "pk: sent SIG$sig to $(echo $pids | tr '\n' ' ')"
}

# --- ble.sh, part two -------------------------------------------------------
# Must be the LAST line: attaching hands ble.sh the line editor, and anything
# registering a prompt hook afterwards would be invisible to it.
[[ ${BLE_VERSION-} ]] && ble-attach
