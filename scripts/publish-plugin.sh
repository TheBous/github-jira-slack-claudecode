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

# Step 4: Sync version to gemini-extension.json (Antigravity)
echo -e "${BLUE}4. Syncing version to gemini-extension.json (Antigravity)...${NC}"
jq ".version = \"$NEW_VERSION\"" gemini-extension.json > gemini-extension.json.tmp
mv gemini-extension.json.tmp gemini-extension.json
echo -e "${GREEN}   ✓ Updated gemini-extension.json${NC}\n"

# Step 5: Stage version files for commit
echo -e "${BLUE}5. Staging version updates...${NC}"
git add package.json package-lock.json .claude-plugin/plugin.json .codex-plugin/plugin.json gemini-extension.json
echo -e "${GREEN}   ✓ Staged${NC}\n"

# Step 6: Alert user to publish manually (avoid silent 2FA failures)
echo ""
echo -e "${GREEN}✅ Version sync complete! v$NEW_VERSION ready.${NC}"
echo ""
echo -e "${RED}⚠️  MANUAL STEP REQUIRED:${NC}"
echo ""
echo "   Run this command to publish to npm:"
echo ""
echo -e "   ${BLUE}npm publish --access public${NC}"
echo ""
echo "   (This requires 2FA authentication)"
echo ""
echo -e "${BLUE}After npm publish, updates will reach:${NC}"
echo "   • npm (@lucvalse/jira-git-sync-opencode-plugin)"
echo "   • Claude Code (marketplace)"
echo "   • Codex (marketplace)"
echo "   • Antigravity CLI"
echo ""
echo -e "${BLUE}Then in each host:${NC}"
echo "   1. Claude Code: reinstall the plugin or restart"
echo "   2. Codex: restart the app"
echo "   3. OpenCode: auto-updates on next startup"
echo "   4. Antigravity: will pick up the latest version from GitHub"
