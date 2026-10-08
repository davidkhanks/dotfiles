/** What the band knows about the repo, or null when there is nothing to ship. */
export type ShipStatus = {
  branch: string
  /** Files with uncommitted changes. */
  dirty: number
  /** Commits on this branch not yet on its upstream. */
  ahead: number
  /** False when the branch has never been pushed. */
  hasUpstream: boolean
} | null

declare module 'claude-code' {
  interface PluginState {
    'ship': {
      status: ShipStatus
      /** The label that was dismissed, so new work un-hides the band. */
      hiddenFor: string | null
    }
  }
}
