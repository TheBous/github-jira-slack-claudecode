# jira-git-sync

Claude Code plugin: git → Jira → Slack workflow automation.

## Commands

| Command | What it does | When to use | Outcome |
|---|---|---|---|
| **setup** | Configure Jira, Slack, Confluence credentials | Once, at project start | Credentials saved locally in `.env` |
| **new-branch** | Create branch from Jira ticket + move ticket to In Progress | Start a task | Branch created, Slack notified, ticket In Progress |
| **cook** | Implement feature/fix: write code, run tests, update docs | While developing on the branch | Code committed, tests passed, docs current |
| **create-pr** | Open PR against main + link Jira + notify Slack | When code is ready for review | PR opened, Jira commented, Slack notified |
| **review-pr** | Analyze PR: correctness, naming, coverage + structured review | As a reviewer on any PR | Verdict shown, inline comments ready to submit |
| **address-review** | Resolve each review comment one-by-one + update docs | After receiving review feedback | Comments resolved, fixes applied, PR updated |
| **merge-pr** | Merge PR + move ticket to In Staging + notify Slack | After PR is approved | PR merged to main, ticket In Staging, Slack notified |
| **tag** | Create release tag + transition all tickets to Done + Slack | Before production deploy | Tag created, all tickets Done, Slack notified |
| **create-doc** | Generate new Confluence page from code | Documenting a new feature | Page created under Confluence parent |
| **update-doc** | Update existing Confluence page with latest changes | Keeping docs in sync with code | Page updated with new content |

## Installation

```bash
# Add the marketplace (once per team)
/plugin marketplace add lucvalse/jira-git-sync

# Install the plugin
/plugin install jira-git-sync

# Configure credentials (interactive)
/jira-git-sync:setup
```

## Requirements

- Authenticated `gh` CLI (`gh auth login`)
- Jira account with API token ([generate here](https://id.atlassian.com/manage-profile/security/api-tokens))
- Slack Incoming Webhook ([create here](https://api.slack.com/messaging/webhooks))

## Branch convention

The branch name must contain the Jira key for automatic linking:

```
feat/dc-443-ticket-title           ✓
fix/AUTH-12-fix-oauth-redirect     ✓
my-random-branch                   ✗  (no Jira link)
```
