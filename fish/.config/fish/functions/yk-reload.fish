# Reload the YubiKey PKCS#11 module into ssh-agent -- fish port of the
# yk-reload function in bash/.bashrc.
#
# After unplugging and replugging the key the agent keeps a stale PIV session
# handle and signing fails with "agent refused operation". The udev rule plus
# yubikey-ssh-reload.service do this automatically on insert; this is the
# manual equivalent, and the thing you want when signing starts failing.
#
# Autoloaded: fish reads functions/ lazily by filename, so this file must stay
# named after the function it defines.

function yk-reload --description 'Reload the YubiKey PKCS#11 module into ssh-agent'
    set -l lib /usr/lib/libykcs11.so
    # The unload is expected to fail when nothing is loaded yet; that is not an
    # error worth showing.
    ssh-add -e $lib 2>/dev/null
    ssh-add -s $lib
end
