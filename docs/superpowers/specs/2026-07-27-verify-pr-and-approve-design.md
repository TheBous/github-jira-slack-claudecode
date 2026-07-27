# Design: `verify-pr-and-approve` Skill

**Date:** 2026-07-27  
**Status:** Design  
**Scope:** jira-git-sync skill to verify reviewer's comments are resolved and approve PR

---

## Goal

Create a skill that verifies all of the current user's review comments on a GitHub PR are resolved, and if so, approves the PR with a confirmation message. If any comments remain unresolved, display them and abort the approval.

---

## Input & Mode Detection

The skill accepts an optional argument to specify the PR:

| Input | Mode |
|-------|------|
| `verify-pr-and-approve 123` | PR number on current repo |
| `verify-pr-and-approve https://github.com/owner/repo/pull/123` | Full PR URL |
| `verify-pr-and-approve` (no arg) | Detect PR from current branch |

**Flow for mode detection:**
1. If argument provided, parse it (number or URL)
2. If no argument, run `gh pr view --json number,title,url,headRefName` to detect current PR
3. Extract `OWNER/REPO` and PR number for all subsequent queries
4. **TLS fallback:** if step 2 fails, use curl + git remote + branch name (see `references/full-mode.md`)

**Validation:** if no PR can be found, stop and ask user for explicit URL.

---

## Authentication

- Verify user is authenticated: `gh auth status` (succeeds if logged in)
- If not authenticated, tell user to run `gh auth login`
- Current user login is extracted from `gh auth status` output for comment filtering

---

## Step 1: Fetch Review Comments

Query all review-level comments (general feedback) and inline code-review comments (diff threads) on the PR.

**GraphQL query** (see `scripts/get-pr-comments`):
```graphql
{
  repository(owner: "OWNER", name: "REPO") {
    pullRequest(number: PR_NUMBER) {
      reviews(first: 100, states: [COMMENTED, CHANGES_REQUESTED]) {
        nodes {
          id
          author { login }
          body
          state
          comments(first: 100) {
            nodes {
              id
              author { login }
              body
              path
              line
              isResolved
            }
          }
        }
      }
    }
  }
}
```

**Fetch inline code-review comments** (see `scripts/get-thread-for-comment`):
```graphql
{
  repository(owner: "OWNER", name: "REPO") {
    pullRequest(number: PR_NUMBER) {
      reviewThreads(first: 100) {
        nodes {
          id
          isResolved
          comments(first: 100) {
            nodes {
              id
              author { login }
              body
              path
              startLine
              line
            }
          }
        }
      }
    }
  }
}
```

**API fallback** (TLS/certificate error):
```bash
curl -sf -H "Authorization: Bearer $(gh auth token)" \
  "https://api.github.com/repos/OWNER/REPO/pulls/PR_NUMBER/reviews" \
  | jq '.'

curl -sf -H "Authorization: Bearer $(gh auth token)" \
  "https://api.github.com/repos/OWNER/REPO/pulls/PR_NUMBER/comments" \
  | jq '.'
```

---

## Step 2: Filter Current User's Comments

- Extract current user login from `gh auth status`
- Filter all fetched comments/threads to include only those where `author.login == CURRENT_USER`
- Group by thread ID (for inline comments) or review ID (for general comments)

**Result:** list of unresolved comment threads authored by the current user, in order (by path, then line number for inline; chronological for general comments).

---

## Step 3: Verify Resolution Status

For each comment/thread from step 2:

**General review comments:** check `review.state` — if state is `CHANGES_REQUESTED` and no reply to address it exists, mark as **unresolved**.

**Inline code-review comments:** check `reviewThread.isResolved` — if `false`, mark as **unresolved**. If `true`, mark as **resolved**.

**Summary:** count resolved vs. unresolved.

---

## Step 4: Decision Gate

**If all comments are resolved (or user has 0 comments on the PR):**
- Proceed to step 5 (approve)

**If any comments are unresolved:**
- Display them to the user (file, line, snippet, author)
- Stop and do NOT approve
- Suggest: "Resolve these threads or contact the author before approving"

---

## Step 5: Approve the PR

If gate passes (all resolved):

1. Run `gh pr review <PR_NUMBER> --approve`
2. Add a comment via GraphQL or API:
   ```bash
   gh api repos/:owner/:repo/issues/PR_NUMBER/comments \
     -X POST -f body="All review comments resolved ✅"
   ```
   (or curl fallback if TLS fails)

3. Confirm to user:
   ```
   ✅ PR #123 approved
   💬 Comment added: "All review comments resolved ✅"
   ```

---

## Error Handling

| Scenario | Action |
|----------|--------|
| PR number not found | Stop, ask for explicit URL |
| User not authenticated | Stop, suggest `gh auth login` |
| GraphQL query fails (TLS) | Retry via curl API fallback |
| Approval fails (e.g., user lacks permission) | Show error, stop |
| Comment posting fails | Show error, but PR is already approved |

---

## References & Scripts

- `references/full-mode.md` — detailed step-by-step implementation
- `references/auth-and-fetch.md` — authentication + GraphQL query patterns
- `scripts/get-pr-comments` — GraphQL query for reviews + inline comments
- `scripts/get-thread-for-comment` — map comment to thread; check resolution
- `scripts/approve-pr` — gh pr review + comment posting

---

## Success Criteria

✅ User can call `verify-pr-and-approve [PR-NUM|URL]`  
✅ Fetches only the user's own review comments  
✅ Correctly identifies resolved vs. unresolved threads  
✅ Approves PR + posts confirmation message if all resolved  
✅ Shows unresolved comments and stops if any remain  
✅ TLS certificate errors fall back to curl  
✅ Clear error messages for auth/not-found cases  

---

## Notes

- Inspired by `ce-resolve-pr-feedback` structure (references/, scripts/, SKILL.md)
- Integrated into jira-git-sync plugin (follows existing skill patterns)
- No interactive approval loop — decision is binary (all resolved → approve, else → stop)
- Comment message is fixed: "All review comments resolved ✅" (no customization)
