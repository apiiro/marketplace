import { expect, mock, test } from 'claude-code/testing'

const BAND = {
  plugin: 'guardian-enrichment',
  component: 'AbovePrompt',
  props: {
    hasSurvey: false,
    isWorking: false,
    maxRows: 20,
    bodyColumns: 80,
    scroll: { offset: 0, bodyRows: 19 },
    view: {},
  },
} as const


const LOG_PATH = '/home/me/.apiiro/prevent-log/s1.jsonl'
const ENRICHMENT =
  'Security Requirements:\nAuthentication: Authenticate callers.\n\nData Storage: Use parameterized queries.\n\nIMPLEMENTATION GUIDELINES - Follow these principles:\nOrganization guidelines: scan packages'

function line(ts: string, enrichment: string, prompt = 'add login') {
  return JSON.stringify({ ts, session_id: 's1', prompt, enrichment })
}

type On = Parameters<Parameters<typeof test>[1]>[1]

type Gate = { reached: () => void; release: Promise<void> }
type EngineOptions = { env?: Record<string, string>; size?: number; session?: { id: string }; gate?: Gate }

function engine(on: On, files: Record<string, string>, options: EngineOptions = {}) {
  const env = options.env ?? { HOME: '/home/me' }
  const seen = { toasts: [] as string[], opened: [] as unknown[], status: [] as (string | undefined)[] }
  on('env.get', (_, e) => ({ value: env[e.name] }))
  const session = options.session ?? { id: 's1' }
  on('session.id', () => ({ value: session.id }))
  let gate = options.gate
  on('fs.stat', async (_, e) => {
    const text = files[e.path]
    if (gate) {
      const held = gate
      gate = undefined
      held.reached()
      await held.release
    }
    if (text === undefined) throw new Error('ENOENT')
    return { value: { kind: 'file', size: options.size ?? text.length, mtimeMs: text.length, isLink: false } }
  })
  on('fs.read', (_, e) => {
    const text = files[e.path]
    if (text === undefined) throw new Error('ENOENT')
    return { value: text }
  })
  on('command.register', () => ({ value: { command: 'guardian-enrichment' } }))
  on('ui.open', (_, e) => {
    seen.opened.push(e)
    return { value: { isPlaced: true } }
  })
  on('ui.close', () => ({ value: {} }))
  on('ui.panes', () => ({ value: [] }))
  on('ui.toast', (_, e) => {
    seen.toasts.push(String(e.text))
    return { value: {} }
  })
  on('ui.status', (_, e) => {
    seen.status.push(e.text)
    return { value: {} }
  })
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('prompt.submit', (_, e) => ({ text: e.text }))
  on('tool.call', () => ({ result: {} }))
  on('session.end', (_, e) => ({ sessionId: e.sessionId }))
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text>engine</Text>
  })
  return seen
}

test('a new enrichment draws the band and status quietly, on terminal and desktop', async ($, on) => {
  const files: Record<string, string> = {}
  const seen = engine(on, files)
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })

  files[LOG_PATH] = line('2026-11-03T10:00:00.500Z', ENRICHMENT)
  await $.prompt.submit({ text: 'add login' })

  expect(seen.toasts).toHaveLength(0)
  expect(seen.opened).toHaveLength(0)
  expect(seen.status.at(-1)).toBe('〈〉 Apiiro Guardian: 1 prompt enriched')

  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({ ...BAND, surface })
    expect(await ui.find({ type: 'Text', text: /2 security requirements added to your prompt/ })).toBeDefined()
    expect((await ui.find({ type: 'Text', text: /Data Storage/ }))?.text).toBe('Authentication · Data Storage')
    await ui.unmount()
  }
})

test('the toast option raises a toast per enrichment', { options: { toasts: true } }, async ($, on) => {
  const files: Record<string, string> = {}
  const seen = engine(on, files)
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })

  files[LOG_PATH] = line('2026-11-03T10:00:00.500Z', ENRICHMENT)
  await $.prompt.submit({ text: 'add login' })

  expect(seen.toasts).toEqual(['Apiiro Guardian added security requirements: Authentication, Data Storage'])
})

