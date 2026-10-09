# prs

A Claude Code plugin that shows the current repo's pull requests in a pane. It works with Bitbucket and GitHub, depending on the `origin` remote.

- `/prs` opens or closes the pane. You can also close it with Esc or the Close button.
- **Open** (the default), **Draft** and **Merged** filter the list, with a count on each. Merged shows the 20 most recent.
- Each row shows the PR number, author and title. Click anywhere on a row to expand it and see its branch, last update and description.
- **Address comments** asks you to confirm, closes the pane, and prompts Claude to check out the branch, address every unresolved review comment, run the tests, commit and push, then reply to and resolve each thread. It doesn't wait for a new bot review.
- **Check out** prompts Claude to check out the branch and stop.
- **Approve** prompts Claude to approve the PR and leaves the pane open. A PR you've approved shows "✓ You approved this", read when `/prs` loads.
- Once a PR is approved by you (or you've just pressed Approve), **Squash** and **Merge** appear. Each asks you to confirm, then prompts Claude to merge with that strategy (squash, or a merge commit) and close the source branch. If the merge is refused, for example by failed merge checks, Claude says why and stops.
- Draft PRs offer neither Approve nor the merge buttons.
- **Open in browser** opens the PR.

Everything, descriptions included, loads when `/prs` runs. To refresh, close the pane and run `/prs` again. In auto mode, a call a plugin makes from a button press is refused by the classifier, so the filters and expanded views use what was already loaded, and the action buttons ask Claude to do the work.

- **Bitbucket** uses the `bitbucket` MCP server (`bb_get`), which needs its Atlassian credentials loaded before Claude Code starts.
- **GitHub** uses the `gh` CLI, which needs `gh auth login`.

## Install

One line, at the prompt of a terminal session. No clone:

```
/plugin install prs --marketplace davidkhanks/dotfiles
```

Answer `y` to add the marketplace, then Enter for the user scope. It is active
in that session immediately and in every session started afterwards. If you
already added the marketplace (for example by installing `ship`),
`/plugin install prs@davidkhanks` does the same.

## Requirements

- **Bitbucket repos:** the `bitbucket` MCP server, set up as in the myeducator repo's `scripts/dev/BITBUCKET_MCP_SETUP.md`, with its Atlassian credentials loaded before Claude Code starts.
- **GitHub repos:** the `gh` CLI, logged in with `gh auth login`.


## Test

```
claude plugin test claude-plugins/prs
```
