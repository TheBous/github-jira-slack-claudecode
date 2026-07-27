# Verify PR and Approve

Verify that all of your review comments on a GitHub PR are resolved, and if so, approve the PR with a confirmation message.

## When to Use

Use this skill when you've done a code review on a PR and want to automatically check that all your comments are marked resolved before approving.

## Mode Detection

| Input | Behavior |
|-------|----------|
| No argument | Detect PR from current branch |
| PR number (e.g., `123`) | Use that PR on current repo |
| Full PR URL (e.g., `https://github.com/owner/repo/pull/123`) | Parse and use that PR |

## Steps

### 1. Identify the PR

If the user passed an argument, parse it (number or URL). Otherwise, detect the PR from the current branch using:

```bash
gh pr view --json number,title,url,headRefName
```

**TLS fallback** (if the command fails):
```bash
OWNER_REPO=$(git remote get-url origin | sed -E 's#.*[:/]([^/]+/[^/]+)(\.git)?$#\1#')
BRANCH=$(git branch --show-current)
curl -sf -H "Authorization: Bearer $(gh auth token)" \
  "https://api.github.com/repos/$OWNER_REPO/pulls?head=$(echo $OWNER_REPO | cut -d/ -f1):$BRANCH&state=open" \
  | jq '.[0] | {number, title, url: .html_url, headRefName: .head.ref}'
```

**Validation:** if no PR is found, ask the user to pass the URL explicitly.

### 2. Authenticate

Verify the user is authenticated:
```bash
gh auth status
```

Extract the current user's login from the output. If not authenticated, tell the user to run `gh auth login`.

### 3. Fetch All Review Comments

Use GraphQL to fetch:
- General review comments (review-level feedback)
- Inline code-review comments (diff threads)

See `references/fetch-comments.md` for the full GraphQL queries and curl fallbacks.

**Result:** a list of all comments on the PR, each with author, body, file, line, and resolution status.

### 4. Filter Comments by Current User

Keep only comments where `author.login == CURRENT_USER`.

**Result:** a list of comments authored by the reviewer.

### 5. Check Resolution Status

For each comment:
- **General review comments:** check `review.state`. If `CHANGES_REQUESTED`, mark as unresolved.
- **Inline code comments:** check `reviewThread.isResolved`. If `false`, mark as unresolved.

**Summary:** count resolved vs. unresolved.

### 6. Decision Gate

**If all comments are resolved (or the user has 0 comments):**
- Proceed to step 7 (approve)

**If any comments are unresolved:**
- Display them to the user (file, line, snippet)
- Stop without approving
- Suggest: "Resolve these threads or contact the author before approving"

### 7. Approve the PR

1. Approve via:
   ```bash
   gh pr review <PR_NUMBER> --approve
   ```

2. Post a confirmation comment:
   ```bash
   gh api repos/:owner/:repo/issues/PR_NUMBER/comments \
     -X POST -f body="All review comments resolved ✅"
   ```

3. Confirm to the user:
   ```
   ✅ PR #123 approved
   💬 Comment added: "All review comments resolved ✅"
   ```

## Error Handling

| Error | Action |
|-------|--------|
| PR not found | Ask for explicit URL |
| Not authenticated | Suggest `gh auth login` |
| GraphQL query fails (TLS) | Retry via curl API fallback |
| Approval fails | Show error and stop |
| Comment post fails | Show error but PR is approved anyway |

## Success Criteria

✅ Identify the PR from branch or argument  
✅ Fetch only the current user's review comments  
✅ Correctly identify resolved vs. unresolved threads  
✅ Approve PR + post confirmation if all resolved  
✅ Show unresolved comments and stop if any remain  
✅ Handle TLS errors gracefully with curl fallback  
✅ Clear error messages for auth/not-found cases  
