# tickets

A Claude Code plugin that shows your assigned Linear tickets in a pane.

- `/tickets` opens or closes the pane. You can also close it with Esc or the Close button.
- Tickets that are in progress come first, then ones that are queued. Done and canceled tickets are hidden. Each ticket's full description loads with the list. To refresh, close the pane and run `/tickets` again.
- Click anywhere on a ticket's row to expand it and see its team, project, priority and description. Click it again to collapse it. With the keyboard, Tab to a row and press Enter.
- **Start working** asks you to confirm, closes the pane, and prompts Claude to move the ticket to *In Progress*, create its branch and plan the work.
- **Send to Claude** asks you to confirm, closes the pane, and prompts Claude to move the ticket to the *Claude* column so the Claude bot picks it up.

It uses your **claude.ai Linear** connector, so it needs no API key.

All of the plugin's own Linear calls (reading the list and the descriptions) happen while `/tickets` runs. In auto mode, a call a plugin makes from a button press is refused by the classifier whatever the plugin or a settings rule allows, so the buttons that change a ticket ask Claude to do it instead. For those to run without a prompt in auto mode, allow `mcp__claude_ai_Linear__save_issue` under `permissions.allow` in `~/.claude/settings.json`. The status names are `START_STATUS` and `CLAUDE_STATUS` at the top of `hooks/register.tsx`.

## Install

One line, at the prompt of a terminal session. No clone:

```
/plugin install tickets --marketplace davidkhanks/dotfiles
```

Answer `y` to add the marketplace, then Enter for the user scope. It is active
in that session immediately and in every session started afterwards. If you
already added the marketplace (for example by installing `ship`),
`/plugin install tickets@davidkhanks` does the same.

## Requirements

- The **claude.ai Linear** connector, connected in Claude Code (`/mcp` lists it as `claude.ai Linear`).
- Linear statuses named *In Progress* and *Claude*. Change `START_STATUS` and `CLAUDE_STATUS` in `hooks/register.tsx` if your team's differ.
- In auto mode, Start working and Send to Claude have Claude move the ticket with `save_issue`. To skip the classifier for that, add `mcp__claude_ai_Linear__save_issue` to `permissions.allow` in `~/.claude/settings.json`.


## Test

```
claude plugin test claude-plugins/tickets
```
