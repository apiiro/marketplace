export type Enrichment = { ts: string; prompt: string; enrichment: string }

export type EnrichmentState = {
  sessionId: string | null
  events: Enrichment[]
  total: number
  activeTs: string | null
  isExpanded: boolean
  seenThrough: string | null
}

declare module 'claude-code' {
  interface PluginState {
    'guardian-enrichment': {
      state: Shaped<EnrichmentState>
    }
  }
}
