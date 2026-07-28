// jira-git-sync — OpenCode plugin.
//
// Dynamically discovers and registers jira-git-sync commands from .opencode/command/
// and registers the skills directory. Self-locating via import.meta.url so paths
// work across hosts without symlinks or installation scripts.
//
// Add to opencode.json:
//   { "plugin": ["./.opencode/plugins/jira-git-sync.mjs"] }

import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Bridge to CommonJS parser
const require = createRequire(import.meta.url);
const { parseCommandFile } = require('./jira-git-sync-frontmatter.cjs');

export default async ({ client } = {}) => {
  const jiraGitSyncSkillsDir = path.resolve(__dirname, '../../skills');

  return {
    // Register slash commands + skills directory.
    config: async (config) => {
      if (!config.command) config.command = {};
      const commandDir = path.join(__dirname, '..', 'command');
      try {
        for (const file of fs.readdirSync(commandDir).filter((f) => f.endsWith('.md'))) {
          const name = path.basename(file, '.md');
          const parsed = parseCommandFile(path.join(commandDir, file));
          if (parsed) config.command[name] = parsed;
        }
      } catch (e) {}

      config.skills = config.skills || {};
      config.skills.paths = config.skills.paths || [];
      if (!config.skills.paths.includes(jiraGitSyncSkillsDir)) {
        config.skills.paths.push(jiraGitSyncSkillsDir);
      }
    },
  };
};
