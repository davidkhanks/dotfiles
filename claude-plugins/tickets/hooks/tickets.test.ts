import { expect, test } from 'claude-code/testing'
import type { On } from 'claude-code'

const SURFACES = ['terminal', 'desktop'] as const
const PANE = { component: 'Pane', requestId: 'tickets' } as const

const ISSUES = [
  { id: 'MYE-1', title: 'Queued', status: 'Ready for Work', statusType: 'unstarted', priority: { name: 'High' }, team: 'Snap', url: 'https://linear.app/x/MYE-1', gitBranchName: 'mye-1-queued', updatedAt: '2026-10-08T00:00:00Z' },
  { id: 'MYE-2', title: 'In flight', status: 'Needs Review', statusType: 'started', priority: { name: 'Low' }, team: 'Snap', url: 'https://linear.app/x/MYE-2', gitBranchName: 'mye-2-in-flight', updatedAt: '2026-10-07T00:00:00Z' },
  { id: 'MYE-3', title: 'Finished', status: 'Done', statusType: 'completed', priority: { name: 'Low' }, team: 'Snap', url: '', gitBranchName: '', updatedAt: '' },
]

type Calls = { mcp: { tool: string; args: Record<string, unknown> }[]; prompts: string[] }

/** Stands in for the engine: serves the Linear connector from a fixture. */
function bottom(on: On, listReply?: string): Calls {
  const calls: Calls = { mcp: [], prompts: [] }
  const text = (value: unknown) => ({ value: { content: [{ type: 'text' as const, text: JSON.stringify(value) }], isError: false } })

  on('session.start', () => ({ cwd: '/repo' }))
  on('ui.toast', () => ({ value: undefined }))
  on('ui.open', () => ({ value: { isPlaced: true as const } }))
  on('ui.close', () => ({ value: undefined }))
  on('ui.panes', () => ({ value: [] }))
  on('prompt.submit', (_$, e) => {
    calls.prompts.push(e.text)
    return { text: e.text }
  })
  on('mcp.call', (_$, e) => {
    calls.mcp.push({ tool: e.tool, args: e.args })
    if (e.tool === 'list_issues') {
      if (listReply !== undefined) return { value: { content: [{ type: 'text' as const, text: listReply }], isError: false } }
      return text({ issues: ISSUES })
    }
    if (e.tool === 'get_issue') {
      const description = e.args.id === 'MYE-2' ? 'Start <linear-image>{"src":"x"}</linear-image> and more' : 'The details.'
      return text({ id: e.args.id, description })
    }
    return text({ ok: true })
  })
  return calls
}

async function opened($: any, on: On, surface: (typeof SURFACES)[number], listReply?: string) {
  const calls = bottom(on, listReply)
  await $.session.start({ cwd: '/repo' })
  await $.command.run({ command: 'tickets', args: '' })
  const ui = await $.ui.mount({ plugin: 'tickets', surface, ...PANE, props: {} })
  return { calls, ui }
}

