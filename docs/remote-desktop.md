# Remote desktop (RDP)

Connecting to the headless Windows box over the tailnet, the GUI equivalent of
the Windows App on macOS. The SMB side of the same machine is in
[`smb-shares.md`](smb-shares.md).

Installed by the `rdp` module. RDP is reachable over the tailnet exactly as SMB
is — `port 3389` is open on the target, so this works from anywhere both
machines have internet, not just at home.

## The packaging trap

In Arch, both of the things that make Remmina useful are **optional**
dependencies:

```
remmina  Optional Deps : freerdp: RDP plugin
                         libsecret: Secret plugin
```

Install `remmina` alone and you get a remote desktop client that launches
perfectly well and offers **no RDP protocol option at all** — a confusing way to
discover a missing package. Without `libsecret`, connection passwords are stored
obfuscated in the `.remmina` profile rather than in the keyring.

Hence `PACKAGES_RDP=(remmina freerdp libsecret)`, and `step_rdp` verifies the
plugins actually landed rather than trusting the package list:

```
/usr/lib/remmina/plugins/remmina-plugin-rdp.so
/usr/lib/remmina/plugins/remmina-plugin-secret.so
```

## Profiles are not tracked

Remmina keeps connection profiles as plain files in
`~/.local/share/remmina/*.remmina`. They are deliberately **not** stowed: a
useful one carries a server and a username, and this repo is public. Passwords
go to the keyring through the Secret plugin, never into the file.

`step_rdp` reports how many profiles exist and points at the GUI when there are
none, rather than generating one.

## Rolling profiles out to other machines

Profiles travel as an age-encrypted tar, `secrets/remmina-profiles.age`,
encrypted to the same recipients as the work manifest.

**What is inside is settings, a server and a username — not a password.** With
the Secret plugin active, Remmina writes the literal placeholder `password=.`
into the `.remmina` file and keeps the real secret in the local keyring. So a
restored profile is complete except for the password, which is entered once per
machine. That is the right split: the payload is worth little if it leaks, and
no password is ever written to disk in the clear on any machine.

`remmina.pref` is **not** in the payload. It holds the `secret=` key Remmina
uses to obfuscate passwords when the keyring is unavailable, and it is
machine-local by design.

Refresh the payload after adding or editing a profile:

```bash
cd ~/dotfiles
tar -C ~/.local/share/remmina -cf - --sort=name --owner=0 --group=0 \
    --numeric-owner *.remmina \
  | age -e -R secrets/recipients.txt -o secrets/remmina-profiles.age
```

Encrypting needs no YubiKey. Decrypting does, and **needs a real terminal** —
`age -d` with a YubiKey identity prompts for the PIN on `/dev/tty`, so it
cannot be driven from a non-interactive tool call.

`step_rdp` restores only when there are **no** local profiles. Decrypting every
run would demand a touch every time and would clobber profiles edited in the
GUI since the payload was last refreshed. To pull updated profiles down, delete
the local ones first, or unpack by hand:

```bash
age -d -i secrets/yubikey-identity.txt secrets/remmina-profiles.age \
  | tar -C ~/.local/share/remmina -xf -
```

### secrets/recipients.txt

The public keys every payload under `secrets/` is encrypted to now live in
`secrets/recipients.txt`. Public keys are safe to commit, and committing them is
the point — re-encrypting should never depend on remembering what the offline
backup key was. It lists the YubiKey PIV slot that the committed identity stub
resolves to, plus the offline backup recipient.

## The account is not the SMB account

RDP requires membership in the **Remote Desktop Users** group (or
Administrators). The dedicated share-only account used for SMB is deliberately
neither, so it cannot open an RDP session — that is the separation working, not
a fault. Use the normal interactive Windows login. To check on the Windows side:

```powershell
Get-LocalGroupMember -Group "Remote Desktop Users"
```

## If Remmina feels sluggish

`freerdp` also ships a **native Wayland** client, which renders directly rather
than through GTK or XWayland — usually better on a HiDPI panel:

```
/usr/bin/wlfreerdp3     native Wayland
/usr/bin/sdl-freerdp3   SDL
/usr/bin/xfreerdp3      X11 / XWayland

wlfreerdp3 /v:<host> /u:<user> /dynamic-resolution /clipboard /sound
```

No connection manager, but for a single machine a `.desktop` launcher around
that one line is a one-click icon. Remmina uses FreeRDP underneath either way,
so this is a different front end, not a different protocol implementation.
