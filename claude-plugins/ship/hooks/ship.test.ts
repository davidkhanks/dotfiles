import { expect, test } from 'claude-code/testing'
import type { On } from 'claude-code'

const SURFACES = ['terminal', 'desktop'] as const

const CLEAN = {
  'rev-parse': '/repo\n',
  'branch --show-current': 'main\n',
  'status --porcelain': '',
  'rev-list': '0\n',
}

const DIRTY = {
  ...CLEAN,
  'branch --show-current': 'feat/thing\n',
  'status --porcelain': ' M a.ts\n M b.ts\n',
  'rev-list': '1\n',
}

/**
 * Nothing sits beneath the plugins in a test, so the test stands in for the
 * engine: it answers session.start and serves git from a fixture.
 */
function bottom(on: On, out: Record<string, string>) {
  on('session.start', () => ({ cwd: '/repo' }))
  // The engine namespaces a plugin's command, so the fixture does too.
  on('command.list', () => ({
    value: [
      { name: 'compact', description: 'built in', source: 'builtin' as const },
      { name: 'ship:ship', description: 'ships', source: 'plugin' as const, plugin: 'ship' },
    ],
  }))
  on('ui.toast', () => ({ value: undefined }))
  on('ui.render', () => ({ type: 'Box', props: {}, children: [] }))

  on('process.run', ($, e, next) => {
    const argv = e.argv.join(' ')
    if (!argv.startsWith('git ')) return next(e)
    for (const [match, stdout] of Object.entries(out)) {
      if (argv.includes(match)) return { value: { exitCode: 0, stdout, stderr: '' } }
    }
    return { value: { exitCode: 0, stdout: '', stderr: '' } }
  })
}

for (const surface of SURFACES) {
  test(`${surface}: no band when the branch is clean and level`, async ($, on) => {
    bottom(on, CLEAN)
    await $.session.start({ cwd: '/repo' })

    const drawn = await $.ui.mount({
      plugin: 'ship',
      surface,
      component: 'AbovePrompt',
      props: { hasSurvey: false },
    })

    expect(await drawn.find({ key: 'ship' })).toBe(undefined)
  })

  test(`${surface}: Ship button appears when there is work`, async ($, on) => {
    bottom(on, DIRTY)
    await $.session.start({ cwd: '/repo' })

    const drawn = await $.ui.mount({
      plugin: 'ship',
      surface,
      component: 'AbovePrompt',
      props: { hasSurvey: false },
    })

    expect(await drawn.find({ key: 'ship' })).toBeDefined()
  })

  test(`${surface}: pressing Ship runs this plugin's namespaced command`, async ($, on) => {
    bottom(on, DIRTY)
    const ran: string[] = []
    on('command.run', ($$, e) => {
      ran.push(e.command)
      return { text: '' }
    })
    await $.session.start({ cwd: '/repo' })

    const drawn = await $.ui.mount({
      plugin: 'ship',
      surface,
      component: 'AbovePrompt',
      props: { hasSurvey: false },
    })
    await drawn.press({ key: 'ship' })

    expect(ran).toEqual(['ship:ship'])
  })
}