test('an entry the hook writes later is picked up by the poll', async ($, on) => {
  const time = mock.clock(on, { now: Date.parse('2026-11-03T10:00:00.000Z') })
  const files: Record<string, string> = {}
  const seen = engine(on, files)
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })

  await $.prompt.submit({ text: 'add login' })
  expect(seen.status.at(-1)).toBeUndefined()

  files[LOG_PATH] = line('2026-11-03T10:00:00.500Z', ENRICHMENT)
  await time.advance(1500)
  expect(seen.status.at(-1)).toBe('〈〉 Apiiro Guardian: 1 prompt enriched')
})

test('a narrow or short band draws one line', async ($, on) => {
  const files: Record<string, string> = {}
  engine(on, files)
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  files[LOG_PATH] = line('2026-11-03T10:00:00.500Z', ENRICHMENT)
  await $.prompt.submit({ text: 'add login' })

  const ui = await $.ui.mount({ ...BAND, surface: 'terminal', props: { ...BAND.props, bodyColumns: 40 } })
  expect(await ui.find({ type: 'Text', text: /requirements added/ })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /Data Storage/ })).toBeUndefined()
  await ui.unmount()
})

test('entries already in the log at session start are not announced', async ($, on) => {
  const seen = engine(on, { [LOG_PATH]: line('2026-11-03T09:00:00.000Z', ENRICHMENT) })
  await $.session.start({ cwd: '/', surface: 'desktop', isInteractive: true })
  await $.prompt.submit({ text: 'hello' })

  expect(seen.toasts).toHaveLength(0)
  const ui = await $.ui.mount({ ...BAND, surface: 'desktop' })
  expect((await ui.find({ type: 'Text' }))?.text).toBe('engine')
  await ui.unmount()
})

test('a new session does not reuse the previous session history or cursor', async ($, on) => {
  const files: Record<string, string> = {}
  const session = { id: 's1' }
  const seen = engine(on, files, { session })
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  files[LOG_PATH] = line('2026-11-03T10:00:00.500Z', ENRICHMENT, 'first prompt')
  await $.prompt.submit({ text: 'first prompt' })
  expect(seen.status.at(-1)).toBe('〈〉 Apiiro Guardian: 1 prompt enriched')

  session.id = 's2'
  const secondPath = '/home/me/.apiiro/prevent-log/s2.jsonl'
  files[secondPath] = line('2026-11-03T09:00:00.500Z', ENRICHMENT, 'second prompt')
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  const result = await $.command.run({ command: 'guardian-enrichment' })
  expect(result).toMatchObject({ text: expect.stringContaining('1 prompt') })
  expect(result).toMatchObject({ text: expect.stringContaining('second prompt') })
  expect(result).not.toMatchObject({ text: expect.stringContaining('first prompt') })
})

test('closing the band hides it', async ($, on) => {
  const files: Record<string, string> = {}
  engine(on, files)
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  files[LOG_PATH] = line('2026-11-03T10:00:00.500Z', ENRICHMENT)
  await $.prompt.submit({ text: 'add login' })

  const ui = await $.ui.mount({ ...BAND, surface: 'terminal' })
  await ui.press({ key: 'guardian-enrichment-close' })
  expect((await ui.find({ type: 'Text' }))?.text).toBe('engine')
  await ui.unmount()
})

test('the command says how to turn logging on when it is off', async ($, on) => {
  engine(on, { '/home/me/.apiiro/hooks-config.json': '{"disableEnrichPrompt":false}' })

  const result = await $.command.run({ command: 'guardian-enrichment' })
  expect(result).toMatchObject({
    text: expect.stringContaining('apiiro hooks config enable preventLog'),
  })
})

