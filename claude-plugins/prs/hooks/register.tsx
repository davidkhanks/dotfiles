import { atom, read, update } from 'claude-code'
import type { EngineInterface as Engine, Register } from 'claude-code'

import type { Action, Filter, Pending, PullRequest, Repo } from '../types'

const PANE = 'prs'
const BITBUCKET = 'bitbucket'

/** How many merged pull requests the Merged filter shows, newest first. */
const MERGED_LIMIT = 20
/** How many open pull requests, drafts included, the list loads. */
const OPEN_LIMIT = 50
/** How many descriptions are fetched at once while the pane loads. */
const DETAIL_CONCURRENCY = 5

/**
 * The connector tool this plugin calls, read-only, pre-approved for its own
 * calls; the model's calls to it still go through the mode.
 *
 * Every call is made while /prs runs. In auto mode a call made from a button
 * press reaches the classifier with no request to judge it against and is
 * refused, whatever this hook or a settings rule says. So the pane loads every
 * filter and description up front, and its buttons work by prompting Claude.
 */
const OWN_TOOLS = new Set(['mcp__bitbucket__bb_get'])

const FILTERS: readonly { key: Filter; label: string }[] = [
  { key: 'open', label: 'Open' },
  { key: 'draft', label: 'Draft' },
  { key: 'merged', label: 'Merged' },
]

const repo = atom({ plugin: 'prs', key: 'repo' } as const, null)
const prs = atom({ plugin: 'prs', key: 'prs' } as const, [])
const isLoading = atom({ plugin: 'prs', key: 'isLoading' } as const, false)
const error = atom({ plugin: 'prs', key: 'error' } as const, null)
const filter = atom({ plugin: 'prs', key: 'filter' } as const, 'open')
const expanded = atom({ plugin: 'prs', key: 'expanded' } as const, null)
const descriptions = atom({ plugin: 'prs', key: 'descriptions' } as const, {})
const pending = atom({ plugin: 'prs', key: 'pending' } as const, null)
const busy = atom({ plugin: 'prs', key: 'busy' } as const, null)
const approvalsSent = atom({ plugin: 'prs', key: 'approvalsSent' } as const, [])

/** What each confirmed action asks before it goes ahead. */
const CONFIRM: Partial<Record<Action, string>> = {
  address: 'Check it out, address its open comments, then commit, push and resolve them?',
  squash: 'Squash merge it and close the source branch?',
  merge: 'Merge it with a merge commit and close the source branch?',
}

function message(err: unknown): string {
  return err instanceof Error ? err.message : String(err)
}

/** Reads `owner/name` and the host off a remote URL, ssh or https. */
function parseRemote(url: string): Repo | null {
  const match = url.trim().match(/(bitbucket\.org|github\.com)[:/]([^/]+)\/([^/]+?)(?:\.git)?\/?$/)
  if (!match) return null
  return { host: match[1] === 'github.com' ? 'github' : 'bitbucket', owner: match[2]!, name: match[3]! }
}

async function run($: Engine, argv: readonly string[], cwd: string) {
  const result = await $.process.run(argv, { cwd, timeoutMs: 30000 })
  if (result.exitCode !== 0) throw new Error(result.stderr.trim() || `${argv[0]} exited ${result.exitCode}`)
  return result.stdout
}

/**
 * Calls the Bitbucket connector's read tool and parses its JSON answer. A
 * reply that is not JSON is a notice in its place (an auth failure, a reply
 * too large to return), so it is thrown rather than read as an empty list.
 */
async function bitbucket($: Engine, path: string, queryParams: Record<string, string>): Promise<any> {
  const result = await $.mcp.call(BITBUCKET, 'bb_get', { path, queryParams, outputFormat: 'json' })
  const text = result.content
    .map(block => (block.type === 'text' ? (block as { text: string }).text : ''))
    .join('')
  if (result.isError) throw new Error(text || 'bb_get failed')
  try {
    return JSON.parse(text)
  } catch {
    $.ui.log(`prs: bb_get ${path} failed: ${text.slice(0, 500)}`)
    throw new Error(text.split('\n')[0] || 'bb_get returned nothing')
  }
}

const BB_FIELDS = [
  'id', 'title', 'draft', 'state', 'author.display_name', 'source.branch.name', 'updated_on', 'links.html.href',
  'participants.approved', 'participants.user.account_id',
].map(field => `values.${field}`).join(',')

