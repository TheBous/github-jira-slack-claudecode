# jira-git-sync OpenCode Plugin

This directory contains the OpenCode plugin for jira-git-sync.

## How it works

- **`plugins/jira-git-sync.mjs`** — Entry point that self-locates via `import.meta.url`. Discovers and registers:
  - Commands from `command/*.md` (dynamically, no symlinks)
  - Skills directory (`skills/`) for skill registration

- **`command/*.md`** — Command definitions with YAML frontmatter

## Zero-setup across hosts

Since the plugin self-locates (finds its own directory, then resolves dependencies relative to itself), this works without:
- Installation scripts
- Symlinks with absolute paths
- Per-host configuration

**On macbook, VPS, or anywhere:** sync the repo, and `opencode.json` loads the plugin with a relative path. The plugin finds everything else from there.

## Configuration

Add to your `opencode.json`:
```json
{
  "plugin": ["./.opencode/plugins/jira-git-sync.mjs"]
}
```

That's it. No `install-opencode.sh` needed.
