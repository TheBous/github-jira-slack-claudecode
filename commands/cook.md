---
description: Develop a feature or fix on the current branch, run tests, and update documentation
---

## Goal

Implement a feature or fix starting from the context of the current branch/ticket, ensuring tests pass and documentation is up to date.

## Steps

### 1. Gather context

Extract the Jira key from the current branch (pattern `[A-Z]+-[0-9]+`):
```bash
git branch --show-current
```

If found, fetch the ticket's title and description with the MCP tool `getJiraIssue` using `issueKey: "<KEY>"` and `fields: ["summary", "description"]`.

Show the user:
```
🎫 Ticket: <KEY> — <title>
📋 <description truncated to 300 characters>

Is this what you want to implement? Do you want to add details or correct the direction?
```

Wait for a reply and incorporate any clarifications before proceeding.

### 2. Choose the development flow

Ask the user:
```
How do you want to approach this task?

1. 🧠 Brainstorming — explore options and approaches before writing code
2. 🔥 Grilling — a Q&A session to nail down requirements in detail
3. ⚡ Direct — implement right away with no preliminary flow
```

- If they choose **1**: invoke the `superpowers:brainstorming` skill before proceeding
- If they choose **2**: invoke the `grilling` skill before proceeding
- If they choose **3**: go directly to step 3

### 3. Implement

Read the relevant code in the repository to understand the context before writing. Implement the feature or fix following the existing codebase's conventions.

After each significant change, briefly show what you did before continuing.

### 4. Run the tests

Read `references/run-tests.md` (in the plugin root) and follow the instructions to find and run the project's tests/lint/checks.

### 5. Update documentation

Fetch the changed files:
```bash
git diff HEAD --name-only
```

**Local docs** — if `docs/` exists:
```bash
ls docs/ 2>/dev/null && grep -rl "<changed-file>" docs/ 2>/dev/null
```

**Confluence** — if `CONFLUENCE_PARENT_URL` is configured in `.env`:
```bash
source "${CLAUDE_PLUGIN_DATA}/.env"
```
Extract `PARENT_PAGE_ID` and use the MCP tool `searchConfluenceUsingCql`:
```
ancestor = <PARENT_PAGE_ID> AND (text ~ "<file1>" OR text ~ "<file2>")
```

If candidates are found (local or Confluence), show:
```
📄 Documentation to update:
- [local] docs/auth.md
- [Confluence] <title> → <url>

Do you want to update them? (yes/no/list which ones)
```

Wait for confirmation. For each confirmed doc, update the relevant content to reflect the implemented changes.

### 6. Final confirmation

Show the user:
- ✅ Feature/fix implemented
- ✅ Tests: `<list of scripts>` — all green
- ✅ Documentation updated: `<list of files/pages>` (if applicable)
- → Suggest the next step: `/jira-git-sync:create-pr`