function fromBitbucket(raw: any, me: string): PullRequest {
  return {
    approvedByMe: (raw.participants ?? []).some((p: any) => p.approved && p.user?.account_id === me),
    number: raw.id,
    title: raw.title ?? '',
    author: raw.author?.display_name ?? '',
    state: raw.state === 'MERGED' ? 'merged' : raw.draft ? 'draft' : 'open',
    branch: raw.source?.branch?.name ?? '',
    url: raw.links?.html?.href ?? '',
    updatedAt: raw.updated_on ?? '',
  }
}

/** Runs `work` over `items`, at most `limit` at a time. */
async function inPool<T>(items: readonly T[], limit: number, work: (item: T) => Promise<void>) {
  let next = 0
  const runner = async () => {
    while (next < items.length) await work(items[next++]!)
  }
  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, runner))
}

function describe(body: string | null | undefined): string {
  return body?.trim() || '_No description._'
}

async function loadBitbucket($: Engine, r: Repo) {
  const base = `/repositories/${r.owner}/${r.name}/pullrequests`
  const [me, open, merged] = await Promise.all([
    bitbucket($, '/user', { fields: 'account_id' }),
    bitbucket($, base, { state: 'OPEN', sort: '-updated_on', pagelen: String(OPEN_LIMIT), fields: BB_FIELDS }),
    bitbucket($, base, { state: 'MERGED', sort: '-updated_on', pagelen: String(MERGED_LIMIT), fields: BB_FIELDS }),
  ])
  const list = [...(open?.values ?? []), ...(merged?.values ?? [])].map(raw => fromBitbucket(raw, me?.account_id ?? ''))
  await update($, prs, () => list)

  // The list endpoint's descriptions would push the reply past what a
  // connector may return, so each one is fetched on its own.
  await inPool(list, DETAIL_CONCURRENCY, async pr => {
    let text: string
    try {
      const detail = await bitbucket($, `${base}/${pr.number}`, { fields: 'description' })
      text = describe(detail?.description)
    } catch (err) {
      text = `_Couldn't load the description: ${message(err)}_`
    }
    await update($, descriptions, all => ({ ...all, [pr.number]: text }))
  })
}

async function loadGithub($: Engine, r: Repo, cwd: string) {
  const fields = 'number,title,author,isDraft,state,headRefName,url,updatedAt,body,latestReviews'
  const me = (await run($, ['gh', 'api', 'user', '--jq', '.login'], cwd)).trim()
  const list = async (state: string, limit: number) =>
    JSON.parse(
      await run($, ['gh', 'pr', 'list', '-R', `${r.owner}/${r.name}`, '--state', state, '--limit', String(limit), '--json', fields], cwd),
    ) as any[]
  const raw = [...(await list('open', OPEN_LIMIT)), ...(await list('merged', MERGED_LIMIT))]
  const docs: Record<string, string> = {}
  for (const pr of raw) docs[pr.number] = describe(pr.body)
  await update($, descriptions, () => docs)
  await update($, prs, () =>
    raw.map(pr => ({
      number: pr.number,
      title: pr.title ?? '',
      author: pr.author?.name || pr.author?.login || '',
      state: pr.state === 'MERGED' ? 'merged' : pr.isDraft ? 'draft' : 'open',
      branch: pr.headRefName ?? '',
      url: pr.url ?? '',
      updatedAt: pr.updatedAt ?? '',
      approvedByMe: (pr.latestReviews ?? []).some((review: any) => review.state === 'APPROVED' && review.author?.login === me),
    })),
  )
}

/** Finds the repo and loads every filter's pull requests. Called only while /prs runs. */
async function load($: Engine) {
  await update($, isLoading, () => true)
  await update($, error, () => null)
  await update($, prs, () => [])
  await update($, descriptions, () => ({}))
  await update($, expanded, () => null)
  await update($, pending, () => null)
  await update($, approvalsSent, () => [])
  try {
    const cwd = await $.session.cwd()
    const found = parseRemote(await run($, ['git', 'remote', 'get-url', 'origin'], cwd))
    await update($, repo, () => found)
    if (found === null) throw new Error("This repo's origin is neither Bitbucket nor GitHub.")
    if (found.host === 'bitbucket') await loadBitbucket($, found)
    else await loadGithub($, found, cwd)
  } catch (err) {
    await update($, error, () => message(err))
  } finally {
    await update($, isLoading, () => false)
  }
}

async function toggleExpanded($: Engine, number: number) {
  const open = await read($, expanded)
  await update($, pending, () => null)
  await update($, expanded, () => (open === number ? null : number))
}

async function setFilter($: Engine, next: Filter) {
  await update($, filter, () => next)
  await update($, expanded, () => null)
  await update($, pending, () => null)
}

