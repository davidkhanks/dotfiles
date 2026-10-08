# ship

A `/ship` command that takes the work in front of you from uncommitted to a
reviewed PR, and a **Ship** button above the prompt that runs it.

The band appears only when there is something to ship, and says what:

```
feat/thing: 2 uncommitted, 1 unpushed  [ Ship ] [ Hide ]
```

## Install

```bash
claude plugin marketplace add ~/dotfiles/claude-plugins
```

Then, at a terminal session's prompt:

```
/plugin install ship --marketplace davidkhanks
```

Answer `y` to add the marketplace, then Enter for the user scope.

Because the marketplace is a folder and the entry is a relative path, the
plugin is read from **this repo**, not from a copy. Edit a file here and run
`/reload-plugins` -- no reinstall, no version bump.

## What is in it

| Path | What |
|---|---|
| `commands/ship.md` | The `/ship` command: branch, commit, push, PR, wait for the auto-review, address it |
| `hooks/register.tsx` | The band and its button |
| `hooks/ship.test.ts` | 6 tests, over the terminal and desktop surfaces |
| `types/index.d.ts` | The `$.state` contract the engine holds the module to |

## Developing

```bash
claude plugin validate ~/dotfiles/claude-plugins/ship
claude plugin test     ~/dotfiles/claude-plugins/ship
```

Two things the engine enforces that are easy to trip over:

- `$.prompt.submit` **refuses text beginning with `/`**. Running a command from
  a hook is `$.command.run({ command: 'ship' })`.
- `$` may only be passed to a function **declared at the top of the file**, not
  to a closure defined inside `register`.
