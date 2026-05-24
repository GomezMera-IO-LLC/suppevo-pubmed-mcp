#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# PubMed MCP Server — Interactive Release Script
# ─────────────────────────────────────────────────────────────────────────────

PACKAGE_DIR="pubmed"
PYPROJECT="$PACKAGE_DIR/pyproject.toml"
CHANGELOG="CHANGELOG.md"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()  { echo -e "${BLUE}ℹ${NC} $*"; }
ok()    { echo -e "${GREEN}✓${NC} $*"; }
warn()  { echo -e "${YELLOW}⚠${NC} $*"; }
error() { echo -e "${RED}✗${NC} $*"; exit 1; }

# ─────────────────────────────────────────────────────────────────────────────
# Pre-flight checks
# ─────────────────────────────────────────────────────────────────────────────

command -v python3 >/dev/null 2>&1 || error "python3 not found"
command -v git >/dev/null 2>&1 || error "git not found"

# Check we're in the repo root
[[ -f "$PYPROJECT" ]] || error "Run this script from the repository root"

# Check git status
if [[ -n "$(git status --porcelain)" ]]; then
    warn "Working directory has uncommitted changes:"
    git status --short
    echo ""
    read -rp "Continue anyway? (y/N) " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || exit 0
fi

# Current version
CURRENT_VERSION=$(grep -m1 'version' "$PYPROJECT" | sed 's/.*"\(.*\)".*/\1/')
info "Current version: ${GREEN}$CURRENT_VERSION${NC}"

# ─────────────────────────────────────────────────────────────────────────────
# Version bump
# ─────────────────────────────────────────────────────────────────────────────

IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

echo ""
echo "Select version bump:"
echo "  1) patch  → $MAJOR.$MINOR.$((PATCH + 1))"
echo "  2) minor  → $MAJOR.$((MINOR + 1)).0"
echo "  3) major  → $((MAJOR + 1)).0.0"
echo "  4) custom"
echo ""
read -rp "Choice [1-4]: " choice

case "$choice" in
    1) NEW_VERSION="$MAJOR.$MINOR.$((PATCH + 1))" ;;
    2) NEW_VERSION="$MAJOR.$((MINOR + 1)).0" ;;
    3) NEW_VERSION="$((MAJOR + 1)).0.0" ;;
    4) read -rp "Enter version: " NEW_VERSION ;;
    *) error "Invalid choice" ;;
esac

info "New version: ${GREEN}$NEW_VERSION${NC}"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Generate changelog
# ─────────────────────────────────────────────────────────────────────────────

LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
DATE=$(date +%Y-%m-%d)

ADDED=""
FIXED=""
CHANGED=""

if [[ -n "$LAST_TAG" ]]; then
    COMMITS=$(git log "$LAST_TAG"..HEAD --pretty=format:"%s" 2>/dev/null || echo "")
else
    COMMITS=$(git log --pretty=format:"%s" 2>/dev/null || echo "")
fi

while IFS= read -r msg; do
    [[ -z "$msg" ]] && continue
    if [[ "$msg" =~ ^feat ]]; then
        desc=$(echo "$msg" | sed 's/^feat[^:]*: *//')
        ADDED="${ADDED}\n- ${desc}"
    elif [[ "$msg" =~ ^fix ]]; then
        desc=$(echo "$msg" | sed 's/^fix[^:]*: *//')
        FIXED="${FIXED}\n- ${desc}"
    else
        desc=$(echo "$msg" | sed 's/^[a-z]*[^:]*: *//')
        CHANGED="${CHANGED}\n- ${desc}"
    fi
done <<< "$COMMITS"

CHANGELOG_ENTRY="## [$NEW_VERSION] - $DATE"
[[ -n "$ADDED" ]] && CHANGELOG_ENTRY="${CHANGELOG_ENTRY}\n\n### Added${ADDED}"
[[ -n "$FIXED" ]] && CHANGELOG_ENTRY="${CHANGELOG_ENTRY}\n\n### Fixed${FIXED}"
[[ -n "$CHANGED" ]] && CHANGELOG_ENTRY="${CHANGELOG_ENTRY}\n\n### Changed${CHANGED}"

echo -e "\n${BLUE}── Changelog Preview ──${NC}"
echo -e "$CHANGELOG_ENTRY"
echo -e "${BLUE}───────────────────────${NC}\n"

read -rp "Edit changelog in editor? (y/N) " edit_choice
if [[ "$edit_choice" =~ ^[Yy]$ ]]; then
    TMPFILE=$(mktemp)
    echo -e "$CHANGELOG_ENTRY" > "$TMPFILE"
    ${EDITOR:-vim} "$TMPFILE"
    CHANGELOG_ENTRY=$(cat "$TMPFILE")
    rm -f "$TMPFILE"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Apply changes
# ─────────────────────────────────────────────────────────────────────────────

# Update pyproject.toml version
sed -i '' "s/version = \"$CURRENT_VERSION\"/version = \"$NEW_VERSION\"/" "$PYPROJECT"
ok "Updated $PYPROJECT → $NEW_VERSION"

# Update CHANGELOG.md
if [[ -f "$CHANGELOG" ]]; then
    # Insert after the first heading
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

# ─────────────────────────────────────────────────────────────────────────────
# Build
# ─────────────────────────────────────────────────────────────────────────────

info "Building package..."
cd "$PACKAGE_DIR"
rm -rf dist/ build/ *.egg-info
python3 -m build
cd ..
ok "Package built"

# Check
info "Checking package..."
python3 -m twine check "$PACKAGE_DIR/dist/*"
ok "Package checks passed"

# ─────────────────────────────────────────────────────────────────────────────
# Git commit and tag
# ─────────────────────────────────────────────────────────────────────────────

echo ""
read -rp "Commit and tag? (Y/n) " commit_choice
if [[ ! "$commit_choice" =~ ^[Nn]$ ]]; then
    git add "$PYPROJECT" "$CHANGELOG"
    git commit -m "chore: release version $NEW_VERSION"
    git tag -a "v$NEW_VERSION" -m "Release version $NEW_VERSION"
    ok "Committed and tagged v$NEW_VERSION"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Upload
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo "Upload to:"
echo "  1) TestPyPI (recommended first)"
echo "  2) PyPI (production)"
echo "  3) Skip upload"
echo ""
read -rp "Choice [1-3]: " upload_choice

case "$upload_choice" in
    1)
        python3 -m twine upload --repository testpypi "$PACKAGE_DIR/dist/*"
        ok "Uploaded to TestPyPI"
        info "Test with: pip install --index-url https://test.pypi.org/simple/ pubmed-mcp-server==$NEW_VERSION"
        ;;
    2)
        python3 -m twine upload "$PACKAGE_DIR/dist/*"
        ok "Uploaded to PyPI"
        info "Install with: pip install pubmed-mcp-server==$NEW_VERSION"
        ;;
    3)
        info "Skipped upload. Run manually:"
        echo "  python3 -m twine upload $PACKAGE_DIR/dist/*"
        ;;
esac

# ─────────────────────────────────────────────────────────────────────────────
# Push
# ─────────────────────────────────────────────────────────────────────────────

echo ""
read -rp "Push to remote? (Y/n) " push_choice
if [[ ! "$push_choice" =~ ^[Nn]$ ]]; then
    git push && git push --tags
    ok "Pushed to remote"
fi

echo ""
ok "Release $NEW_VERSION complete! 🎉"