/** What Claude is told to do for each pull request action. */
function promptFor(r: Repo, pr: PullRequest, action: Action): string {
  const isBitbucket = r.host === 'bitbucket'
  const where = isBitbucket ? 'Bitbucket' : 'GitHub'
  const api = `/repositories/${r.owner}/${r.name}/pullrequests/${pr.number}`
  const intro = `${where} PR #${pr.number} "${pr.title}" (${pr.url}), branch \`${pr.branch}\``
  const clean =
    `If the working tree has uncommitted changes, stop and ask me first. ` +
    `Otherwise fetch and check out the branch, and pull it up to date.`

  switch (action) {
    case 'checkout':
      return `Check out ${intro} locally. ${clean} Then stop.`

    case 'approve':
      return isBitbucket
        ? `Approve ${intro} with the Bitbucket MCP tools: POST \`${api}/approve\` with body \`{}\`. Don't do anything else.`
        : `Approve ${intro}: \`gh pr review ${pr.number} -R ${r.owner}/${r.name} --approve\`. Don't do anything else.`

    case 'squash':
    case 'merge': {
      const how = action === 'squash' ? 'a squash merge' : 'a merge commit'
      const call = isBitbucket
        ? `with the Bitbucket MCP tools: POST \`${api}/merge\` with body ` +
          `\`{"merge_strategy": "${action === 'squash' ? 'squash' : 'merge_commit'}", "close_source_branch": true}\``
        : `\`gh pr merge ${pr.number} -R ${r.owner}/${r.name} --${action === 'squash' ? 'squash' : 'merge'} --delete-branch\``
      return (
        `Merge ${intro} using ${how} and close the source branch, ${call}. ` +
        `If the merge is refused (failed merge checks, missing approvals, conflicts), tell me why and stop; ` +
        `don't change the PR or its settings to get it through.`
      )
    }

    case 'address': {
      const comments = isBitbucket
        ? `Use the Bitbucket MCP tools (\`${api}/comments\`) to find every unresolved comment thread. ` +
          `Reply to a comment with \`parent: {id}\` and resolve its thread with POST \`.../comments/{id}/resolve\` and body \`{}\`.`
        : `Use \`gh\` to find every unresolved review thread (\`gh api graphql\` with \`reviewThreads\` and \`isResolved\`). ` +
          `Reply in the thread and resolve it with the \`resolveReviewThread\` mutation.`
      return (
        `Address the open review comments on ${intro}. ${clean} ${comments} ` +
        `For each unresolved comment, make the change it calls for, or reply explaining why not; ` +
        `run the tests for what you change. Commit and push the changes, then reply to each comment saying what was done and resolve its thread. ` +
        `If there are no unresolved comments, say so and stop. ` +
        `The review bot has already commented on this PR, so don't wait for a new review.`
      )
    }
  }
}

/**
 * Submits the action's prompt as the person's own. Claude's own git and
 * connector calls are judged against that prompt, which a press's call is not.
 *
 * Approve keeps the pane open and marks the approval as sent, so the merge
 * buttons show at once; every other action closes the pane.
 */
async function handOff($: Engine, pr: PullRequest, action: Action) {
  if ((await read($, busy)) !== null) return
  const r = await read($, repo)
  if (r === null) return
  await update($, pending, () => null)
  await update($, busy, () => pr.number)
  try {
    if (action === 'approve') await update($, approvalsSent, sent => [...sent, pr.number])
    else await $.ui.close({ id: PANE })
    await $.prompt.submit({ asUser: true, text: promptFor(r, pr, action) })
  } catch (err) {
    $.ui.toast(`prs: ${message(err)}`)
  } finally {
    await update($, busy, () => null)
  }
}

/** Cuts a row label to the pane's width, so each pull request stays one line. */
function fit(text: string, width: number): string {
  return text.length <= width ? text : `${text.slice(0, width - 1)}…`
}

