---
description: Commit and push; on Bitbucket also open a PR and address the auto-review
allowed-tools: Bash(git:*), Monitor, Read, Edit, Write, Grep, Glob, mcp__bitbucket__bb_get, mcp__bitbucket__bb_post
---

## Context

- Branch: !`git branch --show-current`
- Default branch: !`git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|origin/||' || echo main`
- Origin: !`git remote get-url origin 2>/dev/null || echo "(no origin)"`
- Status: !`git status --short`
- Change summary: !`git diff HEAD --stat`

## Your task

Ship the current work. Do not ask for confirmation between steps -- the point
of this command is that it runs unattended. Do stop and report if a step fails.

**How far it goes depends on the host**, read from `Origin` above:

| Origin | What this command does |
|---|---|
| `bitbucket.org` | everything: commit, push, PR, wait for the review, address it |
| `github.com` | commit and push only, then **stop** |
| anything else | commit and push only, then **stop** |

### 1. Branch

If the current branch is the default branch, create one named for the work
(`type/short-description`). Otherwise stay put.

### 2. Commit

If there are uncommitted changes, stage and commit them in a single commit.
Write a real message: what changed and why, not a restatement of the diff. If
the tree is already clean, skip -- the work may already be committed.

This command commits on your behalf. Where a project's conventions say an
agent should not commit unprompted, invoking this command *is* the deliberate
exception -- that is the whole point of it.

### 3. Push

`git push -u origin <branch>`. Say so before pushing: a push may need a
hardware-key touch, a passphrase or an SSO re-auth, and the user should not
have to notice a silent prompt.

### 4. Stop here unless the origin is Bitbucket

**On GitHub or any other host, this is the end.** Report the branch, the
commit and that it is pushed, and say plainly that no PR was opened and why
(the review workflow below is Bitbucket-only). Do not open a PR, do not reach
for `gh`, do not poll. Stopping here is success, not a partial failure.

### 5. Bitbucket: open the PR

Parse `<workspace>` and `<repo>` out of `Origin` -- both SSH
(`git@bitbucket.org:<workspace>/<repo>.git`) and HTTPS forms appear. Never
assume a workspace; always read it from the remote.

First check whether this branch already has one open, and reuse it if so:

```
bb_get  path: /repositories/<workspace>/<repo>/pullrequests
        queryParams: { q: 'state="OPEN" AND source.branch.name="<branch>"', pagelen: "5" }
        jq: "values[*].{id: id, title: title, link: links.html.href}"
```

If there is none, create one against the default branch:

```
bb_post path: /repositories/<workspace>/<repo>/pullrequests
        body: { "title": "...", "description": "...",
                "source": { "branch": { "name": "<branch>" } },
                "destination": { "branch": { "name": "<default branch>" } } }
        jq: "{id: id, link: links.html.href}"
```

Print the PR link. If either call fails on authentication, say so and stop --
the Bitbucket MCP server needs credentials, and that is a setup problem the
user has to fix, not something to retry.

### 6. Wait for the auto-review -- poll once a minute, give up after 7

Bitbucket is reachable only through the MCP tools, so **`Monitor` cannot query
it**. Use `Monitor` purely as a heartbeat, and do the checking yourself on each
tick:

```bash
for i in $(seq 1 7); do sleep 60; echo "tick $i"; done
echo "TIMEOUT no review within 7 minutes"
```

Set `timeout_ms` to 480000. On each `tick`, call:

```
bb_get  path: /repositories/<workspace>/<repo>/pullrequests/<id>/comments
        queryParams: { pagelen: "50", sort: "-created_on" }
        jq: "values[*].{user: user.display_name, created: created_on, file: inline.path, line: inline.to, text: content.raw}"
```

Keep the timestamp from when the PR was pushed and ignore anything older, so a
pre-existing thread does not read as a fresh review. As soon as new comments
appear, **stop the monitor** (TaskStop) and move on -- do not wait out the
remaining ticks.

`TIMEOUT` is a normal outcome, not a failure: report that no review arrived,
leave the PR open, and stop. Do not re-arm the monitor.

### 7. Address the review

Only once comments have landed. For each one, decide whether it is actionable:

- **Actionable** -- a real bug, a missed case, a convention violation. Fix it.
- **Not actionable** -- style opinion you disagree with, a misreading of the
  code, something already handled elsewhere. Do not change code to satisfy it.
  Reply on the thread saying why:

```
bb_post path: /repositories/<workspace>/<repo>/pullrequests/<id>/comments
        body: { "content": { "raw": "..." } }
```

Never make a change you cannot justify just to clear a comment. A bot being
confident is not evidence that it is right -- verify each claim against the
actual code before acting on it.

### 8. Commit and push the fixes

Only if step 7 changed something. One commit, message naming what the review
caught. Announce this push too, for the same reason as the first.

### 9. Report

The PR link, what the review raised, what you changed, and what you declined
and why. Be specific about anything you skipped.
