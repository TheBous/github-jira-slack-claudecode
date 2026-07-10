---
description: Review a GitHub PR — analyze the diff in full file context, present a verdict, then submit a structured review with inline comments
---

## Goal

Act as the reviewer on a GitHub PR: gather the diff and full file context, analyze it against correctness/test-coverage/naming-convention checks, present a concise verdict to the user, and — only after confirmation — submit a structured review via `gh` with inline comments and committable suggestions.

## Steps

### 1. Identify the PR

If the user passed a PR number or URL, use it. Otherwise detect it from the current branch:
```bash
gh pr view --json number,title,body,author,headRefName,baseRefName,additions,deletions,changedFiles 2>/dev/null
```

**TLS fallback**:
```bash
OWNER_REPO=$(git remote get-url origin | sed -E 's#.*[:/]([^/]+/[^/]+)(\.git)?$#\1#')
BRANCH=$(git branch --show-current)
curl -sf -H "Authorization: Bearer $(gh auth token)" \
  "https://api.github.com/repos/$OWNER_REPO/pulls?head=$(echo $OWNER_REPO | cut -d/ -f1):$BRANCH&state=open" \
  | jq '.[0] | {number, title, body, author: .user.login, headRefName: .head.ref, baseRefName: .base.ref, additions, deletions, changedFiles: .changed_files}'
```

If there's no open PR for the current branch, ask the user to pass the number or URL explicitly.

### 2. Gather full context

Get the diff and the head commit SHA (needed for inline comments):
```bash
gh pr diff <NUMBER>
gh pr view <NUMBER> --json headRefOid --jq '.headRefOid'
```

**TLS fallback**:
```bash
curl -sf -H "Authorization: Bearer $(gh auth token)" -H "Accept: application/vnd.github.v3.diff" \
  "https://api.github.com/repos/$OWNER_REPO/pulls/<NUMBER>"
curl -sf -H "Authorization: Bearer $(gh auth token)" \
  "https://api.github.com/repos/$OWNER_REPO/pulls/<NUMBER>" | jq -r '.head.sha'
```

**Always read the full file**, not just the diff, when: the change touches a comment that may be inaccurate, the diff doesn't show the function body/type definitions/imports, or you need exact line numbers for inline comments.
```bash
gh api "repos/$OWNER_REPO/contents/<path>?ref=<sha>" --jq '.content' | base64 -d | cat -n
```

**TLS fallback**:
```bash
curl -sf -H "Authorization: Bearer $(gh auth token)" \
  "https://api.github.com/repos/$OWNER_REPO/contents/<path>?ref=<sha>" \
  | jq -r '.content' | base64 -d | cat -n
```

If the branch name matches a Jira key (pattern `[A-Za-z]+-[0-9]+`, case-insensitive, uppercase the match), fetch the ticket's summary and description with the MCP tool `getJiraIssue` — use it as extra context for judging whether the PR actually fixes the stated problem.

### 3. Analyze

Look for, in roughly this order:

1. **Correctness of the core change** — does the fix actually fix the stated problem (per the PR description and, if available, the Jira ticket)?
2. **Migrations** (if SQL) — NULL handling, idempotency, statement ordering (FK repointing before DELETE), index/constraint match between DB and app code
3. **Race conditions / concurrency** — retry loops, conflict fallbacks, READ COMMITTED visibility gaps
4. **Type-system bypasses** — `as unknown as`, `any`, generic narrowing — are they documented and runtime-safe?
5. **Comment accuracy** — comments often outlive the code; check that what they say still matches what the code does (especially after a rename)
6. **Test coverage** — is the new logic actually tested? A mock update that only changes a key in a list does NOT test the dispatch logic behind that key
7. **Semantic precision** — do enum/union values returned in different paths actually mean what they say
8. **Naming conventions** — check every new or renamed identifier against `references/naming-conventions-code.md` (in the plugin root), plus `references/naming-conventions-db.md` for schema/migration changes or `references/naming-conventions-nextjs.md` for Next.js App Router files. Before flagging a violation, check for a library-mandated name or an existing sibling pattern in the same file — an inherited convention isn't a new error.
9. **Edge cases the PR description acknowledges as deferred** — are they really safe to defer?

**Scope discipline**: a finding in code outside the PR's own diff (pre-existing, or arrived via a merge of the base branch) is not a blocking issue on this PR, even if security-relevant — note it separately for the user, don't fold it into the verdict below.

### 4. Present the verdict to the user

```
## Code Review: PR #N — <title>

**<additions> / <deletions> lines**

---

### Overview
2-3 sentences on what the PR does and why.

---

### Analysis
**Issue 1 — <short headline>**
File:line. What's wrong, why it matters.

**Issue 2 — ...**

---

### Verdict
| Area | Status |
|------|--------|
| ... | ✅ / ⚠️ / ❌ |

Do you want me to submit the review?
```

Wait for confirmation. Do not submit without it. If the user asks for changes to the analysis, revise and re-present.

### 5. Submit the top-level review

**Inline-first, no duplication.** The substance of every finding lives in its inline comment (step 6). The top-level body is a *concise index*, grouped by severity, pointing to each inline thread — it must NOT repeat the explanation. Post inline comments first, then this index.

