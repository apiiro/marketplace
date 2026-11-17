import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { Enrichment, EnrichmentState } from '../types'

const COMMAND = 'guardian-enrichment'
const TITLE = 'Apiiro Guardian'
const BRAND = '#6ef0c8'
const ACCENT = '#00a090'
const HISTORY_LIMIT = 20
const POLL_MS = 1500
const COMPACT_COLUMNS = 50
const FULL_ROWS = 2
const MAX_LOG_BYTES = 4 * 1024 * 1024
const TOPIC_LINE = /^([A-Z][A-Za-z -]{2,40}):\s+\S/

const store = atom(
  { plugin: 'guardian-enrichment', key: 'state' } as const,
  { sessionId: null, events: [], total: 0, activeTs: null, isExpanded: false, seenThrough: null },
  { shape: 'state-5' },
)

// The apiiro CLI resolves its folder with os.homedir(): USERPROFILE on Windows, HOME elsewhere.
async function apiiroDir($: EngineInterface): Promise<string | undefined> {
  const home = (await $.env.get('OS')) === 'Windows_NT'
    ? (await $.env.get('USERPROFILE')) ?? (await $.env.get('HOME'))
    : (await $.env.get('HOME')) ?? (await $.env.get('USERPROFILE'))
  return home === undefined ? undefined : `${home.replace(/[\\/]$/, '')}/.apiiro`
}

function parseLog(text: string): Enrichment[] {
  const entries: Enrichment[] = []
  for (const line of text.split('\n')) {
    if (!line.trim()) continue
    try {
      const row = JSON.parse(line)
      if (typeof row.enrichment === 'string' && row.enrichment.trim()) {
        entries.push({
          ts: String(row.ts ?? ''),
          prompt: String(row.prompt ?? ''),
          enrichment: row.enrichment.trim(),
        })
      }
    } catch {}
  }
  return entries
}

let lastRead: string | undefined

// undefined: the log is missing or unchanged since the last read.
async function readEntries($: EngineInterface): Promise<Enrichment[] | 'too-big' | undefined> {
  const dir = await apiiroDir($)
  if (dir === undefined) return undefined
  const path = `${dir}/prevent-log/${await $.session.id()}.jsonl`
  const stat = await $.fs.stat(path).catch(() => undefined)
  if (stat === undefined) return undefined
  if (stat.size > MAX_LOG_BYTES) return 'too-big'
  const key = `${path}:${stat.size}:${stat.mtimeMs}`
  if (key === lastRead) return undefined
  const text = await $.fs.read(path).catch(() => undefined)
  if (text === undefined) return undefined
  lastRead = key
  return parseLog(text)
}

function requirementTopics(enrichment: string): string[] {
  const topics: string[] = []
  for (const line of enrichment.split('\n')) {
    if (/^IMPLEMENTATION GUIDELINES/.test(line)) break
    const match = TOPIC_LINE.exec(line)
    if (match?.[1]) topics.push(match[1])
  }
  return topics
}

function requirementLines(enrichment: string): string[] {
  const lines: string[] = []
  for (const line of enrichment.split('\n')) {
    if (/^IMPLEMENTATION GUIDELINES/.test(line)) break
    if (line.trim()) lines.push(line)
  }
  return lines
}

function statusText(state: EnrichmentState): string | undefined {
  const count = state.total
  return count === 0
    ? undefined
    : `〈〉 ${TITLE}: ${count} prompt${count === 1 ? '' : 's'} enriched`
}

async function dismiss($: EngineInterface): Promise<void> {
  await update($, store, state => ({ ...state, activeTs: null, isExpanded: false }))
}

async function toggleDetails($: EngineInterface): Promise<void> {
  await update($, store, state => ({ ...state, isExpanded: !state.isExpanded }))
}

// Resets the store and clears the status line when the store belongs to another session,
// and returns the current session's state.
async function startSession($: EngineInterface, sessionId: string): Promise<EnrichmentState> {
  const state = await read($, store)
  if (state.sessionId === sessionId) return state
  lastRead = undefined
  $.ui.status(undefined)
  return update($, store, () => ({
    sessionId,
    events: [],
    total: 0,
    activeTs: null,
    isExpanded: false,
    seenThrough: null,
  }))
}

let isToastOn = false
let scanning: { done: Promise<void>; isQuiet: boolean } | undefined
let poll: { cancel: () => void } | undefined

async function scanOnce($: EngineInterface, isQuiet: boolean): Promise<void> {
  // /clear can switch the session without a session.start: the poll then starts the new session's
  // count, before the new session has a log, so the band and status do not show the previous session.
  const state = await startSession($, await $.session.id())
  const entries = await readEntries($)
  if (entries === undefined) return
  if (entries === 'too-big') {
    $.ui.status(`〈〉 ${TITLE}: this session's log is over 4 MiB; the band stopped updating`)
    return
  }
  // The log only grows, in time order: everything up to seenThrough was handled already.
  const fresh = entries.filter(entry => state.seenThrough === null || entry.ts > state.seenThrough)
  if (fresh.length === 0) return

  const next = await update($, store, current => ({
    ...current,
    events: [...current.events, ...fresh].slice(-HISTORY_LIMIT),
    total: current.total + fresh.length,
    seenThrough: fresh.at(-1)!.ts,
    activeTs: isQuiet ? current.activeTs : fresh.at(-1)!.ts,
    isExpanded: isQuiet ? current.isExpanded : false,
  }))
  $.ui.status(statusText(next))
  if (isQuiet) return

  if (isToastOn) {
    const topics = requirementTopics(fresh.at(-1)!.enrichment)
    $.ui.toast(`${TITLE} added security requirements${topics.length > 0 ? `: ${topics.join(', ')}` : ''}`)
  }
}

