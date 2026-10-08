# ship

A `/ship` command that takes the work in front of you from uncommitted to a
reviewed PR, and a **Ship** button above the prompt that runs it.

The band appears only when there is something to ship, and says what:

```
feat/thing: 2 uncommitted, 1 unpushed  [ Ship ] [ Hide ]
```

Pressing **Ship** runs the command. It always branches (if you are on the
default branch), commits anything uncommitted and pushes. **How much further it
goes depends on the host:**

| Origin | What happens |
|---|---|
| `bitbucket.org` | opens a PR (reusing an open one for the branch), polls once a minute for up to seven minutes for the automated review, addresses what it raises, commits and pushes the fixes |
| `github.com` | stops after the push -- no PR |
| anything else | stops after the push -- no PR |

Stopping after the push is a success, not a partial run: the review workflow is
Bitbucket-only, and the command says so rather than leaving you wondering.

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
| git | a repo with a remote; the band stays hidden anywhere else |
| Bitbucket MCP | only for the PR half. `@aashari/mcp-server-atlassian-bitbucket`, with credentials configured. Without it the command still commits and pushes |

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

Bitbucket is reachable only through MCP tools, never a CLI, so `Monitor` cannot
query it. It runs as a bare heartbeat and the polling happens on each tick --
worth knowing before you try to "simplify" that loop into a single shell
command.

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
