/** One assigned ticket, as the list shows it. */
export type Ticket = {
  /** The identifier, e.g. MYE-2362. */
  id: string
  title: string
  status: string
  /** Linear's state type: triage, backlog, unstarted, started, ... */
  statusType: string
  priority: string
  team: string
  project: string | null
  url: string
  gitBranchName: string
  updatedAt: string
}

/** What the pane is waiting on the person to confirm, if anything. */
export type Pending = { id: string; action: 'start' | 'claude' } | null

declare module 'claude-code' {
  interface PluginState {
    'tickets': {
      tickets: Ticket[]
      /** True while the list is being fetched. */
      isLoading: boolean
      /** Why the last fetch failed, or null. */
      error: string | null
      /** The ticket whose details are shown. */
      expanded: string | null
      /** Descriptions fetched on expand, by ticket id. */
      descriptions: Record<string, string>
      pending: Pending
      /** The ticket an action is running on, so its buttons can't double-fire. */
      busy: string | null
    }
  }
}