// One scan at a time: the timer and the turn's events never announce an entry twice.
// A loud scan that arrives during a quiet one runs after it, so its entry is not baselined away.
function scanLog($: EngineInterface, isQuiet = false): Promise<void> {
  if (scanning) return scanning.isQuiet && !isQuiet ? scanning.done.then(() => scanLog($)) : scanning.done
  const done = scanOnce($, isQuiet)
    .catch(() => undefined)
    .finally(() => {
      scanning = undefined
    })
  scanning = { done, isQuiet }
  return done
}

export const register: Register = (on, options) => {
  isToastOn = options.toasts === true

  on('session.start', async ($, e, next) => {
    const result = await next(e)
    await startSession($, await $.session.id())
    await $.command
      .register({ name: COMMAND, description: "Show what Apiiro Guardian added to this session's prompts" })
      .catch(() => undefined)
    const state = await read($, store)
    await scanLog($, state.seenThrough === null)
    $.ui.status(statusText(await read($, store)))
    // The poll runs for the process: after /clear or a resume it reads the new session's log.
    poll?.cancel()
    poll = $.clock.every(POLL_MS, () => void scanLog($))

    return result
  })

  on('prompt.submit', async ($, e, next) => {
    const result = await next(e)
    await scanLog($)

    return result
  }).catch(($, e, next) => next(e))

  on('turn.complete', async ($, e, next) => {
    if (e.agentId === undefined) await scanLog($)

    return next(e)
  }).catch(($, e, next) => next(e))

  on('command.run', { command: COMMAND }, async $ => {
    await scanLog($, true)
    const state = await read($, store)
    const latest = state.events.at(-1)
    if (latest) {
      await update($, store, current => ({ ...current, activeTs: latest.ts, isExpanded: true }))
      const text = [...state.events]
        .reverse()
        .map(event => `${event.prompt}\n  ${requirementTopics(event.enrichment).join(', ')}`)
        .join('\n\n')
      const listed = state.total > state.events.length ? ` The last ${state.events.length} are listed below.` : ''
      return { text: `${TITLE} added security requirements to ${state.total} prompt${state.total === 1 ? '' : 's'} in this session; the latest is open above the prompt.${listed}\n\n${text}` }
    }

    const dir = await apiiroDir($)
    const config = dir
      ? await $.fs.read(`${dir}/hooks-config.json`).catch(() => '{}')
      : '{}'
    let isLogOn = false
    try {
      isLogOn = JSON.parse(config).enablePreventLog === true
    } catch {}

    return {
      text: isLogOn
        ? `${TITLE} has not enriched a prompt in this session yet.`
        : `${TITLE} enrichment logging is off. Turn it on with: apiiro hooks config enable preventLog`,
    }
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const existing = await next(e)
    try {
      const state = await read($, store)
      const entry = state.events.find(event => event.ts === state.activeTs)
      if (!entry || e.props.hasSurvey || e.props.maxRows < 1) return existing

      const { Box, Button, Text } = $.ui.resolve(e)
      const topics = requirementTopics(entry.enrichment)
      const isCompact = e.props.bodyColumns < COMPACT_COLUMNS || e.props.maxRows < FULL_ROWS
      const isExpanded = state.isExpanded && !isCompact
      const count = topics.length
      const headline = count > 0
        ? `${count} security requirement${count === 1 ? '' : 's'} added to your prompt`
        : 'Security requirements added to your prompt'

      // The pane chords press these from the prompt: the terminal's main screen passes no clicks.
      const chord = (keys: string) => (e.surface === 'terminal' ? ` (${keys})` : '')
      const buttons = (
        <Box gap={1} flexShrink={0} alignItems="center">
          {!isCompact && (
            <Button
              key="guardian-enrichment-details"
              label={isExpanded ? `Hide details${chord('ctrl+x ↓')}` : `Details${chord('ctrl+x ↑')}`}
              action={isExpanded ? 'pane:shrink' : 'pane:grow'}
              onPress={() => void toggleDetails($)}
            />
          )}
          <Button
            key="guardian-enrichment-close"
            label={`Close${chord('ctrl+x x')}`}
            action="pane:close"
            role="dismiss"
            onPress={() => void dismiss($)}
          />
        </Box>
      )

      return (
        <Box flexDirection="column">
          <Box justifyContent="space-between" alignItems="center" columnGap={2}>
            <Box flexDirection="column" flexShrink={1}>
              <Text wrap="truncate-end">
                <Text color={BRAND} bold>{TITLE}</Text>
                <Text dimColor> · {headline}</Text>
              </Text>
              {!isCompact && !isExpanded && count > 0 && (
                <Text wrap="truncate-end">
                  {topics.flatMap((topic, index) => [
                    ...(index > 0 ? [<Text dimColor> · </Text>] : []),
                    <Text color={ACCENT}>{topic}</Text>,
                  ])}
                </Text>
              )}
            </Box>
            {buttons}
          </Box>
          {isExpanded &&
            requirementLines(entry.enrichment)
              .filter(line => !/^Security Requirements:\s*$/.test(line))
              .map(line => {
                const match = TOPIC_LINE.exec(line)
                const topic = match?.[1]
                return topic ? (
                  <Box marginTop={1}>
                    <Text wrap="wrap">
                      <Text color={ACCENT} bold>{topic}</Text>
                      <Text>{line.slice(topic.length)}</Text>
                    </Text>
                  </Box>
                ) : (
                  <Text wrap="wrap">{line}</Text>
                )
              })}
          {existing}
        </Box>
      )
    } catch {
      return existing
    }
  })
}
