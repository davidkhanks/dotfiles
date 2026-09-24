# SSH between my own machines

Enabled by the `ssh_server` module, **off by default**. The goal is that
whichever machine the YubiKey is plugged into can reach every other machine,
from anywhere, without opening anything to an untrusted network.

## Shape

| | |
|---|---|
| who may log in | the public keys in `SSH_AUTHORIZED_KEYS` in `bootstrap.sh` |
| authentication | YubiKey PIV key — **a physical touch per login** |
| passwords | disabled outright, along with root login and keyboard-interactive |
| reachable from | the tailnet only; every other interface is closed |

Committing the **public** half to a public repo is safe by construction — that
asymmetry is the entire point of the key pair. The private half never leaves
the token, so the key in the repo authorizes nothing without the hardware.

## The firewall rule is interface-scoped, not address-scoped

```bash
ufw allow in on tailscale0 to any port 22 proto tcp
```

which produces exactly one accept path:

```
-A ufw-user-input -i tailscale0 -p tcp -m tcp --dport 22 -j ACCEPT
```

ufw defaults to deny-incoming here, so port 22 is open on `tailscale0` and
closed on wifi, ethernet and docker. Scoping by **interface** rather than by
address is deliberate: an address rule would mean committing a tailnet IP to
this public repo, and would break whenever the address changed.

**Do not test this from the machine itself.** Connecting to your own LAN
address routes over loopback, and ufw accepts all loopback traffic:

```
-A ufw-before-input -i lo -j ACCEPT
```

so a self-test reports port 22 open on the LAN address and proves nothing. Test
from another machine, or read the iptables rules as above.

## sshd hardening

`step_ssh_server` writes `/etc/ssh/sshd_config.d/10-hardening.conf`:

```
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
```

It is written by the step rather than tracked in `hosts/<hostname>/` because it
is identical on every machine — the same precedent as the udev rule written by
`step_yubikey_ssh`. `authorized_keys` is appended to rather than stowed:
other tools legitimately add to it, and sshd's `StrictModes` is fussy about
what it will read from a symlink.

## Running bootstrap remotely

It mostly works, and it fails in the right places.

- `sudo` needs a TTY, so use **`ssh -t <host> 'cd dotfiles && ./bootstrap.sh'`**.
- `--dry-run` needs no sudo for most checks and is the right way to inspect a
  machine's state from elsewhere. The one exception is the ufw check, which
  cannot read firewall state without root and reports
  `cannot read ufw state without sudo` rather than proposing a rule that may
  already exist.
- The YubiKey-dependent steps (`work_repos`, `work_setup`, the Remmina profile
  restore) need the token **physically in the remote machine**. SSH agent
  forwarding does not help: it forwards SSH *authentication*, not the PIV
  session that `age` needs to decrypt. Those steps fail cleanly and everything
  else still runs.

So a remote run is genuinely useful for packages, stow, services, plugins and
host files; the encrypted-payload steps stay a sit-at-the-machine job.

## The alternative that was not chosen

`tailscale up --ssh` makes Tailscale terminate SSH itself: no open port, no
`authorized_keys`, no host keys, and access governed by tailnet ACLs. It is
less work.

It was not chosen because authentication becomes **tailnet identity rather than
a YubiKey touch** — any already-logged-in device on the tailnet gets a shell on
everything, with no physical confirmation. Given that the SMB account, the RDP
account and the work credentials are all deliberately separated here, handing
out unattended shell access on device identity alone is the wrong trade. The
two are not mutually exclusive if that changes.
