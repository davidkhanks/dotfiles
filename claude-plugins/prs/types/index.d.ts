/** Where the repo's pull requests live, read from the `origin` remote. */
export type Repo = { host: 'bitbucket' | 'github'; owner: string; name: string }

/** Which pull requests the list shows. */
export type Filter = 'open' | 'draft' | 'merged'

/** What a pull request's buttons hand to Claude. */
export type Action = 'checkout' | 'address' | 'approve' | 'squash' | 'merge'

/** The action waiting on the person's Yes, if any. */
export type Pending = { number: number; action: Action } | null

/** One pull request, as the list shows it. */
export type PullRequest = {
  number: number
  title: string
  author: string
  /** `open` means open and not a draft. */
  state: Filter
  branch: string
  url: string
  updatedAt: string
  /** True when the person running /prs has approved it, as of the last load. */
  approvedByMe: boolean
}

declare module 'claude-code' {
  interface PluginState {
    'prs': {
      repo: Repo | null
      prs: PullRequest[]
      /** True while the list or the descriptions are being fetched. */
      isLoading: boolean
      /** Why the last load failed, or null. */
      error: string | null
      filter: Filter
      /** The pull request whose details are shown. */
      expanded: number | null
      /** Descriptions, fetched as the pane loads, by pull request number. */
      descriptions: Record<string, string>
      pending: Pending
      /** Pull requests whose approval was handed to Claude since the last load. */
      approvalsSent: number[]
      /** The pull request being handed to Claude, so its button can't double-fire. */
      busy: number | null
    }
  }
}
