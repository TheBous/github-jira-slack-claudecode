# Agent Portability

jira-git-sync is an agent-portable workflow bundle. `commands/*.md` hold the
actual workflow logic (11 files, one per workflow); host-specific files are
thin adapters that make those workflows loadable and slash-invocable in a
given agent.

## Supported Adapters

| Host | Files | Manual invocation |
|------|-------|--------------------|
| Claude Code | `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `commands/` | `/jira-git-sync:<workflow>` (native plugin slash command, e.g. `/jira-git-sync:new-branch DC-443`) |
| OpenCode | `SKILL.md`, `.opencode/commands/`, `scripts/install-opencode.sh` | `/jira-<workflow>` after running the install script once (e.g. `/jira-new-branch DC-443`) |
| Generic agents (Codex, any AGENTS.md-reading host) | `AGENTS.md` | Ask the agent by name: "read `commands/new-branch.md` and run it for DC-443" |

## Adapter Rule

Keep adapters thin. Every adapter points at the same `commands/*.md` files —
no workflow logic is duplicated per host. `references/*.md` (Jira transition
pattern, test runner, naming conventions) and `scripts/helpers.sh` are shared
the same way; only Claude Code and OpenCode adapters differ in how they expose
the `/` entry point.

- **Claude Code**: `commands/*.md` is the plugin's native command directory —
  each file becomes `/jira-git-sync:<filename>` automatically, no extra step.
- **OpenCode**: `.opencode/commands/*.md` are one-line wrappers ("use the
  jira-git-sync skill, run workflow X") that OpenCode auto-discovers from
  `.opencode/commands/` (project) or `~/.config/opencode/commands/` (global,
  installed by `scripts/install-opencode.sh`). `SKILL.md` is the router the
  wrapper hands off to; it reads the matching `commands/<name>.md` on demand.
- **Everything else**: `AGENTS.md` is the compact always-on instruction set —
  table of workflows + pointer to `commands/*.md` — for hosts that read
  `AGENTS.md` but have no slash-command or skill system of their own.

## Portable Behavior

All 11 workflows live in `commands/*.md` and are identical across hosts:
`setup`, `new-branch`, `cook`, `create-pr`, `review-pr`, `address-review`,
`judge`, `merge-pr`, `tag`, `create-doc`, `update-doc`. Credentials
(`${CLAUDE_PLUGIN_DATA:-$HOME/.config/jira-git-sync}/.env`) and the Atlassian
MCP server configuration are shared across every host — set up once, works
everywhere.
