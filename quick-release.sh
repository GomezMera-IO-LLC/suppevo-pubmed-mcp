#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# PubMed MCP Server — Quick Patch Release
# Usage: ./quick-release.sh [optional description]
# ─────────────────────────────────────────────────────────────────────────────

PACKAGE_DIR="pubmed"
PYPROJECT="$PACKAGE_DIR/pyproject.toml"
CHANGELOG="CHANGELOG.md"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

info() { echo -e "${BLUE}ℹ${NC} $*"; }
ok()   { echo -e "${GREEN}✓${NC} $*"; }
error(){ echo -e "${RED}✗${NC} $*"; exit 1; }

[[ -f "$PYPROJECT" ]] || error "Run from repository root"

# Get current version and bump patch
CURRENT_VERSION=$(grep -m1 'version' "$PYPROJECT" | sed 's/.*"\(.*\)".*/\1/')
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"
NEW_VERSION="$MAJOR.$MINOR.$((PATCH + 1))"

info "Bumping $CURRENT_VERSION → $NEW_VERSION"

# Generate changelog entry
DATE=$(date +%Y-%m-%d)
DESCRIPTION="${1:-}"

if [[ -z "$DESCRIPTION" ]]; then
    # Auto-generate from commits since last tag
    LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    if [[ -n "$LAST_TAG" ]]; then
        DESCRIPTION=$(git log "$LAST_TAG"..HEAD --pretty=format:"- %s" 2>/dev/null | head -20)
    else
        DESCRIPTION=$(git log --pretty=format:"- %s" -10 2>/dev/null)
    fi
else
    DESCRIPTION="- $DESCRIPTION"
fi

CHANGELOG_ENTRY="## [$NEW_VERSION] - $DATE\n\n### Changed\n$DESCRIPTION"

# Update version
sed -i '' "s/version = \"$CURRENT_VERSION\"/version = \"$NEW_VERSION\"/" "$PYPROJECT"
ok "Updated version in $PYPROJECT"

# Update changelog
if [[ -f "$CHANGELOG" ]]; then
    TMPFILE=$(mktemp)
    awk -v entry="$(echo -e "$CHANGELOG_ENTRY")" '
        /^# / && !done { print; print ""; print entry; done=1; next }
        { print }
    ' "$CHANGELOG" > "$TMPFILE"
    mv "$TMPFILE" "$CHANGELOG"
else
    echo -e "# Changelog\n\n$CHANGELOG_ENTRY" > "$CHANGELOG"
fi
ok "Updated $CHANGELOG"

# Build
info "Building..."
cd "$PACKAGE_DIR"
rm -rf dist/ build/ *.egg-info
python3 -m build
cd ..
ok "Package built"

# Check
python3 -m twine check "$PACKAGE_DIR/dist/*"
ok "Package checks passed"

# Commit and tag
git add "$PYPROJECT" "$CHANGELOG"
git commit -m "chore: release version $NEW_VERSION"
git tag -a "v$NEW_VERSION" -m "Release version $NEW_VERSION"
ok "Committed and tagged v$NEW_VERSION"

echo ""
ok "Quick release $NEW_VERSION ready!"
info "To publish:"
echo "  python3 -m twine upload $PACKAGE_DIR/dist/*"
echo "  git push && git push --tags"
