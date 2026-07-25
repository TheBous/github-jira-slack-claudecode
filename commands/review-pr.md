---
description: Review a GitHub PR — identify PR and Jira ticket, switch to isolated worktree, delegate analysis to ce-code-review (report-only), present findings by severity, and submit structured review with inline comments and suggested fixes
---

## Goal

Act as the reviewer on a GitHub PR: identify the PR and linked Jira ticket, switch to an isolated worktree, delegate analysis to `ce-code-review` in report-only mode (no fixes applied), present findings by severity (P0–P3), ask the user which to post, and submit a structured review via `gh` with inline comments and committable suggestions.

## Steps

### 1. Identify the PR and Jira ticket

Use `gh pr view` to get PR metadata (same pattern as other jira-git-sync workflows):
```bash
gh pr view --json number,title,body,author,headRefName,baseRefName,additions,deletions,changedFiles
```

Extract the branch name and check if it matches a Jira key pattern (e.g., `DC-123`). If it does, fetch the ticket via the `getJiraIssue` MCP tool or `jq` from the Jira API, using the same credentials pattern as `references/jira-transition.md`.

If no PR is open on the current branch, ask the user to pass the PR number or URL explicitly.

### 2. Gather full context

Get the diff and head commit SHA:
```bash
gh pr diff <NUMBER>
gh pr view <NUMBER> --json headRefOid --jq '.headRefOid'
```

Read full files (not just hunks) for lines touched by the diff. Always read the complete file when the diff doesn't show function bodies, type definitions, or imports.

### 3. Ask about review depth

Ask the user whether they want a shallow or deep review:

```
Would you prefer a shallow or deep review?

• **Shallow** (default): Correctness + project standards only
• **Deep**: Full team review (correctness, testing, security, maintainability, adversarial, reliability, API-contract, data-migration, learnings, agent-native)
```

Wait for the user's choice. Default to shallow if they don't specify.

### 4. Switch to isolated worktree

Enter a fresh worktree isolated from the main branch, using the `worktrunk` pattern:
```bash
wt switch pr:${PR_NUMBER}
```

This creates a dedicated worktree for the review. **Do not create another worktree inside ce-code-review** — the next step will know one already exists.

### 5. Delegate analysis to ce-code-review

Invoke the `ce-code-review` skill in `mode:agent` (report-only JSON output):

**If shallow review was chosen:**
```
mode:agent <NUMBER>
```

**If deep review was chosen:**
```
mode:agent depth:full <NUMBER>
```

Pass the context that a worktree has already been created in step 4, so ce-code-review does NOT create a new one — it will use the existing isolated worktree.

ce-code-review returns structured findings:
- `title` — brief description
- `severity` — P0, P1, P2, P3 (internal codes)
- `file` and `line` — exact location
- `pre_existing` — whether the issue existed before this PR
- `suggested_fix` — optional code-level suggestion

**CRITICAL: Transform severity codes before presenting to the user or writing to GitHub:**
- `P0` → 🔴 "Must fix before merge"
- `P1` → 🟡 "Recommended"
- `P2` → 🟢 "Fix if straightforward"
- `P3` → ⚪ "Discretionary" (discard from public comments, mention only in verdict to user)

**Never write P0/P1/P2/P3 in any GitHub comment or presentation.** All public comments must use the human-readable labels.

**Scope discipline**: do not flag pre-existing issues as blocking this PR. Note them separately for the user's awareness.

### 6. Present the verdict to the user

Group findings by severity and present them in order (P0 → P3):

```
## Code Review: PR #N — <title>

**Jira**: <TICKET-123> — <ticket summary>
**Author**: @<author>
**+<additions> / -<deletions> lines**

---

### Findings by Severity

#### 🔴 P0 (Must fix before merge)
**Issue 1 — <short headline>**
`<file>`:<line>
<explanation + why it matters>
<suggested_fix if available>

#### 🟡 P1 (Recommended)
**Issue 2 — <short headline>**
...

#### 🟢 P2 (Fix if straightforward)
...

#### ⚪ P3 (Discretionary)
...

---

**Note**: <count> total findings. P0 issues require changes from the author before merge.

Which findings would you like me to post as a review? (e.g., "P0 and P1 only", "all", "none")
```

Wait for user confirmation. Do not submit without it.

### 7. Submit the top-level review

After the user confirms, post the main review comment on GitHub first. This is a **summary comment** that:
- Explains the focus and scope of the review
- Lists all findings grouped by severity
- Points to the detailed sub-comments (threads) for each issue

Structure of the main review comment:

