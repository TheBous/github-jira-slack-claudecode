#!/bin/bash
# Publish jira-git-sync plugin to all three platforms (npm, Claude Code, Codex)
# Usage: ./scripts/publish-plugin.sh [patch|minor|major]
# Default: patch

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get version type (default: patch)
VERSION_TYPE="${1:-patch}"

# Validate version type
if [[ ! "$VERSION_TYPE" =~ ^(patch|minor|major)$ ]]; then
  echo -e "${RED}❌ Invalid version type: $VERSION_TYPE${NC}"
  echo "Usage: ./scripts/publish-plugin.sh [patch|minor|major]"
  exit 1
fi

echo -e "${BLUE}📦 Publishing jira-git-sync plugin...${NC}\n"

# Step 1: Bump version in package.json (also creates git tag)
echo -e "${BLUE}1. Bumping version ($VERSION_TYPE)...${NC}"
npm version "$VERSION_TYPE"
NEW_VERSION=$(jq -r '.version' package.json)
echo -e "${GREEN}   ✓ Updated to $NEW_VERSION${NC}\n"

# Step 2: Sync version to .claude-plugin/plugin.json
echo -e "${BLUE}2. Syncing version to .claude-plugin/plugin.json...${NC}"
jq ".version = \"$NEW_VERSION\"" .claude-plugin/plugin.json > .claude-plugin/plugin.json.tmp
mv .claude-plugin/plugin.json.tmp .claude-plugin/plugin.json
echo -e "${GREEN}   ✓ Updated .claude-plugin/plugin.json${NC}\n"

# Step 3: Sync version to .codex-plugin/plugin.json
echo -e "${BLUE}3. Syncing version to .codex-plugin/plugin.json...${NC}"
jq ".version = \"$NEW_VERSION\"" .codex-plugin/plugin.json > .codex-plugin/plugin.json.tmp
mv .codex-plugin/plugin.json.tmp .codex-plugin/plugin.json
echo -e "${GREEN}   ✓ Updated .codex-plugin/plugin.json${NC}\n"

# Step 4: Stage version files for commit
echo -e "${BLUE}4. Staging version updates...${NC}"
git add package.json package-lock.json .claude-plugin/plugin.json .codex-plugin/plugin.json
echo -e "${GREEN}   ✓ Staged${NC}\n"

# Step 5: Publish to npm
echo -e "${BLUE}5. Publishing to npm...${NC}"
npm publish --access public
echo -e "${GREEN}   ✓ Published to npm${NC}\n"

# Step 6: Done
echo -e "${GREEN}✅ Done! Published v$NEW_VERSION to:${NC}"
echo -e "${GREEN}   • npm (@lucvalse/jira-git-sync-opencode-plugin)${NC}"
echo -e "${GREEN}   • Claude Code (marketplace)${NC}"
echo -e "${GREEN}   • Codex (marketplace)${NC}\n"
echo -e "${BLUE}Next steps:${NC}"
echo -e "   1. Claude Code: reinstall the plugin or restart"
echo -e "   2. Codex: restart the app"
echo -e "   3. OpenCode: auto-updates on next startup"
