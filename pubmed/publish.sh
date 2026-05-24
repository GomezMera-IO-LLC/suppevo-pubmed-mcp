#!/usr/bin/env bash
# publish.sh — Build and publish pubmed-mcp-server to PyPI
#
# Usage:
#   ./publish.sh          # publish to PyPI (production)
#   ./publish.sh --test   # publish to TestPyPI first
#
# Prerequisites:
#   pip install build twine
#   Set TWINE_USERNAME and TWINE_PASSWORD env vars, or use ~/.pypirc
#   For API tokens: TWINE_USERNAME=__token__ TWINE_PASSWORD=pypi-...

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# Check dependencies
command -v python3 >/dev/null 2>&1 || error "python3 is required"
python3 -c "import build" 2>/dev/null || error "python-build not installed. Run: pip install build"
command -v twine >/dev/null 2>&1 || error "twine is required. Run: pip install twine"

# Extract version from pyproject.toml
VERSION=$(python3 -c "
import re
with open('pyproject.toml') as f:
    m = re.search(r'version\s*=\s*\"(.+?)\"', f.read())
    print(m.group(1) if m else 'unknown')
")
info "Publishing pubmed-mcp-server v${VERSION}"

# Clean previous builds
info "Cleaning previous builds..."
rm -rf dist/ build/ *.egg-info pubmed_mcp_server.egg-info/

# Build
info "Building package..."
python3 -m build

# Verify
info "Checking distribution..."
twine check dist/*

# Publish
if [[ "${1:-}" == "--test" ]]; then
    info "Uploading to TestPyPI..."
    twine upload --repository testpypi dist/*
    echo ""
    info "Published to TestPyPI!"
    info "Install with: pip install -i https://test.pypi.org/simple/ pubmed-mcp-server"
else
    echo ""
    warn "About to publish v${VERSION} to PyPI (production)."
    read -rp "Continue? [y/N] " confirm
    if [[ "$confirm" != [yY] ]]; then
        info "Aborted."
        exit 0
    fi
    info "Uploading to PyPI..."
    twine upload dist/*
    echo ""
    info "Published pubmed-mcp-server v${VERSION} to PyPI!"
    info "Install with: pip install pubmed-mcp-server"
fi
