import { expect, test } from 'claude-code/testing'
import type { On } from 'claude-code'

const SURFACES = ['terminal', 'desktop'] as const
const PANE = { component: 'Pane', requestId: 'prs' } as const

const BB_OPEN = [
  { id: 11, title: 'Ready one', draft: false, state: 'OPEN', author: { display_name: 'Ada' }, source: { branch: { name: 'ready-one' } }, updated_on: '2026-10-09T00:00:00Z', links: { html: { href: 'https://bitbucket.org/acme/app/pull-requests/11' } } },
  { id: 13, title: 'Already approved', draft: false, state: 'OPEN', author: { display_name: 'Di' }, source: { branch: { name: 'approved' } }, updated_on: '2026-10-09T00:00:00Z', links: { html: { href: 'https://bitbucket.org/acme/app/pull-requests/13' } }, participants: [{ approved: true, user: { account_id: 'me-id' } }, { approved: false, user: { account_id: 'other' } }] },
  { id: 12, title: 'Work in progress', draft: true, state: 'OPEN', author: { display_name: 'Bo' }, source: { branch: { name: 'wip' } }, updated_on: '2026-10-08T00:00:00Z', links: { html: { href: 'https://bitbucket.org/acme/app/pull-requests/12' } } },
]
const BB_MERGED = [
  { id: 9, title: 'Shipped', draft: false, state: 'MERGED', author: { display_name: 'Cy' }, source: { branch: { name: 'shipped' } }, updated_on: '2026-10-01T00:00:00Z', links: { html: { href: 'https://bitbucket.org/acme/app/pull-requests/9' } } },
]
const GH = [
  { number: 5, title: 'GitHub change', author: { login: 'dee', name: 'Dee' }, isDraft: false, state: 'OPEN', headRefName: 'gh-change', url: 'https://github.com/acme/app/pull/5', updatedAt: '2026-10-09T00:00:00Z', body: 'GitHub body.', latestReviews: [{ author: { login: 'me' }, state: 'APPROVED' }] },
]

type Calls = { mcp: { tool: string; args: any }[]; argv: string[][]; prompts: string[]; closes: number }

/** Stands in for the engine: a repo with the given remote, and both hosts' APIs. */
function bottom(on: On, remote: string): Calls {
  const calls: Calls = { mcp: [], argv: [], prompts: [], closes: 0 }
  const json = (value: unknown) => ({ value: { content: [{ type: 'text' as const, text: JSON.stringify(value) }], isError: false } })

  on('session.start', () => ({ cwd: '/repo' }))
  on('session.cwd', () => ({ value: '/repo' }))
  on('ui.toast', () => ({ value: undefined }))
  on('ui.open', () => ({ value: { isPlaced: true as const } }))
  on('ui.close', () => {
    calls.closes++
    return { value: undefined }
  })
  on('ui.panes', () => ({ value: [] }))
  on('prompt.submit', (_$, e) => {
    calls.prompts.push(e.text)
    return { text: e.text }
  })
  on('process.run', (_$, e) => {
    calls.argv.push([...e.argv])
    const ok = (stdout: string) => ({ value: { exitCode: 0, stdout, stderr: '' } })
    if (e.argv[0] === 'git') return ok(`${remote}\n`)
    if (e.argv[0] === 'gh' && e.argv[1] === 'api') return ok('me\n')
    if (e.argv[0] === 'gh') return ok(JSON.stringify(e.argv.includes('merged') ? [] : GH))
    return ok('')
  })
  on('mcp.call', (_$, e) => {
    calls.mcp.push({ tool: e.tool, args: e.args })
    const { path, queryParams } = e.args as any
    if (path === '/user') return json({ account_id: 'me-id' })
    if (path.endsWith('/pullrequests')) return json({ values: queryParams.state === 'MERGED' ? BB_MERGED : BB_OPEN })
    const id = path.split('/').pop()
    return json({ description: `Description of ${id}.` })
  })
  return calls
}

async function opened($: any, on: On, surface: (typeof SURFACES)[number], remote = 'git@bitbucket.org:acme/app.git') {
  const calls = bottom(on, remote)
  await $.session.start({ cwd: '/repo' })
  await $.command.run({ command: 'prs', args: '' })
  const ui = await $.ui.mount({ plugin: 'prs', surface, ...PANE, props: {} })
  return { calls, ui }
}

