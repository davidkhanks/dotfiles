import { atom, read, update } from 'claude-code'
import type { EngineInterface as Engine, Register } from 'claude-code'

import type { Pending, Ticket } from '../types'

const PANE = 'tickets'
const LINEAR = 'claude.ai Linear'

/** The Linear status names the two actions move a ticket to. */
const START_STATUS = 'In Progress'
const CLAUDE_STATUS = 'Claude'

/** Finished tickets stay off the list. */
const CLOSED_TYPES = new Set(['completed', 'canceled', 'duplicate'])

/** Work in flight first, then what's queued up, then the rest. */
const TYPE_ORDER = ['started', 'unstarted', 'backlog', 'triage']

/**
 * The connector tools this plugin calls, read-only, pre-approved for its own
 * calls; the model's calls to the same tools still go through the mode.
 *
 * Every call is made while /tickets runs. In auto mode a call made from a
 * button press reaches the classifier with no request to judge it against and
 * is refused, whatever this hook or a settings rule says. So the pane loads
 * everything up front, and its buttons change Linear by prompting Claude.
 */
const OWN_TOOLS = new Set(['list_issues', 'get_issue'].map(tool => `mcp__claude_ai_Linear__${tool}`))

/** How many descriptions are fetched at once while the pane loads. */
const DETAIL_CONCURRENCY = 5

const tickets = atom({ plugin: 'tickets', key: 'tickets' } as const, [])
const isLoading = atom({ plugin: 'tickets', key: 'isLoading' } as const, false)
const error = atom({ plugin: 'tickets', key: 'error' } as const, null)
const expanded = atom({ plugin: 'tickets', key: 'expanded' } as const, null)
const descriptions = atom({ plugin: 'tickets', key: 'descriptions' } as const, {})
const pending = atom({ plugin: 'tickets', key: 'pending' } as const, null)
const busy = atom({ plugin: 'tickets', key: 'busy' } as const, null)

function message(err: unknown): string {
  return err instanceof Error ? err.message : String(err)
}

/**
 * Calls a Linear connector tool and parses its JSON answer. The connector
 * reports failures as an error result rather than a rejection, so that is
 * turned into a throw here to keep callers to one failure path.
 */
async function linear($: Engine, tool: string, args: Record<string, unknown>): Promise<any> {
  let result
  try {
    result = await $.mcp.call(LINEAR, tool, args)
  } catch (err) {
    $.ui.log(`tickets: ${tool} failed: ${message(err)}`)
    throw err
  }
  const text = result.content
    .map(block => (block.type === 'text' ? (block as { text: string }).text : ''))
    .join('')
  if (result.isError) {
    $.ui.log(`tickets: ${tool} failed: ${text}`)
    throw new Error(text || `${tool} failed`)
  }
  try {
    return JSON.parse(text)
  } catch {
    // Not JSON: a notice in its place, such as a reply too large to return.
    $.ui.log(`tickets: ${tool} failed: ${text.slice(0, 500)}`)
    throw new Error(text.split('\n')[0] || `${tool} returned nothing`)
  }
}

/** A description as Markdown can draw it: Linear's image markup becomes a note. */
function tidy(raw: string | undefined): string {
  const text = (raw ?? '').replace(/<linear-image>[\s\S]*?(<\/linear-image>|$)/g, '_[image]_').trim()
  return text || '_No description._'
}

function toTicket(raw: any): Ticket {
  return {
    id: raw.id,
    title: raw.title ?? '',
    status: raw.status ?? '',
    statusType: raw.statusType ?? '',
    priority: raw.priority?.name ?? 'No priority',
    team: raw.team ?? '',
    project: raw.project ?? null,
    url: raw.url ?? '',
    gitBranchName: raw.gitBranchName ?? '',
    updatedAt: raw.updatedAt ?? '',
  }
}

function rank(t: Ticket): number {
  const i = TYPE_ORDER.indexOf(t.statusType)
  return i === -1 ? TYPE_ORDER.length : i
}

