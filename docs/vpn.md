# VPN

Covers Tailscale, which is set up, and the decision still open about running a
commercial VPN (VPN.ac) alongside it.

## Tailscale (done)

Omarchy has **first-party** Tailscale support, so nothing third-party is
involved and none of the plugin caveats in README apply here:

| piece | where it comes from |
|---|---|
| `omarchy.tailscale` bar widget | ships with Omarchy, disabled by default |
| `omarchy-tailscale-receive.service` | ships with Omarchy; Taildrop files land in `~/Downloads` |
| `omarchy-install-service-tailscale` | Omarchy's one-shot installer |

The `tailscale` module in `bootstrap.sh` reproduces what Omarchy's installer
does, minus the one part that cannot be automated:

```bash
omarchy-pkg-add tailscale                              # PACKAGES_TAILSCALE
sudo systemctl enable --now tailscaled.service         # step_services
sudo tailscale set --operator="$USER"                  # step_tailscale
systemctl --user enable --now omarchy-tailscale-receive.service
omarchy-plugin-enable omarchy.tailscale
omarchy-webapp-install "Tailscale" <admin console>     # WEBAPPS
```

**`tailscale up` is deliberately not run by bootstrap.** Account auth is a
browser flow, and re-running it every bootstrap would also stomp flags set by
hand. The step reports the logged-out state and leaves it to the operator:

```bash
sudo tailscale up --accept-routes
```

### Why the operator check is written the way it is

`--operator` is what lets `tailscale` commands — and the bar widget, which
shells out to them — work without sudo. Detecting whether it is already set is
awkward: it does **not** appear in `tailscale debug prefs` until it has been
set at least once. Measured on 1.102.3:

```
before:  35 fields, no OperatorUser
after:   36 fields, "OperatorUser": "davidkhanks",
```

So "field absent" means unset, and the step matches on the field rather than
running `tailscale set` unconditionally, which would report a change on every
run and break the idempotency contract.

## VPN.ac alongside Tailscale (not done — decision open)

### Can they coexist?

Tailscale's own documentation is not encouraging:

> "It's theoretically possible to use Tailscale alongside other virtual private
> networks (VPNs)… However, in most cases, you can't use Tailscale alongside
> other VPNs without a workaround."

Three conflicts, in the order they are likely to matter:

1. **Kill switches.** *"Most VPNs set aggressive firewall rules to ensure all
   network traffic goes through them. This can result in the other VPN dropping
   all Tailscale traffic."* This is the decider. Check the VPN.ac `.conf` for
   `PostUp`/`PostDown` iptables rules before assuming anything.
2. **Exit nodes are mutually exclusive.** *"Exit nodes only support one VPN at
   a time."* Ordinary tailnet access is fine; routing out through a Tailscale
   exit node while VPN.ac is up is not.
3. **CGNAT overlap.** If VPN.ac hands out addresses inside `100.64.0.0/10` it
   collides with Tailscale's range. Unlikely, but cheap to check.

### Why it will probably work anyway

VPN.ac's Linux path is WireGuard: generate a `.conf` from their key management
tool, drop it in `/etc/wireguard/`, `wg-quick up`. With
`AllowedIPs = 0.0.0.0/0`, `wg-quick` installs a policy rule containing
`suppress_prefixlength 0`, which keeps **more specific** routes in the main
table alive. Tailscale's `100.64.0.0/10` is more specific than a default route,
so it survives.

Expect Tailscale to keep working but fall back to **DERP relays rather than
direct connections**, because VPN.ac's NAT breaks UDP hole punching. Functional,
just slower peer to peer. To confirm once both are up:

```bash
tailscale status          # shows "direct" or "relay" per peer
tailscale ping <peer>     # reports which path it took
```

### The secret problem, which has to be settled first

**A VPN.ac WireGuard `.conf` contains a private key, and this repo is public.**
It cannot be committed as-is. Two options:

- Keep it out of the repo entirely — it lives only in `/etc/wireguard/` and is
  re-fetched by hand on a new machine.
- Encrypt it as `secrets/vpn-ac.age` with the existing age + YubiKey identity,
  exactly like `work-repos.age`, and have a `vpn` module decrypt and import it.
  This reuses machinery that already exists and is the better fit.

### Managing it: NetworkManager, not a plugin

NetworkManager (already the network stack here) imports WireGuard natively:

```bash
nmcli connection import type wireguard file vpn-ac-<location>.conf
```

After that it is an ordinary NM connection, togglable from `nmtui`, `nmcli` or
Omarchy's existing network controls — **no new code in the bar process.**

Third-party Omarchy VPN widgets exist, but all are tiny and unproven, and the
objection recorded in README about plugins running unsandboxed inside
`omarchy-shell` applies to every one of them:

| plugin | traction | scope |
|---|---|---|
| `tpatzelt/omarchy-vpn-widget` | 3 ★, 1 fork, MIT | NetworkManager only, no extra deps |
| `vinicgobbi/omarchy-plugin-vpn` | 1 ★, 0 forks, MIT | Tailscale + NM, `.ovpn` import |
| `igor-alexandrov/omarchy-tailscale` | 1 ★, 0 forks, **no license** | Tailscale only |

The first-party widget already covers Tailscale, so adopting any of these would
be taking on unsandboxed third-party code for the VPN.ac half alone.

### If this gets built

A `vpn` module: `wireguard-tools`, decrypt `secrets/vpn-ac.age`, import with
`nmcli connection import`. Left disconnected by default — bringing a full tunnel
up automatically on boot is not wanted. Revisit the kill-switch question above
before writing any of it.

## Sources

- <https://tailscale.com/kb/1105/other-vpns>
- <https://vpn.ac/knowledgebase/126/WireGuard-on-Linux-using-terminal.html>
