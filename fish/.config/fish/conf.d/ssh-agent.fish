# YubiKey ssh-agent environment, fish side.
#
# bash/.bashrc exports these two for bash. fish never reads .bashrc, so on a
# fish machine neither one was ever set and `ssh-add` talked to whatever agent
# the desktop session happened to start -- or to none at all.
#
# SSH_AUTH_SOCK is also set by ssh/.config/environment.d/10-ssh-agent.conf,
# which is the more general fix: systemd's user manager reads it and every
# process it spawns inherits it. It is repeated here for the same reason
# .bashrc repeats it -- environment.d is read when `systemd --user` starts, so
# a shell in a session that predates the file (the login right after
# bootstrap.sh first stows it) does not have it, and a plain new terminal will
# not bring it back. Setting it here makes the shell correct immediately
# rather than one logout later.

set -l _runtime $XDG_RUNTIME_DIR
test -n "$_runtime"; or set _runtime /run/user/(id -u)
set -gx SSH_AUTH_SOCK "$_runtime/ssh-agent.sock"

# The GUI PIN prompt for the PKCS#11 login. gcr-ssh-askpass refuses to run
# standalone, hence lxqt's. Guarded because the yubikey module is what installs
# it: pointing SSH_ASKPASS at a binary that does not exist is worse than
# leaving it unset, since ssh-add then fails instead of falling back to the
# terminal prompt.
if test -x /usr/bin/lxqt-openssh-askpass
    set -gx SSH_ASKPASS /usr/bin/lxqt-openssh-askpass
end