Use `--approve` when there are no blocking issues, `--request-changes` when there are, `--comment` for a purely informational review.

```bash
gh pr review <NUMBER> --request-changes --body "$(cat <<'EOF'
## Review — <title>

Details are in the inline comments; this is just the index.

**Must fix before merge**
- <headline> → see inline on `<path>`.

**Recommended**
- <headline> → suggestion inline on `<path>`.

**Minor**
- <headline> → inline on `<path>`.
EOF
)"
```

**TLS fallback**:
```bash
curl -sf -X POST -H "Authorization: Bearer $(gh auth token)" \
  "https://api.github.com/repos/$OWNER_REPO/pulls/<NUMBER>/reviews" \
  -d "{\"body\":\"<review index body>\",\"event\":\"REQUEST_CHANGES\"}"
# event: "APPROVE" | "REQUEST_CHANGES" | "COMMENT" depending on the verdict
```

Do NOT add a "Verdict" table or a "Verified / not flagged" section to the published body — that prose stays in the step 4 chat with the user.

### 6. Add inline comments

**A) Trivial fix → committable suggestion** (one-click apply from the PR page):
```bash
gh api repos/:owner/:repo/pulls/<NUMBER>/comments \
  --method POST \
  --field commit_id='<sha>' \
  --field path='<file>' \
  --field side='RIGHT' \
  --field line=<line> \
  --field body="$(cat <<'EOF'
Brief explanation of the problem.

\`\`\`suggestion
<replacement code for that line>
\`\`\`
EOF
)" --jq '.html_url'
```

For multi-line replacement, add `--field start_line=<first>` and set `line=<last>`; the `suggestion` block must contain the entire replacement for that line range.

**TLS fallback**:
```bash
curl -sf -X POST -H "Authorization: Bearer $(gh auth token)" \
  "https://api.github.com/repos/$OWNER_REPO/pulls/<NUMBER>/comments" \
  -d "{\"commit_id\":\"<sha>\",\"path\":\"<file>\",\"side\":\"RIGHT\",\"line\":<line>,\"body\":\"<explanation>\\n\\n\`\`\`suggestion\\n<replacement>\\n\`\`\`\"}" \
  | jq -r '.html_url'
```

**B) Non-trivial issue → explanatory comment** (no `suggestion` block, or a code snippet outside `suggestion` for code that goes elsewhere, e.g. tests in a new file). Same endpoint, drop the `suggestion` fence from `body`.

**Anchoring rules**:
- `commit_id` must be the PR's **head** commit SHA at the moment of posting. If the author pushed new commits since step 2, refetch it.
- `side='RIGHT'` for added/modified lines, `side='LEFT'` for deleted lines.
- `line` is the **file line number**, not the diff position.
- Only lines in the unified diff (added, removed, or in a hunk's context) can be commented on. For an unchanged line far from any hunk, fold the point into the top-level review body instead.

**Decision rules**:
- Trivial fix (one line, no type changes, no test updates) → committable `suggestion`.
- Fix needing coordinated changes elsewhere (e.g. an enum value used in a type union) → explanation + code snippet, not a one-click suggestion.
- Fix needing new tests in a new/different file → explanation + code snippet for the test, anchored on the most relevant existing line, no `suggestion` block.
- Change to a generated artifact (a Drizzle migration `.sql`, a lockfile, an auth-generated schema) → put the committable `suggestion` on the *source of truth* and note in the comment to regenerate it. Never one-click-suggest edits to generated files.
- An acknowledged deferred trade-off in the PR description → don't re-flag unless the deferral is unsafe.

### 7. Optional Jira comment

If the branch matched a Jira key in step 2, ask the user:
```
Vuoi che lasci un commento su Jira con l'esito della review?
```

If yes, follow `references/jira-transition.md` (in the plugin root) for the comment call only — **do not pass a `<TRANSITION_ID>`, this step never changes ticket status**, just post:
- `<COMMENT_TEXT>` = `"🔍 Review PR #<NUMBER>: <Approved|Changes requested|Commented> — <PR_URL>"`

### 8. Confirmation

Show the user:
- Review submitted: `<Approved|Changes requested|Commented>`
- Inline comments posted: `<count>`
- Jira: commented (if applicable)

## Style for review prose

- **Top-level review body** in English — a concise index grouped by severity, not a self-contained report.
- **Inline comments** in English. The explanation, rationale, and any `suggestion` live here.
- **Conversation with the user** (step 4) in the language they used.
- Be concise: issue, why it matters, fix — in that order. No emojis in PR comments unless the team already uses them.

## Common pitfalls to avoid

- Don't trust the diff for line numbers — read the file at the head SHA.
- Don't suggest an enum-value change without checking the union definition.
- Don't suggest a SQL change without checking the schema for NOT NULL / FK / index constraints.
- Don't add a comment-only suggestion when the comment is already there — read the existing comment first.
- Don't post inline comments on lines outside the diff hunks.
- Don't flag a naming/type "violation" before checking (1) library-mandated names, (2) sibling patterns already in the same file, (3) the generic convention doc.
- Don't duplicate detail between the top-level body and inline comments — detail goes inline, the body just indexes it.