/** Runs `work` over `items`, at most `limit` at a time. */
async function inPool<T>(items: readonly T[], limit: number, work: (item: T) => Promise<void>) {
  let next = 0
  const runner = async () => {
    while (next < items.length) await work(items[next++]!)
  }
  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, runner))
}

/** Fetches each ticket's full description, so expanding one needs no call. */
async function loadDescriptions($: Engine, list: readonly Ticket[]) {
  await inPool(list, DETAIL_CONCURRENCY, async t => {
    let text: string
    try {
      const issue = await linear($, 'get_issue', { id: t.id, fields: ['id', 'description'] })
      text = tidy(issue?.description)
    } catch (err) {
      text = `_Couldn't load details: ${message(err)}_`
    }
    await update($, descriptions, all => ({ ...all, [t.id]: text }))
  })
}

/** Loads the list, then the descriptions. Called only while /tickets runs. */
async function load($: Engine) {
  await update($, isLoading, () => true)
  await update($, descriptions, () => ({}))
  try {
    const data = await linear($, 'list_issues', {
      assignee: 'me',
      limit: 100,
      orderBy: 'updatedAt',
      // No descriptions here: with them the reply outgrows what a connector may
      // return, and arrives as a "saved to a file" notice instead of the list.
      fields: ['id', 'title', 'status', 'statusType', 'priority', 'team', 'project', 'url', 'gitBranchName', 'updatedAt'],
    })
    const list = ((data?.issues ?? []) as any[])
      .map(toTicket)
      .filter(t => !CLOSED_TYPES.has(t.statusType))
      // Array sort is stable, so updatedAt order holds within each group.
      .sort((a, b) => rank(a) - rank(b))
    await update($, tickets, () => list)
    await update($, error, () => null)
    await loadDescriptions($, list)
  } catch (err) {
    await update($, error, () => message(err))
  } finally {
    await update($, isLoading, () => false)
  }
}

async function toggleExpanded($: Engine, id: string) {
  const open = await read($, expanded)
  await update($, pending, () => null)
  await update($, expanded, () => (open === id ? null : id))
}

/** Hands the ticket to Claude in this session, which moves it in Linear itself. */
async function startWork($: Engine, ticket: Ticket) {
  await prompt(
    $,
    ticket,
    `Let's start work on Linear ticket ${ticket.id}: "${ticket.title}" (${ticket.url}). ` +
      `First move it to the "${START_STATUS}" status with the Linear tools. Then read the ticket and its comments, ` +
      `switch to a new branch \`${ticket.gitBranchName}\` off master, investigate the code, and propose a plan before making changes.`,
  )
}

/** Asks Claude to move the ticket to the Claude column, and nothing more. */
async function sendToClaude($: Engine, ticket: Ticket) {
  await prompt(
    $,
    ticket,
    `Move Linear ticket ${ticket.id} ("${ticket.title}") to the "${CLAUDE_STATUS}" status with the Linear tools, ` +
      `so the Claude bot picks it up. Don't do anything else with it.`,
  )
}

/**
 * Closes the pane and submits `text` as the person's prompt. Claude's own
 * Linear call is judged against that prompt, which a press's call is not.
 */
async function prompt($: Engine, ticket: Ticket, text: string) {
  if ((await read($, busy)) !== null) return
  await update($, pending, () => null)
  await update($, busy, () => ticket.id)
  try {
    await $.ui.close({ id: PANE })
    await $.prompt.submit({ asUser: true, text })
  } catch (err) {
    $.ui.toast(`tickets: ${message(err)}`)
  } finally {
    await update($, busy, () => null)
  }
}

/** Cuts a row label to the pane's width, so each ticket stays one line. */
function fit(text: string, width: number): string {
  return text.length <= width ? text : `${text.slice(0, width - 1)}…`
}

async function openPane($: Engine) {
  await $.ui.open({ id: PANE, title: 'Linear tickets', focus: true, closeOnEscape: true })
  await load($)
}