test('the band expands and collapses the full requirements in place, on terminal and desktop', async ($, on) => {
  const files: Record<string, string> = {}
  const seen = engine(on, files)
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  files[LOG_PATH] = line('2026-11-03T10:00:00.500Z', ENRICHMENT)
  await $.prompt.submit({ text: 'add login' })

  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({ ...BAND, surface })
    expect(await ui.find({ type: 'Text', text: /^Authentication:/ })).toBeUndefined()

    await ui.press({ key: 'guardian-enrichment-details' })
    expect((await ui.find({ type: 'Text', text: /^Authentication:/ }))?.text).toBe('Authentication: Authenticate callers.')
    expect(await ui.find({ type: 'Text', text: /IMPLEMENTATION/ })).toBeUndefined()
    expect(await ui.find({ type: 'Text', text: / · Data Storage/ })).toBeUndefined()

    await ui.press({ key: 'guardian-enrichment-details' })
    expect(await ui.find({ type: 'Text', text: /^Authentication:/ })).toBeUndefined()
    await ui.unmount()
  }
  expect(seen.opened).toHaveLength(0)
})

test('the command lists the session and opens the latest in the band', async ($, on) => {
  const files: Record<string, string> = {}
  engine(on, files)
  await $.session.start({ cwd: '/', surface: 'desktop', isInteractive: true })
  files[LOG_PATH] = [
    line('2026-11-03T09:00:00.000Z', 'Input Validation: Validate every field.', 'first prompt'),
    line('2026-11-03T10:00:00.500Z', ENRICHMENT, 'second prompt'),
  ].join('\n')

  const result = await $.command.run({ command: 'guardian-enrichment' })
  expect(result).toMatchObject({ text: expect.stringContaining('2 prompts') })
  expect(result).toMatchObject({ text: expect.stringContaining('first prompt\n  Input Validation') })

  const ui = await $.ui.mount({ ...BAND, surface: 'desktop' })
  expect((await ui.find({ type: 'Text', text: /^Authentication:/ }))?.text).toBe('Authentication: Authenticate callers.')
  await ui.unmount()
})

const ts = (n: number) => new Date(Date.parse('2026-11-03T10:00:00.000Z') + n * 1000).toISOString()

test('past the 20 kept entries nothing is announced twice and the session total still counts', async ($, on) => {
  const files: Record<string, string> = {}
  const seen = engine(on, files)
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })

  files[LOG_PATH] = Array.from({ length: 25 }, (_, n) => line(ts(n), ENRICHMENT, `prompt ${n}`)).join('\n')
  await $.prompt.submit({ text: 'prompt 24' })
  await $.prompt.submit({ text: 'again' })
  await $.prompt.submit({ text: 'and again' })

  expect(seen.status.filter(text => text !== undefined).at(-1)).toBe('〈〉 Apiiro Guardian: 25 prompts enriched')
  const result = await $.command.run({ command: 'guardian-enrichment' })
  expect(result).toMatchObject({ text: expect.stringContaining('to 25 prompts in this session') })
  expect(result).toMatchObject({ text: expect.stringContaining('The last 20 are listed below.') })
  expect(result).toMatchObject({ text: expect.stringContaining('prompt 24') })
  expect(result).not.toMatchObject({ text: expect.stringContaining('prompt 4\n') })
})

test('malformed and empty log lines are skipped', async ($, on) => {
  const files: Record<string, string> = {}
  const seen = engine(on, files)
  await $.session.start({ cwd: '/', surface: 'desktop', isInteractive: true })

  files[LOG_PATH] = ['{not json', '', JSON.stringify({ ts: ts(1), prompt: 'x', enrichment: '   ' }), line(ts(2), ENRICHMENT)].join('\n')
  await $.prompt.submit({ text: 'add login' })

  expect(seen.status.at(-1)).toBe('〈〉 Apiiro Guardian: 1 prompt enriched')
})

