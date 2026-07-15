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

## Testing & Regression Prevention

### What are Evals?

Evals are automated test cases that verify each command works as expected. Each eval:
- **Defines a task** (e.g., "Create a new branch for ticket DC-443")
- **Lists expectations** (e.g., "Calls getJiraIssue", "Branch includes ticket key", "Ticket transitioned to In Progress")
- **Runs the command** and checks if all expectations are met
- **Produces a report** with pass/fail for each expectation

Evals live in `evals/evals.json5` (human-readable format) and can be run to catch regressions before merging changes.

### Running Evals

Inside Claude Code (interactive session):

```
/skill-creator
```

Then say: "Run evals mode. Test evals/evals.json5 for jira-git-sync."

This spawns subagents to:
1. Execute each test case (executor)
2. Grade each expectation (grader)
3. Produce a `grading.json` report with pass/fail + evidence

### Preventing Regressions

**Before modifying a command:**
1. Run the full eval suite to establish a baseline
2. Note which expectations pass
3. Make your change
4. Re-run evals — if pass rates drop, you've introduced a regression
5. Either fix the regression or update the evals if the new behavior is intentional

**After adding a new command:**
1. Write 2–3 realistic test cases in `evals/evals.json5`
2. Run evals to confirm they all pass
3. Commit both the command and its evals
4. Anyone can now run evals to verify the command still works

### Example Eval

```json5
{
  id: 1,
  command: "new-branch",
  prompt: "Create a new branch for ticket DC-443",
  expected_output: "Fetches DC-443 from Jira, derives branch name, creates branch, transitions ticket, posts Slack notification",
  expectations: [
    "Calls getJiraIssue for DC-443 before naming the branch",
    "Branch name includes the lowercase ticket key (dc-443)",
    "Ticket is transitioned to 'In Progress' via Jira MCP",
    "A Slack message is sent announcing the new branch"
  ]
}
```

When you run evals, each expectation is checked against the transcript — if all pass, that eval passes.
