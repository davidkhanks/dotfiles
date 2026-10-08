import { atom, read, update } from 'claude-code'
import type { Engine, Register } from 'claude-code'

import type { ShipStatus } from '../types'

const status = atom({ plugin: 'ship', key: 'status' } as const, null)
const hiddenFor = atom({ plugin: 'ship', key: 'hiddenFor' } as const, null)

/** Runs git without letting a non-zero exit or a missing repo throw. */
async function git($: Engine, argv: readonly string[]) {
  try {
    return await $.process.run(['git', ...argv], { timeoutMs: 5000 })
  } catch {
    return { exitCode: 1, stdout: '', stderr: '' }
  }
}

/**
 * What is shippable right now, or null. Null covers every case where the
 * button would be noise: not a repo, a detached HEAD, or a clean branch that
 * is already level with its upstream.
 */
async function readStatus($: Engine): Promise<ShipStatus> {
  if ((await git($, ['rev-parse', '--show-toplevel'])).exitCode !== 0) return null

  const branch = (await git($, ['branch', '--show-current'])).stdout.trim()
  if (!branch) return null

  const dirty = (await git($, ['status', '--porcelain'])).stdout
    .split('\n')
    .filter(line => line.trim() !== '').length

  // `@{u}` exits non-zero when the branch has no upstream, which is itself the
  // signal that nothing has been pushed yet.
  const counted = await git($, ['rev-list', '--count', '@{u}..HEAD'])
  const hasUpstream = counted.exitCode === 0
  const ahead = hasUpstream ? Number(counted.stdout.trim()) || 0 : 0

  if (hasUpstream && dirty === 0 && ahead === 0) return null

  return { branch, dirty, ahead, hasUpstream }
}

/**
 * Runs this plugin's own ship command.
 *
 * Resolved by owner rather than by a guessed spelling: a plugin's command is
 * namespaced (`ship:ship`), and that spelling is the engine's to choose. A
 * failure is spoken aloud -- `$.command.run` rejects an unknown name, and an
 * unhandled rejection in a press handler is silence, which looks exactly like
 * a dead button.
 */
async function runShip($: Engine) {
  try {
    const commands = await $.command.list()
    const own =
      commands.find(c => c.plugin === 'ship') ??
      commands.find(c => c.name === 'ship' || c.name.endsWith(':ship'))

    if (own === undefined) {
      $.ui.toast('ship: no ship command is registered')
      return
    }

    await $.command.run({ command: own.name })
  } catch (error) {
    $.ui.toast(`ship: ${error instanceof Error ? error.message : String(error)}`)
  }
}

function label(s: NonNullable<ShipStatus>): string {
  const parts: string[] = []
  if (s.dirty > 0) parts.push(`${s.dirty} uncommitted`)
  if (s.ahead > 0) parts.push(`${s.ahead} unpushed`)
  if (!s.hasUpstream) parts.push('never pushed')
  return parts.join(', ')
}

/** Re-reads the repo and stores the result for the render hook. */
async function refresh($: Engine) {
  const next = await readStatus($)
  await update($, status, () => next)
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await refresh($)
    return next(e)
  })

  // After every turn, so the band appears as soon as a turn leaves work behind
  // and clears itself once /ship has pushed.
  on('turn.complete', async ($, e, next) => {
    await refresh($)
    return next(e)
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const s = await read($, status)
    if (s === null || e.props.hasSurvey) return next(e)

    const text = label(s)
    if (text === '') return next(e)
    // Dismissal is remembered per label, so new work brings the band back.
    if ((await read($, hiddenFor)) === text) return next(e)

    const { Box, Button, Text } = $.ui.resolve(e)

    return (
      <Box>
        <Text dimColor>
          {s.branch}: {text}{' '}
        </Text>
        <Button
          key="ship"
          label="Ship"
          variant="primary"
          onPress={() => runShip($)}
        />
        <Button
          key="hide"
          label="Hide"
          role="dismiss"
          onPress={() => update($, hiddenFor, () => text)}
        />
      </Box>
    )
  })
}