```bash
gh pr review <NUMBER> --request-changes --body "$(cat <<'EOF'
## Review — <title>

<2-3 sentences explaining the focus and scope of the review>

For example:
"Focused on data integrity, concurrency invariants, and lifecycle constraints. Each thread proposes a correction direction and suggests a regression test. See detailed comments below grouped by severity."

---

### 🔴 Must fix before merge
- <headline> — see inline comment on `<path>:<line>`
- <headline> — see inline comment on `<path>:<line>`

### 🟡 Recommended  
- <headline> — see inline comment on `<path>:<line>`

### 🟢 Fix if straightforward
- <headline> — see inline comment on `<path>:<line>`
EOF
)"
```

**When to use each flag:**
- If there are "Must fix before merge" findings → use `--request-changes`
- If only "Recommended" or "Fix if straightforward" → use `--comment`
- If P3 (Discretionary) only → omit from review, note them in the user conversation only

**Important structure rules**:
1. Main review body is **summary + index only** — no technical details
2. All technical details live in **sub-comments** (step 8)
3. Never write P0, P1, P2, P3 in GitHub; always use human-readable labels
4. Each main bullet in the review body links to its corresponding inline thread

### 8. Add detailed sub-comments for each finding

For each finding (grouped by severity in the main review), post a **detailed inline comment** that explains:
1. The problem and affected code
2. Why it matters (invariant, constraint, or risk)
3. Suggested fix direction
4. Recommended regression test (when applicable)

**Structure of each sub-comment:**

```bash
gh api repos/:owner/:repo/pulls/<NUMBER>/comments \
  --method POST \
  --field commit_id='<sha>' \
  --field path='<file>' \
  --field side='RIGHT' \
  --field line=<line> \
  --field body="$(cat <<'EOF'
🔴 **Must fix before merge** | 🟡 **Recommended** | 🟢 **Fix if straightforward**

**Issue headline**

Affected code:
\`\`\`
<snippet of the problematic code>
\`\`\`

**Why this matters:**
<Explain the invariant, constraint, or risk. What could break? Data loss? Race condition? Contract violation?>

**Suggested fix:**
<Direction/approach for correction. Code snippets if trivial one-liner:>
\`\`\`suggestion
<replacement>
\`\`\`

Or if fix requires coordinated changes:
\`\`\`
<pseudocode or sketch of the fix>
\`\`\`

**Regression test:**
<Suggest a test that would catch this if it regresses. Example: "Test concurrent saves of the status; verify confirmed_at is set atomically", or "Add integration test for draft→new transition with stale version">
EOF
)"
```

**Key principles for sub-comments**:
- Each comment is a **separate thread** addressing one finding
- Comments are **self-contained** — they explain the problem fully without requiring the main review body
- Severity emoji at the top matches the finding's severity
- Always include the "Why this matters" section to justify the concern
- When a suggested fix is one-line and straightforward, use `\`\`\`suggestion\`\`\` block for one-click apply
- For complex fixes, describe the approach in prose + pseudocode (no suggestion block)

**Anchoring rules**:
- `commit_id` = PR's head commit SHA
- `side='RIGHT'` for added/modified lines, `side='LEFT'` for deleted lines
- `line` = actual file line number, not diff position
- Only comment on lines within the diff hunks

**Decision rules**:
- Trivial one-liner fix → committable `suggestion` block
- Fix needing coordinated changes → code snippet + explanation, no `suggestion`
- Fix needing new tests → code snippet with test code + explanation
- Generated artifacts (migrations, lockfiles) → suggest the *source*, note to regenerate

### 9. Optional Jira comment

If the branch matched a Jira key in step 1, ask:
```
Vuoi che lasci un commento su Jira con l'esito della review?
```

If yes, follow `references/jira-transition.md` for the comment call only — **do not transition the ticket**, just post:
```
🔍 Review PR #<NUMBER>: <Approved|Changes requested|Commented> — <PR_URL>
```

### 10. Confirmation

Show the user:
- Review submitted: `<Approved|Changes requested|Commented>`
- Inline comments posted: `<count>`
- Jira comment: yes/no

## Style for review prose

**All public review content on GitHub must be in English** — regardless of the language used in your conversation with the user.

- **Step 6 (Verdict to user)** — present in the language the user used
- **Step 7 (Top-level review body)** — **English only**. Concise index grouped by severity, pointing to inline threads. No explanation duplication.
- **Step 8 (Inline comments)** — **English only**. Include the affected code snippet, explanation, and `suggested_fix` (if applicable).
- **Step 9 (Jira comment, if applicable)** — **English only**. Brief status update.

For all GitHub comments: be concise (issue, why it matters, affected code, fix — in that order), no emojis unless the team already uses them in code reviews.

## Common pitfalls to avoid

- Don't trust the diff for line numbers — use the actual file at the head SHA.
- Don't suggest a change without reading the full function/type definition.
- Don't post inline comments on lines outside the diff hunks.
- Don't flag "violations" before checking existing patterns in the same file.
- Don't duplicate explanation between the top-level body and inline comments — detail goes inline.
- Remember: P0 → PR blocks on author changes, P1/P2 → advice, P3 → omit entirely.