test('with no HOME it reads the log under USERPROFILE', async ($, on) => {
  const files: Record<string, string> = {}
  const seen = engine(on, files, { env: { USERPROFILE: '/profiles/me/' } })
  await $.session.start({ cwd: '/', surface: 'desktop', isInteractive: true })
  files['/profiles/me/.apiiro/prevent-log/s1.jsonl'] = line(ts(1), ENRICHMENT)
  await $.prompt.submit({ text: 'add login' })
  expect(seen.status.at(-1)).toBe('〈〉 Apiiro Guardian: 1 prompt enriched')
})

test('with neither HOME nor USERPROFILE the prompt goes through and nothing is drawn', async ($, on) => {
  const seen = engine(on, { [LOG_PATH]: line(ts(1), ENRICHMENT) }, { env: {} })
  await $.session.start({ cwd: '/', surface: 'desktop', isInteractive: true })
  const result = await $.prompt.submit({ text: 'add login' })
  expect(result).toMatchObject({ text: 'add login' })
  expect(seen.status.at(-1)).toBeUndefined()
})

test('a log over 4 MiB leaves the prompt alone and says so in the status line', async ($, on) => {
  const seen = engine(on, { [LOG_PATH]: line(ts(1), ENRICHMENT) }, { size: 5 * 1024 * 1024 })
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  const result = await $.prompt.submit({ text: 'add login' })
  expect(result).toMatchObject({ text: 'add login' })
  expect(seen.status.at(-1)).toContain('over 4 MiB')
})

test('on Windows the log is read under USERPROFILE even when HOME is set', async ($, on) => {
  const files: Record<string, string> = {}
  const seen = engine(on, files, { env: { OS: 'Windows_NT', HOME: '/msys/home/me', USERPROFILE: '/profiles/me' } })
  await $.session.start({ cwd: '/', surface: 'desktop', isInteractive: true })
  files['/msys/home/me/.apiiro/prevent-log/s1.jsonl'] = line(ts(1), 'Wrong Place: not this one.')
  files['/profiles/me/.apiiro/prevent-log/s1.jsonl'] = line(ts(1), ENRICHMENT)
  await $.prompt.submit({ text: 'add login' })
  const ui = await $.ui.mount({ ...BAND, surface: 'desktop' })
  expect((await ui.find({ type: 'Text', text: /Data Storage/ }))?.text).toBe('Authentication · Data Storage')
  await ui.unmount()
  expect(seen.status.at(-1)).toBe('〈〉 Apiiro Guardian: 1 prompt enriched')
})

test('after /clear the poll reads the new session log', async ($, on) => {
  const time = mock.clock(on, { now: Date.parse('2026-11-03T10:00:00.000Z') })
  const files: Record<string, string> = {}
  const session = { id: 's1' }
  const seen = engine(on, files, { session })
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })

  await $.session.end({ reason: 'clear', sessionId: 's1' } as never)
  session.id = 's2'
  files['/home/me/.apiiro/prevent-log/s2.jsonl'] = line(ts(1), ENRICHMENT)
  await time.advance(1500)
  expect(seen.status.at(-1)).toBe('〈〉 Apiiro Guardian: 1 prompt enriched')
})

test('after /clear without a session start the new session counts only its own entries', async ($, on) => {
  const time = mock.clock(on, { now: Date.parse('2026-11-03T10:00:00.000Z') })
  const files: Record<string, string> = {}
  const session = { id: 's1' }
  const seen = engine(on, files, { session })
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  files[LOG_PATH] = line(ts(10), ENRICHMENT)
  await $.prompt.submit({ text: 'first' })
  expect(seen.status.at(-1)).toBe('〈〉 Apiiro Guardian: 1 prompt enriched')

  await $.session.end({ reason: 'clear', sessionId: 's1' } as never)
  session.id = 's2'
  files['/home/me/.apiiro/prevent-log/s2.jsonl'] = [line(ts(1), ENRICHMENT), line(ts(2), ENRICHMENT)].join('\n')
  await time.advance(1500)
  expect(seen.status.at(-1)).toBe('〈〉 Apiiro Guardian: 2 prompts enriched')
})