export const register: Register = on => {
  on('tool.check', ($, e, next) =>
    next.origin.plugin === 'prs' && OWN_TOOLS.has(e.tool) ? { decision: 'allow' } : next(e),
  )

  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'prs',
      description: "Toggle a pane of this repo's pull requests on Bitbucket or GitHub",
    })
    return next(e)
  })

  on('command.run', { command: 'prs' }, async $ => {
    const panes = await $.ui.panes()
    if (panes.some(p => p.id === PANE)) {
      await $.ui.close({ id: PANE })
      return { text: 'Pull requests pane closed.' }
    }
    await $.ui.open({ id: PANE, title: 'Pull requests', focus: true, closeOnEscape: true })
    await load($)
    return { text: 'Pull requests pane opened.' }
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Button, Markdown, Text } = $.ui.resolve(e)
    const r = await read($, repo)
    const all = await read($, prs)
    const loading = await read($, isLoading)
    const failure = await read($, error)
    const current = await read($, filter)
    const open = await read($, expanded)
    const docs = await read($, descriptions)
    const waiting: Pending = await read($, pending)
    const working = await read($, busy)
    const sent = await read($, approvalsSent)
    const width = Math.max(20, (e.props.bodyColumns ?? 80) - 1)
    const shown = all.filter(pr => pr.state === current)

    return (
      <Box flexDirection="column">
        <Box gap={1}>
          <Text bold>{r ? `${r.owner}/${r.name}` : 'Pull requests'}</Text>
          {FILTERS.map(f => (
            <Button
              key={`filter-${f.key}`}
              label={`${f.label} (${all.filter(pr => pr.state === f.key).length})`}
              variant={f.key === current ? 'primary' : undefined}
              dimColor={f.key !== current}
              onPress={() => setFilter($, f.key)}
            />
          ))}
          <Button key="close" label="Close" role="dismiss" onPress={() => $.ui.close({ id: PANE })} />
        </Box>
        <Text dimColor>{loading ? 'Loading…' : 'Reopen /prs to refresh'}</Text>
        {failure !== null && <Text color="red">{failure}</Text>}
        {!loading && failure === null && shown.length === 0 && <Text dimColor>No {current} pull requests.</Text>}
        {shown.map(pr => {
          const isOpen = open === pr.number
          return (
            <Box key={`pr-${pr.number}`} flexDirection="column">
              <Button
                key={`row-${pr.number}`}
                plain
                label={fit(`${isOpen ? '▾' : '▸'} #${pr.number}  ${pr.author}  ${pr.title}`, width)}
                onPress={() => toggleExpanded($, pr.number)}
              />
              {isOpen && (
                <Box flexDirection="column" paddingLeft={2} marginBottom={1}>
                  <Text dimColor>
                    {pr.branch} · updated {pr.updatedAt.slice(0, 10)}
                  </Text>
                  <Markdown key={`md-${pr.number}`} text={docs[pr.number] ?? '_Loading the description…_'} />
                  {pr.approvedByMe ? (
                    <Text color="green">✓ You approved this</Text>
                  ) : sent.includes(pr.number) ? (
                    <Text dimColor>Approval sent to Claude</Text>
                  ) : null}
                  {working === pr.number ? (
                    <Text dimColor>Handing it to Claude…</Text>
                  ) : waiting?.number === pr.number ? (
                    <Box gap={1}>
                      <Text bold>{CONFIRM[waiting.action]}</Text>
                      <Button
                        key={`yes-${pr.number}`}
                        label="Yes"
                        variant="primary"
                        hotkey="y"
                        autoFocus
                        onPress={() => handOff($, pr, waiting.action)}
                      />
                      <Button key={`no-${pr.number}`} label="Cancel" hotkey="n" onPress={() => update($, pending, () => null)} />
                    </Box>
                  ) : (
                    <Box gap={1} flexWrap="wrap">
                      {pr.state !== 'merged' && (
                        <Button
                          key={`address-${pr.number}`}
                          label="Address comments"
                          variant="primary"
                          onPress={() => update($, pending, () => ({ number: pr.number, action: 'address' }))}
                        />
                      )}
                      {pr.state !== 'merged' && (
                        <Button key={`checkout-${pr.number}`} label="Check out" onPress={() => handOff($, pr, 'checkout')} />
                      )}
                      {pr.state === 'open' && !pr.approvedByMe && !sent.includes(pr.number) && (
                        <Button key={`approve-${pr.number}`} label="Approve" onPress={() => handOff($, pr, 'approve')} />
                      )}
                      {pr.state === 'open' && (pr.approvedByMe || sent.includes(pr.number)) && (
                        <Button
                          key={`squash-${pr.number}`}
                          label="Squash"
                          onPress={() => update($, pending, () => ({ number: pr.number, action: 'squash' }))}
                        />
                      )}
                      {pr.state === 'open' && (pr.approvedByMe || sent.includes(pr.number)) && (
                        <Button
                          key={`merge-${pr.number}`}
                          label="Merge"
                          onPress={() => update($, pending, () => ({ number: pr.number, action: 'merge' }))}
                        />
                      )}
                      <Button
                        key={`web-${pr.number}`}
                        label="Open in browser"
                        dimColor
                        onPress={() => $.process.run(['xdg-open', pr.url]).catch(() => $.ui.toast(pr.url))}
                      />
                    </Box>
                  )}
                </Box>
              )}
            </Box>
          )
        })}
      </Box>
    )
  })
}
