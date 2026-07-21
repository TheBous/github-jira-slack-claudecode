---
description: Run naming-convention, security, and library-best-practices sub-agents in parallel over the current diff and present the three reports side by side
---

## Goal

Triple-check pending changes along three independent axes — each run by its own sub-agent so none pollutes another's context:

- **Naming** — does the diff follow this repo's naming conventions?
- **Security** — does the diff introduce a security issue?
- **Libraries** — does the diff follow the current best practices of the third-party libraries it touches?

## Steps

### 1. Pin the diff scope

If the user gave a fixed point (branch, commit, or tag), diff against it:
```bash
git diff <fixed-point>...HEAD
```
Otherwise default to uncommitted/local changes:
```bash
git diff HEAD
```
Confirm the diff is non-empty before continuing — an empty diff means nothing to judge, say so and stop.

### 2. Spawn three sub-agents in parallel

Send **one message with three `Agent` tool calls** (subagent_type `general-purpose`), each given the diff from step 1. Never let a sub-agent re-derive the diff scope itself.

**Naming sub-agent** — give it the diff plus `references/naming-conventions-code.md` (always), `references/naming-conventions-db.md` (if the diff touches DB schema/migrations), and `references/naming-conventions-nextjs.md` (if it touches a Next.js App Router file) — all in the plugin root. Brief: "Report every naming/casing/suffix violation against these rules, citing file:line and the exact rule broken. Before flagging, check for a library-mandated name or an existing sibling pattern in the same file. Under 300 words."

**Security sub-agent** — give it the diff/commit range. Brief: "Invoke the `security-review` skill scoped to this diff and relay its findings verbatim, with severity. If the skill isn't available, say so explicitly instead of improvising a check."

**Libraries sub-agent** — give it the diff. Brief: "List every third-party library touched (new import, changed call, or manifest/lockfile bump). For each, resolve it via context7 (`resolve-library-id` then `query-docs`) and check the diff's usage against the current docs. Report per library: followed / violated best practice, quoting the doc excerpt that supports the verdict. If a library has no context7 match, say so — don't judge it from memory. If no third-party library is touched, report that and stop. Under 300 words."

### 3. Present the verdict

Show the three reports under separate headings, verbatim or lightly cleaned:

```
## Naming
<naming sub-agent report>

## Security
<security sub-agent report>

## Libraries
<libraries sub-agent report>
```

Do **not** merge or rerank findings across axes — a naming nit and a security hole aren't comparable severities; keep each axis's own worst finding visible on its own line.

### 4. Optional Jira comment

If the current branch matches a Jira key (pattern `[A-Za-z]+-[0-9]+`), ask the user:
```
Vuoi che lasci un commento su Jira con l'esito della review?
```
If yes, follow `references/jira-transition.md` (in the plugin root) for the comment call only — never pass a transition ID, this step never changes ticket status.

## Common pitfalls to avoid

- Don't skip the Libraries axis silently — report "no external libraries touched" if that's the case.
- Don't fall back to an inline security check if the `security-review` skill is missing — report the gap instead.
- Don't flag a naming "violation" before checking for a library-mandated name or an existing sibling pattern in the same file.
- Don't judge a library's API usage from training-data memory — context7 docs are the source of truth here.