for (const surface of SURFACES) {
  test(`${surface}: Bitbucket open PRs show by default, with their author`, async ($, on) => {
    const { ui } = await opened($, on, surface)
    const row = await ui.find({ key: 'row-11' })
    expect(row?.text).toContain('Ada')
    expect(row?.text).toContain('Ready one')
    expect(await ui.find({ key: 'row-12' })).toBe(undefined)
    expect(await ui.find({ key: 'row-9' })).toBe(undefined)
  })

  test(`${surface}: the filters switch between open, draft and merged, with counts`, async ($, on) => {
    const { calls, ui } = await opened($, on, surface)
    expect((await ui.find({ key: 'filter-draft' }))?.text).toContain('(1)')
    const before = calls.mcp.length

    await ui.press({ key: 'filter-draft' })
    expect(await ui.find({ key: 'row-12' })).toBeDefined()
    expect(await ui.find({ key: 'row-11' })).toBe(undefined)

    await ui.press({ key: 'filter-merged' })
    expect(await ui.find({ key: 'row-9' })).toBeDefined()
    expect(calls.mcp.length).toBe(before)
  })

  test(`${surface}: descriptions load with the pane, and a click shows one with no call of its own`, async ($, on) => {
    const { calls, ui } = await opened($, on, surface)
    const before = calls.mcp.length
    await ui.press({ key: 'row-11' })
    expect(calls.mcp.length).toBe(before)
    expect((await ui.find({ key: 'md-11' }))?.text).toContain('Description of 11.')
    expect(await ui.find({ key: 'address-11' })).toBeDefined()
  })

  test(`${surface}: Address comments asks first, then prompts Claude without waiting for a review`, async ($, on) => {
    const { calls, ui } = await opened($, on, surface)
    await ui.press({ key: 'row-11' })
    await ui.press({ key: 'address-11' })
    expect(calls.prompts).toEqual([])

    await ui.press({ key: 'yes-11' })
    expect(calls.prompts.length).toBe(1)
    const prompt = calls.prompts[0]!
    expect(prompt).toContain('PR #11')
    expect(prompt).toContain('ready-one')
    expect(prompt).toContain('/repositories/acme/app/pullrequests/11/comments')
    expect(prompt).toContain("don't wait for a new review")
  })

  test(`${surface}: Cancel leaves the PR alone`, async ($, on) => {
    const { calls, ui } = await opened($, on, surface)
    await ui.press({ key: 'row-11' })
    await ui.press({ key: 'address-11' })
    await ui.press({ key: 'no-11' })
    expect(calls.prompts).toEqual([])
    expect(await ui.find({ key: 'address-11' })).toBeDefined()
  })

  test(`${surface}: Check out prompts Claude to check out the branch and stop`, async ($, on) => {
    const { calls, ui } = await opened($, on, surface)
    await ui.press({ key: 'row-11' })
    await ui.press({ key: 'checkout-11' })
    expect(calls.prompts.length).toBe(1)
    expect(calls.prompts[0]).toContain('ready-one')
    expect(calls.prompts[0]).toContain('Then stop.')
  })

  test(`${surface}: a merged PR offers no actions that change it`, async ($, on) => {
    const { ui } = await opened($, on, surface)
    await ui.press({ key: 'filter-merged' })
    await ui.press({ key: 'row-9' })
    expect(await ui.find({ key: 'address-9' })).toBe(undefined)
    expect(await ui.find({ key: 'web-9' })).toBeDefined()
  })

  test(`${surface}: a GitHub remote reads its PRs through gh`, async ($, on) => {
    const { calls, ui } = await opened($, on, surface, 'https://github.com/acme/app.git')
    expect(calls.mcp).toEqual([])
    expect(calls.argv.some(a => a[0] === 'gh' && a.includes('acme/app'))).toBe(true)
    const row = await ui.find({ key: 'row-5' })
    expect(row?.text).toContain('Dee')
    await ui.press({ key: 'row-5' })
    expect((await ui.find({ key: 'md-5' }))?.text).toContain('GitHub body.')
    await ui.press({ key: 'address-5' })
    await ui.press({ key: 'yes-5' })
    expect(calls.prompts[0]).toContain('resolveReviewThread')
  })

  test(`${surface}: on GitHub, your approving review shows and Squash uses gh with --delete-branch`, async ($, on) => {
    const { calls, ui } = await opened($, on, surface, 'git@github.com:acme/app.git')
    await ui.press({ key: 'row-5' })
    expect(await ui.find({ type: 'Text', text: /You approved this/ })).toBeDefined()
    await ui.press({ key: 'squash-5' })
    await ui.press({ key: 'yes-5' })
    expect(calls.prompts[0]).toContain('gh pr merge 5 -R acme/app --squash --delete-branch')
  })

  test(`${surface}: Approve hands Claude the approval, keeps the pane open and shows the merge buttons`, async ($, on) => {
    const { calls, ui } = await opened($, on, surface)
    await ui.press({ key: 'row-11' })
    expect(await ui.find({ key: 'squash-11' })).toBe(undefined)
    expect(await ui.find({ key: 'merge-11' })).toBe(undefined)

    await ui.press({ key: 'approve-11' })
    expect(calls.prompts.length).toBe(1)
    expect(calls.prompts[0]).toContain('POST `/repositories/acme/app/pullrequests/11/approve`')
    expect(calls.closes).toBe(0)
    expect(await ui.find({ type: 'Text', text: /Approval sent to Claude/ })).toBeDefined()
    expect(await ui.find({ key: 'approve-11' })).toBe(undefined)
    expect(await ui.find({ key: 'squash-11' })).toBeDefined()
    expect(await ui.find({ key: 'merge-11' })).toBeDefined()
  })

  test(`${surface}: a PR you already approved shows so, with Squash and Merge and no Approve`, async ($, on) => {
    const { ui } = await opened($, on, surface)
    await ui.press({ key: 'row-13' })
    expect(await ui.find({ type: 'Text', text: /You approved this/ })).toBeDefined()
    expect(await ui.find({ key: 'approve-13' })).toBe(undefined)
    expect(await ui.find({ key: 'squash-13' })).toBeDefined()
  })

  test(`${surface}: Squash asks first, then has Claude squash merge and close the branch`, async ($, on) => {
    const { calls, ui } = await opened($, on, surface)
    await ui.press({ key: 'row-13' })
    await ui.press({ key: 'squash-13' })
    expect(calls.prompts).toEqual([])
    await ui.press({ key: 'yes-13' })
    expect(calls.prompts[0]).toContain('"merge_strategy": "squash", "close_source_branch": true')
    expect(calls.prompts[0]).toContain('/pullrequests/13/merge')
    expect(calls.closes).toBe(1)
  })

  test(`${surface}: Merge asks first, then has Claude merge with a merge commit and close the branch`, async ($, on) => {
    const { calls, ui } = await opened($, on, surface)
    await ui.press({ key: 'row-13' })
    await ui.press({ key: 'merge-13' })
    await ui.press({ key: 'no-13' })
    expect(calls.prompts).toEqual([])
    await ui.press({ key: 'merge-13' })
    await ui.press({ key: 'yes-13' })
    expect(calls.prompts[0]).toContain('"merge_strategy": "merge_commit", "close_source_branch": true')
  })

  test(`${surface}: a draft PR offers neither Approve nor the merge buttons`, async ($, on) => {
    const { ui } = await opened($, on, surface)
    await ui.press({ key: 'filter-draft' })
    await ui.press({ key: 'row-12' })
    expect(await ui.find({ key: 'approve-12' })).toBe(undefined)
    expect(await ui.find({ key: 'squash-12' })).toBe(undefined)
    expect(await ui.find({ key: 'address-12' })).toBeDefined()
  })

  test(`${surface}: a remote on neither host says so`, async ($, on) => {
    const { ui } = await opened($, on, surface, 'git@gitlab.com:acme/app.git')
    expect(await ui.find({ type: 'Text', text: /neither Bitbucket nor GitHub/ })).toBeDefined()
  })
}

test("the plugin's Bitbucket pre-approval doesn't extend to anyone else's calls", async ($, on) => {
  on('tool.check', () => ({ decision: 'ask' as const }))
  const { decision } = await $.tool.check({ tool: 'mcp__bitbucket__bb_get', input: { path: '/x' } })
  expect(decision).toBe('ask')
})
