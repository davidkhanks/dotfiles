# panther

Framework Laptop 13 (Intel Core Ultra Series 3). Root-owned files that cannot
be stowed, installed by `bootstrap.sh` via `HOST_FILES`.

## `etc/systemd/logind.conf.d/30-lid-external-power.conf`

Sets `HandleLidSwitchExternalPower=ignore` so losing the external display in
clamshell mode does not suspend the machine while it is on AC. See the comments
in the file for why the default does the wrong thing here.

Unlike the CoolerControl config under `hosts/omarchy/`, this one carries no
hardware-derived identifiers and would be safe on any laptop; it lives here
because the desktop has no lid.
