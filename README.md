# jira-git-sync

Claude Code plugin: git → Jira → Slack workflow automation.

## Commands

| Command | What it does |
|---|---|
| `/jira-git-sync:setup` | Configure Jira and Slack credentials (one time only) |
| `/jira-git-sync:new-branch` | New branch from a Jira ticket → ticket In Progress + Slack |
| `/jira-git-sync:create-pr` | Create PR against main → ticket In Review + Slack |
| `/jira-git-sync:merge-pr` | Merge PR → ticket In Staging + Slack |
| `/jira-git-sync:tag` | Tag release → all tickets Done + Slack |

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