export const register: Register = on => {
  on('tool.check', ($, e, next) =>
    next.origin.plugin === 'tickets' && OWN_TOOLS.has(e.tool) ? { decision: 'allow' } : next(e),
  )

  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'tickets',
      description: 'Toggle a pane of your assigned Linear tickets',
    })
    return next(e)
  })

  on('command.run', { command: 'tickets' }, async $ => {
    const panes = await $.ui.panes()
    if (panes.some(p => p.id === PANE)) {
      await $.ui.close({ id: PANE })
      return { text: 'Linear tickets pane closed.' }
    }
    await openPane($)
    return { text: 'Linear tickets pane opened.' }
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Button, Markdown, Text } = $.ui.resolve(e)
    const list = await read($, tickets)
    const loading = await read($, isLoading)
    const failure = await read($, error)
    const open = await read($, expanded)
    const docs = await read($, descriptions)
    const waiting: Pending = await read($, pending)
    const working = await read($, busy)
    const width = Math.max(20, (e.props.bodyColumns ?? 80) - 1)

    return (
      <Box flexDirection="column">
        <Box gap={1}>
          <Text bold>
            {list.length === 0 && loading ? 'Loading…' : `${list.length} open ticket${list.length === 1 ? '' : 's'}`}
          </Text>
          <Text dimColor>{loading ? 'loading details…' : 'reopen /tickets to refresh'}</Text>
          <Button key="close" label="Close" role="dismiss" onPress={() => $.ui.close({ id: PANE })} />
        </Box>
        {failure !== null && <Text color="red">{failure}</Text>}
        {list.map(t => {
          const isOpen = open === t.id
          return (
            <Box key={`t-${t.id}`} flexDirection="column">
              <Button
                key={`row-${t.id}`}
                plain
                label={fit(`${isOpen ? '▾' : '▸'} ${t.id}  [${t.status}]  ${t.title}`, width)}
                onPress={() => toggleExpanded($, t.id)}
              />
              {isOpen && (
                <Box flexDirection="column" paddingLeft={2} marginBottom={1}>
                  <Text dimColor>
                    {t.team}
                    {t.project ? ` · ${t.project}` : ''} · {t.priority} · updated {t.updatedAt.slice(0, 10)}
                  </Text>
                  <Markdown key={`md-${t.id}`} text={docs[t.id] ?? '_Loading details…_'} />
                  {working === t.id ? (
                    <Text dimColor>Handing it to Claude…</Text>
                  ) : waiting?.id === t.id ? (
                    <Box gap={1}>
                      <Text bold>
                        {waiting.action === 'start'
                          ? `Move to ${START_STATUS} and start working on it here?`
                          : `Have Claude move it to ${CLAUDE_STATUS} for the Claude bot?`}
                      </Text>
                      <Button
                        key={`yes-${t.id}`}
                        label="Yes"
                        variant="primary"
                        hotkey="y"
                        autoFocus
                        onPress={() => (waiting.action === 'start' ? startWork($, t) : sendToClaude($, t))}
                      />
                      <Button key={`no-${t.id}`} label="Cancel" hotkey="n" onPress={() => update($, pending, () => null)} />
                    </Box>
                  ) : (
                    <Box gap={1}>
                      <Button
                        key={`start-${t.id}`}
                        label="Start working"
                        variant="primary"
                        onPress={() => update($, pending, () => ({ id: t.id, action: 'start' }))}
                      />
                      <Button
                        key={`claude-${t.id}`}
                        label={`Send to ${CLAUDE_STATUS}`}
                        onPress={() => update($, pending, () => ({ id: t.id, action: 'claude' }))}
                      />
                      <Button
                        key={`web-${t.id}`}
                        label="Open in Linear"
                        dimColor
                        onPress={() => $.process.run(['xdg-open', t.url]).catch(() => $.ui.toast(t.url))}
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