for (const surface of SURFACES) {
  test(`${surface}: lists open tickets, in-flight first, closed ones hidden`, async ($, on) => {
    const { ui } = await opened($, on, surface)
    expect(await ui.find({ key: 'row-MYE-2' })).toBeDefined()
    expect(await ui.find({ key: 'row-MYE-1' })).toBeDefined()
    expect(await ui.find({ key: 'row-MYE-3' })).toBe(undefined)
    expect(await ui.find({ type: 'Text', text: /2 open tickets/ })).toBeDefined()
  })

  test(`${surface}: the whole row, title included, is what a click lands on`, async ($, on) => {
    const { ui } = await opened($, on, surface)
    const row = await ui.find({ key: 'row-MYE-1' })
    expect(row?.text).toContain('Queued')
    expect(row?.text).toContain('Ready for Work')
  })

  test(`${surface}: descriptions load with the pane, for open tickets only`, async ($, on) => {
    const { calls } = await opened($, on, surface)
    const fetched = calls.mcp.filter(c => c.tool === 'get_issue').map(c => c.args.id).sort()
    expect(fetched).toEqual(['MYE-1', 'MYE-2'])
  })

  test(`${surface}: clicking a ticket shows its details with no Linear call of its own`, async ($, on) => {
    const { calls, ui } = await opened($, on, surface)
    const before = calls.mcp.length
    await ui.press({ key: 'row-MYE-1' })
    expect(calls.mcp.length).toBe(before)
    expect(calls.prompts).toEqual([])
    expect(await ui.find({ type: 'Markdown', text: /The details\./ })).toBeDefined()
    expect(await ui.find({ key: 'start-MYE-1' })).toBeDefined()
    expect(await ui.find({ key: 'claude-MYE-1' })).toBeDefined()
  })

  test(`${surface}: images in a description become a note, not raw markup`, async ($, on) => {
    const { ui } = await opened($, on, surface)
    await ui.press({ key: 'row-MYE-2' })
    const md = await ui.find({ key: 'md-MYE-2' })
    expect(md?.text).toContain('_[image]_')
    expect(md?.text).not.toContain('linear-image')
  })

  test(`${surface}: a reply that isn't the list shows as an error, not an empty list`, async ($, on) => {
    const { ui } = await opened($, on, surface, 'Error: result exceeds maximum allowed tokens.')
    expect(await ui.find({ type: 'Text', text: /exceeds maximum allowed tokens/ })).toBeDefined()
  })

  test(`${surface}: Send to Claude asks first, then has Claude move the ticket`, async ($, on) => {
    const { calls, ui } = await opened($, on, surface)
    await ui.press({ key: 'row-MYE-1' })
    await ui.press({ key: 'claude-MYE-1' })
    expect(calls.prompts).toEqual([])

    await ui.press({ key: 'yes-MYE-1' })
    expect(calls.prompts.length).toBe(1)
    expect(calls.prompts[0]).toContain('MYE-1')
    expect(calls.prompts[0]).toContain('"Claude" status')
    expect(calls.mcp.some(c => c.tool === 'save_issue')).toBe(false)
  })

  test(`${surface}: Cancel on Send to Claude leaves the ticket alone`, async ($, on) => {
    const { calls, ui } = await opened($, on, surface)
    await ui.press({ key: 'row-MYE-1' })
    await ui.press({ key: 'claude-MYE-1' })
    await ui.press({ key: 'no-MYE-1' })
    expect(calls.prompts).toEqual([])
    expect(await ui.find({ key: 'claude-MYE-1' })).toBeDefined()
  })

  test(`${surface}: clicking an open row again collapses it`, async ($, on) => {
    const { ui } = await opened($, on, surface)
    await ui.press({ key: 'row-MYE-1' })
    await ui.press({ key: 'row-MYE-1' })
    expect(await ui.find({ key: 'start-MYE-1' })).toBe(undefined)
  })

  test(`${surface}: Start working asks first, then has Claude move it to In Progress and start on it`, async ($, on) => {
    const { calls, ui } = await opened($, on, surface)
    await ui.press({ key: 'row-MYE-1' })
    await ui.press({ key: 'start-MYE-1' })
    expect(calls.prompts).toEqual([])

    await ui.press({ key: 'yes-MYE-1' })
    expect(calls.prompts.length).toBe(1)
    expect(calls.prompts[0]).toContain('MYE-1')
    expect(calls.prompts[0]).toContain('"In Progress" status')
    expect(calls.prompts[0]).toContain('mye-1-queued')
    expect(calls.mcp.some(c => c.tool === 'save_issue')).toBe(false)
  })
}

test("the plugin's Linear pre-approval doesn't extend to anyone else's calls", async ($, on) => {
  on('tool.check', () => ({ decision: 'ask' as const }))
  const { decision } = await $.tool.check({ tool: 'mcp__claude_ai_Linear__get_issue', input: { id: 'MYE-1' } })
  expect(decision).toBe('ask')
})
