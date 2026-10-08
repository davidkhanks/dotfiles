# Adding event creation to the calendar agenda plugin

Status: **not started.** Notes from the 2026-10-08 investigation so this can be
picked up cold. Nothing here is committed to the plugin or to `bootstrap.sh`.

The plugin is [alexinslc/omarchy-calendar-agenda][repo], installed 2026-10-07
and placed in the bar's center section after `omarchy.clock`. It is read-only by
design. The goal is creating events from the panel instead of opening Google
Calendar in a browser.

[repo]: https://github.com/alexinslc/omarchy-calendar-agenda

## Decide this first

Three routes, and the cheapest one may not be the fork:

1. **Fork and add write support.** ~1 day, mostly QML. Details below.
2. **Switch to [tmn73/omarchy-calendar][tmn73].** Already has create, edit and
   delete with a full form (date picker, 15-minute steps, repeat, guests, Meet).
   40 stars vs 1. The catch is multi-account: its write-capable `gws` backend
   authenticates as **one** Google account. Its multi-account `ics` backend is
   read-only *and* laggy, because Google regenerates secret iCal feeds on its
   own schedule. **Open question: can the `gws` backend hold two accounts?**
   Worth ten minutes of reading before choosing route 1.
3. **Upstream a PR instead of forking.** The author is active (15 merged PRs,
   commits most days). Read-only is advertised as a privacy feature so he may
   decline, but asking costs nothing and beats maintaining a fork.

[tmn73]: https://github.com/tmn73/omarchy-calendar

**The Google Cloud project below is required for routes 1 and 2 equally**, so it
is not a reason to prefer one over the other.

## The gate: register our own OAuth client

Not optional, and it is the real blocker.

```python
# sync/config.py:23
REMOTE_CONFIG_URL = "https://omarchy.alexinslc.com/calendar-agenda/oauth/client-config"
```

There is no client ID in the repo. The plugin fetches the author's at runtime
and caches it for 24h at `~/.local/state/omarchy/calendar-agenda/oauth-client.json`,
which is the path currently in use here. **That app is registered read-only, and
scopes cannot be added to a client we do not own** -- Google rejects scopes a
client is not configured for, and the consent screen is his.

So: create a Google Cloud project with a Desktop OAuth client, then write it to
the private override path, which takes precedence over the remote fetch:

```
~/.config/omarchy/calendar-agenda/config.json      # sync/config.py:17
```

Shape is in `oauth-client.example.json` in the repo root.

- `calendar.events` (write) is a **sensitive** scope -- the same tier as the
  `calendar.events.readonly` already in use. No extra verification burden.
- **Publish the app to Production.** In Testing mode Google expires refresh
  tokens every 7 days. Production shows one unverified-app warning, then works
  indefinitely.
- ~15-20 minutes of clicking, once. One client covers both accounts.

## Python changes (~70 lines)

The extension points are clean. `_json_request` already accepts any
`urllib.request.Request`, so it handles POST unchanged -- no new HTTP plumbing.

| What | Where | Size |
|---|---|---|
| Swap `calendar.events.readonly` for `calendar.events` | `sync/google.py:27` (`READ_ONLY_SCOPES`, and rename it) | 1 line |
| Add `_post()` beside `_get()` | `sync/google.py:405`, in `GoogleCalendarClient` (`:399`) | ~12 |
| `create_event()` -- POST `/calendars/{calendarId}/events` | after `list_events` (`sync/google.py:438`) | ~25 |
| `--create-event` action | `sync/cli.py`, alongside `--sync` / `--add-account` | ~30 |

## QML changes (~300-500 lines) -- the actual work

A new-event form: title, date picker, start/end time, calendar dropdown, all-day
toggle, validation. `AgendaPanel.qml` is already 24 KB, so this probably wants
its own file.

**The bridge already exists**, so no IPC design is needed:

```qml
// OnboardingService.qml:82
actionProcess.command = ["/usr/bin/python3", root.helperPath].concat(args)
```

It spawns `python3 calendar_agenda.py <args>` and parses JSON back. The form
calls that with `--create-event --json`, then `--sync` so the event appears.

## Gotchas

- **Every account must re-consent.** Existing refresh tokens carry read-only
  scopes and Google will not upgrade them silently. Run `--reconnect-account`
  for each; the command already exists.
- **Timezones.** Send `dateTime` *plus* an explicit `timeZone` field rather than
  relying on UTC offsets. This is where naive calendar-write code breaks across
  DST, and it will not show up in testing until March.
- **Sync window is today + 28 days**, so a newly created event further out will
  not appear even after a successful write. Expected, not a bug.
- The systemd timer runs `:00/:15/:30/:45` with `Persistent=true`. Force a sync
  with `python3 calendar_agenda.py --sync` from the plugin directory.

## Still outstanding

- `bootstrap.sh` has no module for this plugin yet, deliberately -- it is on
  trial. If it stays, it needs a `step_calendar_agenda` mirroring
  `step_omastats`, a `MODULE_KEYS` entry, and a placement entry so a rebuild
  does not bury it at position 16 of the right section.
- The bar icon is permanently visible. Bar widgets cannot go in the tray's
  slide-out drawer -- `Tray.qml` matches against `SystemTray.items`, which only
  holds SNI tray icons. Same finding as `zakarch.storage`.
