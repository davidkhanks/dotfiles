---
description: Commit, push, open a PR, wait for the auto-review, then address it
allowed-tools: Bash(git:*), Bash(gh:*), Monitor, Read, Edit, Write, Grep, Glob
---

## Context

- Branch: !`git branch --show-current`
- Default branch: !`git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|origin/||' || echo main`
- Status: !`git status --short`
- Change summary: !`git diff HEAD --stat`
- Existing PR for this branch: !`gh pr view --json number,url,state 2>/dev/null || echo "none"`

## Your task

Ship the current work end to end. Do not ask for confirmation between steps --
the point of this command is that it runs unattended. Do stop and report if a
step fails.

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

### 4. Open the PR

If the Context above shows an existing open PR, reuse it -- do not open a
second. Otherwise `gh pr create` with a title and a body drawn from the commits.
Print the URL.

### 5. Wait for the auto-review -- poll once a minute, give up after 7

Use the **Monitor** tool, not a foreground sleep loop. Poll for new review
comments and exit as soon as any land, so the wait ends early on success:

```bash
PR=<number>; REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
SINCE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
for i in $(seq 1 7); do
  sleep 60
  FOUND=$(
    { gh api "repos/$REPO/pulls/$PR/comments?since=$SINCE" \
        --jq '.[] | "COMMENT \(.user.login) \(.path):\(.line // .original_line): \(.body)"' 2>/dev/null || true
      gh api "repos/$REPO/pulls/$PR/reviews" \
        --jq --arg s "$SINCE" '.[] | select(.submitted_at > $s) | "REVIEW \(.user.login) \(.state): \(.body)"' 2>/dev/null || true
    } | grep -v '^$' || true
  )
  if [ -n "$FOUND" ]; then printf '%s\n' "$FOUND"; echo "REVIEW-LANDED"; exit 0; fi
done
echo "TIMEOUT no review within 7 minutes"
```

Set `timeout_ms` to 480000 (8 minutes -- one minute of headroom over the poll
budget). Treat `TIMEOUT` as a normal outcome, not a failure: report that no
review arrived, leave the PR open, and stop. Do not re-arm the monitor.

### 6. Address the review

Only once comments have landed. For each one, decide whether it is actionable:

- **Actionable** -- a real bug, a missed case, a convention violation. Fix it.
- **Not actionable** -- style opinion you disagree with, a misreading of the
  code, something already handled elsewhere. Do not change code to satisfy it.
  Reply on the thread saying why, with `gh pr comment` or the review reply API.

Never make a change you cannot justify just to clear a comment. A bot being
confident is not evidence that it is right -- verify each claim against the
actual code before acting on it.

### 7. Commit and push the fixes

Only if step 6 changed something. One commit, message naming what the review
caught. Announce this push too, for the same reason as the first.

### 8. Report

The PR URL, what the review raised, what you changed, and what you declined and
why. Be specific about anything you skipped.
