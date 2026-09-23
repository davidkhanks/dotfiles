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
