---
description: Resolve code review comments, then update documentation where needed
---

## Goal

Read the open comments on a GitHub PR and resolve them one at a time: for each comment, propose a fix, wait for the user's approval, apply it only after confirmation, then reply on the PR. No code is changed without explicit permission. At the end of the cycle, update documentation if needed.

## Steps

### 1. Identify the PR

If the user passed a PR URL when invoking the command, use it.

Otherwise, detect the PR from the current branch:
```bash
gh pr view --json number,title,url,headRefName 2>/dev/null
```

**If the command fails with a TLS/certificate error**, use this fallback:
```bash
OWNER_REPO=$(git remote get-url origin | sed -E 's#.*[:/]([^/]+/[^/]+)(\.git)?$#\1#')
BRANCH=$(git branch --show-current)
curl -sf -H "Authorization: Bearer $(gh auth token)" \
  "https://api.github.com/repos/$OWNER_REPO/pulls?head=$(echo $OWNER_REPO | cut -d/ -f1):$BRANCH&state=open" \
  | jq '.[0] | {number, title, url: .html_url, headRefName: .head.ref}'
```

If there's no open PR for the current branch, ask the user to pass the URL explicitly.

### 2. Fetch the review comments

```bash
gh pr view <NUMBER> --json reviews,comments \
  --jq '.reviews[] | select(.state == "CHANGES_REQUESTED") | {author: .author.login, body: .body}'

gh api repos/:owner/:repo/pulls/<NUMBER>/comments \
  --jq '.[] | {path: .path, line: .line, body: .body, author: .user.login}'
```

**TLS fallback**:
```bash
curl -sf -H "Authorization: Bearer $(gh auth token)" \
  "https://api.github.com/repos/$OWNER_REPO/pulls/<NUMBER>/reviews" \
  | jq '.[] | select(.state == "CHANGES_REQUESTED") | {author: .user.login, body}'

curl -sf -H "Authorization: Bearer $(gh auth token)" \
  "https://api.github.com/repos/$OWNER_REPO/pulls/<NUMBER>/comments" \
  | jq '.[] | {path, line, body, author: .user.login}'
```

Collect both general comments and inline code comments. Sort inline comments by file, then by line number (order of appearance in the PR). General (review-level) comments should be addressed first, in chronological order.

### 3. Set the approach with receiving-code-review

If the `superpowers:receiving-code-review` skill is available in the workspace, invoke it once via the Skill tool to set the approach: technical rigor, verify before implementing, no performative agreement. Apply these principles manually to each comment in the loop in step 4 — don't re-invoke the skill on every iteration.

If it's not available, proceed anyway with the same principle: assess whether the comment is technically sound before proposing a fix.

### 4. Resolve comments one at a time

**Never change code without the user's explicit permission.** For each comment, in the order set in step 2:

1. Show the comment:
   ```
   📝 Comment on <file>:<line> (by <author>)
   "<comment text>"
   ```
2. Analyze the comment and propose a concrete fix:
   ```
   💡 Proposal: <description of the change you would make>

   Sound good? Do you want to change it or do you have a different opinion?
   ```
3. Wait for the user's reply. Depending on what they say:
   - **Approves**: apply the fix to the code
   - **Modifies the proposal**: adapt the fix per their instructions, then apply it
   - **Disagrees / wants something else**: discuss until you converge on an action (which may also be "don't change anything")
4. Determine the final status based on what was decided, using this table:

   | Status | Format | When to use it |
   |-------|---------|---------------|
   | ✅ Fixed | `✅ Fixed — <brief description of the change>` | Fix applied |
   | 🔄 Refactored | `🔄 Refactored — <what changed and why>` | Fix that required a broader restructuring |
   | 💬 Acknowledged | `💬 Acknowledged — <reason for not changing>` | Valid comment but doesn't require a code change |
   | ❓ Clarification needed | `❓ Clarification needed — <specific question>` | The comment is unclear or needs more context from the reviewer |
   | 🚫 Won't Fix | `🚫 Won't Fix — <technical or product reasoning>` | Deliberate choice not to apply the change |
   | ⛔ Stalled | `⛔ Stalled — <dependency or blocker>` | Can't be resolved now, blocked by something external |

5. Post the reply on that comment immediately, before moving to the next one:
   ```bash
   gh api repos/:owner/:repo/pulls/comments/<COMMENT_ID>/replies \
     -X POST -f body="<reply with emoji>"
   ```

   **TLS fallback**:
   ```bash
   curl -sf -X POST -H "Authorization: Bearer $(gh auth token)" \
     "https://api.github.com/repos/$OWNER_REPO/pulls/comments/<COMMENT_ID>/replies" \
     -d "{\"body\":\"<reply with emoji>\"}"
   ```

Repeat from point 1 for the next comment, until the list is exhausted.

### 5. Run the tests

If code changes were applied during the cycle, read `references/run-tests.md` (in the plugin root) and follow the instructions to find and run the project's tests/lint/checks.

If no comment required code changes, skip this step.

### 6. Analyze the overall diff and identify docs to update

After resolving all the comments in the cycle:
```bash
git diff HEAD --name-only
```

For each changed file, assess whether the change is logically significant (new signature, changed behavior, removed something public). If so, look for related documentation:

**Local docs** — check if a `docs/` folder exists in the repo:
```bash
ls docs/ 2>/dev/null && grep -rl "<changed-file-name>" docs/ 2>/dev/null
```

**Confluence** — load the credentials and check if `CONFLUENCE_PARENT_URL` is configured:
```bash
source "${CLAUDE_PLUGIN_DATA}/.env" 2>/dev/null
```

If `CONFLUENCE_PARENT_URL` is not empty, use the MCP tool `searchConfluenceUsingCql`:
```
ancestor = <PARENT_PAGE_ID> AND text ~ "<changed-file>"
```

### 7. Ask for confirmation before updating docs

If candidates were found (local or Confluence), show the user:
```
📄 These documents might need updating:
- [local] docs/auth.md
- [Confluence] Authentication flow → <url>

Do you want to update them? (yes/no/list which ones)
```

Wait for a reply before proceeding.

### 8. Update the documentation

**Local docs**: edit the `.md` files in the `docs/` folder directly with the updated information. Show the diff before saving.

**Confluence**: use the MCP tool `updateConfluencePage` for each confirmed page.

If no document was found or the user declines, skip this step silently.

### 9. Confirmation

Show the user:
- Fixes applied for the review comments
- Tests: `<list of scripts>` — all green (if run)
- Replies posted on the PR with their emoji statuses
- Documentation updated: `<list of files/pages>` (if applicable)
- Suggest pushing the branch with `git push`
