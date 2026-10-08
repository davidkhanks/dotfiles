# ship

A `/ship` command that takes the work in front of you from uncommitted to a
reviewed PR, and a **Ship** button above the prompt that runs it.

The band appears only when there is something to ship, and says what:

```
feat/thing: 2 uncommitted, 1 unpushed  [ Ship ] [ Hide ]
```

Pressing **Ship** runs the command. What it does, in order: branch if you are
on the default branch, commit anything uncommitted, push, open a PR (reusing
one that already exists for the branch), poll once a minute for up to seven
minutes for an automated review, address what it raises, then commit and push
the fixes. It reports what it changed and what it declined.

## Install

One line, at the prompt of a terminal session. No clone:

```
/plugin install ship --marketplace davidkhanks/dotfiles
```

Answer `y` to add the marketplace, then Enter for the user scope. It is active
in that session immediately and in every session started afterwards.

## Requirements

| | |
|---|---|
| Claude Code | **2.1.293 or newer** for the button; the `/ship` command alone works on older builds |
| `gh` | authenticated (`gh auth status`) -- the command opens the PR with it |
| git | a repo with a remote; the band stays hidden anywhere else |

**On an older build you get the command and no button, with nothing to say
why.** If `/ship` works but no band appears, check `claude --version` first.

## It only addresses a review it can defend

Step 6 does not apply every suggestion it is given. It fixes real bugs, missed
cases and convention violations, and pushes back in a thread on the rest rather
than changing code to clear a comment. A bot being confident is not evidence
that it is right. If you would rather it be more obedient, or stop and ask
before editing, that is a paragraph in `commands/ship.md`.

If no review lands inside seven minutes it says so and leaves the PR open. If
your CI reviews more slowly than that, raise the loop count in the same file.

## Developing it

The marketplace entry is a relative path, so a plugin installed **from a local
folder** is read from that folder, never from a copy: edit a file and run
`/reload-plugins` -- no reinstall, no version bump. Clone the repo, then:

```bash
claude plugin marketplace add <path-to-this-repo>
claude plugin install ship@davidkhanks
```

Checks:

```bash
claude plugin validate <path-to-this-repo>/claude-plugins/ship
claude plugin test     <path-to-this-repo>/claude-plugins/ship
```

| Path | What |
|---|---|
| `commands/ship.md` | The `/ship` command |
| `hooks/register.tsx` | The band and its button |
| `hooks/ship.test.ts` | 6 tests, over the terminal and desktop surfaces |
| `types/index.d.ts` | The `$.state` contract the engine holds the module to |

Three things the engine enforces that are easy to trip over:

- `$.prompt.submit` **refuses text beginning with `/`**. Run a command from a
  hook with `$.command.run({ command })`.
- A plugin's command is **namespaced** (`ship:ship`), and that spelling is the
  engine's to choose -- so `runShip` resolves it from `$.command.list()` by
  owning plugin rather than by a guessed name.
- `$` may only be passed to a function **declared at the top of the file**, not
  to a closure defined inside `register`.

An unhandled rejection in a press handler is silence, and silence is
indistinguishable from a dead button -- so every failure path ends in a
`$.ui.toast` that names what went wrong.