test('after /clear without a session start or a new log the previous session is not shown', async ($, on) => {
  const time = mock.clock(on, { now: Date.parse('2026-11-03T10:00:00.000Z') })
  const files: Record<string, string> = {}
  const session = { id: 's1' }
  const seen = engine(on, files, { session })
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  files[LOG_PATH] = line(ts(10), ENRICHMENT, 'old prompt')
  await $.prompt.submit({ text: 'old prompt' })
  expect(seen.status.at(-1)).toBe('〈〉 Apiiro Guardian: 1 prompt enriched')

  await $.session.end({ reason: 'clear', sessionId: 's1' } as never)
  session.id = 's2'
  await time.advance(1500)
  expect(seen.status.at(-1)).toBeUndefined()

  const ui = await $.ui.mount({ ...BAND, surface: 'terminal' })
  expect(await ui.find({ type: 'Text', text: /requirements added/ })).toBeUndefined()
  await ui.unmount()

  const result = await $.command.run({ command: 'guardian-enrichment' })
  expect(result).not.toMatchObject({ text: expect.stringContaining('old prompt') })
})

test('a topic with a hyphen is named in the band', async ($, on) => {
  const files: Record<string, string> = {}
  engine(on, files)
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  files[LOG_PATH] = line(ts(1), 'Security Requirements:\nThird-Party Integration: Pin vendor SDKs.\n\nAuthentication: Authenticate callers.')
  await $.prompt.submit({ text: 'add login' })
  const ui = await $.ui.mount({ ...BAND, surface: 'terminal' })
  expect((await ui.find({ type: 'Text', text: /Third-Party/ }))?.text).toBe('Third-Party Integration · Authentication')
  await ui.unmount()
})

test('an entry that lands while the start-up baseline runs is still announced', async ($, on) => {
  const files: Record<string, string> = {}
  let reached!: () => void
  let release!: () => void
  const isReached = new Promise<void>(resolve => (reached = resolve))
  engine(on, files, { gate: { reached, release: new Promise<void>(resolve => (release = resolve)) } })
  const starting = $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await isReached
  files[LOG_PATH] = line(ts(1), ENRICHMENT)
  const submitting = $.prompt.submit({ text: 'add login' })
  release()
  await Promise.all([starting, submitting])

  const ui = await $.ui.mount({ ...BAND, surface: 'terminal' })
  expect(await ui.find({ type: 'Text', text: /requirements added/ })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: 'engine' })).toBeDefined()
  await ui.unmount()
})

test('a closed band comes back for the next enrichment', async ($, on) => {
  const files: Record<string, string> = {}
  engine(on, files)
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  files[LOG_PATH] = line(ts(1), ENRICHMENT)
  await $.prompt.submit({ text: 'first' })

  const ui = await $.ui.mount({ ...BAND, surface: 'terminal' })
  await ui.press({ key: 'guardian-enrichment-close' })
  expect(await ui.find({ type: 'Text', text: /requirements added/ })).toBeUndefined()
  await ui.unmount()

  files[LOG_PATH] = [line(ts(1), ENRICHMENT), line(ts(2), ENRICHMENT)].join('\n')
  await $.prompt.submit({ text: 'second' })
  const again = await $.ui.mount({ ...BAND, surface: 'terminal' })
  expect(await again.find({ type: 'Text', text: /requirements added/ })).toBeDefined()
  await again.unmount()
})

test('a value an earlier version stored is taken as a fresh start, quietly', async ($, on) => {
  on('state.get', () => ({ value: { value: { events: [], activeTs: 'x' }, version: 1 } }))
  const seen = engine(on, { [LOG_PATH]: line(ts(1), ENRICHMENT) })
  await $.session.start({ cwd: '/', surface: 'desktop', isInteractive: true })
  await $.prompt.submit({ text: 'hello' })

  expect(seen.toasts).toHaveLength(0)
  const ui = await $.ui.mount({ ...BAND, surface: 'desktop' })
  expect((await ui.find({ type: 'Text' }))?.text).toBe('engine')
  await ui.unmount()
})
