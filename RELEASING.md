# Release Process

This document describes how to release new versions of the PubMed MCP Server to PyPI.

## Prerequisites

1. Install build tools:

   ```bash
   pip install build twine
   ```

2. Set up PyPI credentials:
   - Create account at [PyPI](https://pypi.org/account/register/)
   - Enable 2FA (required)
   - Generate API token at [PyPI Token Settings](https://pypi.org/manage/account/token/)
   - Store in `~/.pypirc`:

   ```ini
   [pypi]
   username = __token__
   password = pypi-your-api-token-here

   [testpypi]
   username = __token__
   password = pypi-your-testpypi-token-here
   ```

## Release Methods

### Method 1: Interactive Release Script (Recommended)

Use the interactive release script for full control:

```bash
./release.sh
```

This script will:

1. Check git status and branch
1. Prompt for version bump type (patch/minor/major) or custom version
1. Update `pyproject.toml` with new version
1. Auto-generate changelog from git commits (supports conventional commits)
1. Show preview and optionally open editor for manual adjustments
1. Build the package
1. Run package checks
1. Commit changes and create git tag
1. Optionally upload to TestPyPI or PyPI
1. Optionally push to remote

The script automatically categorizes commits using conventional commit format:

- `feat:` → Added section
- `fix:` → Fixed section
- `refactor:`, `perf:`, `style:`, `docs:`, `chore:` → Changed section

### Method 2: Quick Patch Release

For quick bug fix releases with auto-generated changelog:

```bash
./quick-release.sh
```

Or with a custom description:

```bash
./quick-release.sh "Fix NCBI API timeout handling"
```

This automatically:

- Increments patch version
- Generates changelog from commits (or uses provided description)
- Builds package
- Creates commit and tag

Then manually:

```bash
python -m twine upload dist/*
git push && git push --tags
```

### Method 3: Manual Release

1. Update version in `pubmed/pyproject.toml`:

   ```toml
   version = "1.2.3"
   ```

1. Update `CHANGELOG.md`:

   ```markdown
   ## [1.2.3] - 2024-01-15

   ### Added
   - New feature description

   ### Fixed
   - Bug fix description
   ```

1. Build package:

   ```bash
   cd pubmed
   rm -rf dist/ build/ *.egg-info
   python -m build
   ```

1. Check package:

   ```bash
   python -m twine check dist/*
   ```

1. Upload to TestPyPI (optional):

   ```bash
   python -m twine upload --repository testpypi dist/*
   ```

1. Test installation:

   ```bash
   pip install --index-url https://test.pypi.org/simple/ pubmed-mcp-server==1.2.3
   ```

1. Upload to PyPI:

   ```bash
   python -m twine upload dist/*
   ```

1. Commit and tag:

   ```bash
   git add pubmed/pyproject.toml CHANGELOG.md
   git commit -m "chore: release version 1.2.3"
   git tag -a v1.2.3 -m "Release version 1.2.3"
   git push && git push --tags
   ```

## Version Numbering

Follow [Semantic Versioning](https://semver.org/):

- **MAJOR** (1.0.0 → 2.0.0): Breaking changes (e.g., tool renamed, response format changed)
- **MINOR** (1.0.0 → 1.1.0): New tools or features, backward compatible
- **PATCH** (1.0.0 → 1.0.1): Bug fixes, backward compatible

## Changelog Format

The release scripts automatically generate changelog entries from git commits. For best results, use [Conventional Commits](https://www.conventionalcommits.org/):

```bash
# Features (→ Added section)
git commit -m "feat: add batch article fetch tool"
git commit -m "feat(search): support MeSH term expansion"

# Bug fixes (→ Fixed section)
git commit -m "fix: handle NCBI rate limit errors gracefully"
git commit -m "fix(parser): extract nested abstract sections"

# Other changes (→ Changed section)
git commit -m "refactor: simplify XML parsing logic"
git commit -m "docs: update setup instructions"
git commit -m "chore: update httpx dependency"
```

Manual changelog format follows [Keep a Changelog](https://keepachangelog.com/):

```markdown
## [Version] - YYYY-MM-DD

### Added
- New features

### Changed
- Changes in existing functionality

### Deprecated
- Soon-to-be removed features

### Removed
- Removed features

### Fixed
- Bug fixes

### Security
- Security fixes
```

## Testing Before Release

1. Test local installation:

   ```bash
   cd pubmed
   pip install -e .
   pubmed-mcp
   ```

1. Test with FastMCP:

   ```bash
   fastmcp run server.py
   ```

1. Verify tools respond (use an MCP client or test script):

   ```bash
   # Quick smoke test — search should return results
   python -c "from server import search_pubmed; print(search_pubmed('zinc supplementation', 3))"
   ```

## Post-Release

1. Verify PyPI page: [suppevo-pubmed-mcp on PyPI](https://pypi.org/project/suppevo-pubmed-mcp/)

1. Test installation:

   ```bash
   pip install suppevo-pubmed-mcp
   pubmed-mcp
   ```

1. Test with uvx (no install needed):

   ```bash
   uvx suppevo-pubmed-mcp
   ```

1. Create GitHub release (optional):
   - Go to [Releases](https://github.com/gomezmera/suppevo-pubmed-mcp/releases)
   - Click "Draft a new release"
   - Select the tag
   - Copy changelog entry
   - Publish release

## Troubleshooting

### Upload fails with "File already exists"

- You cannot overwrite a version on PyPI
- Increment version and try again

### Authentication fails

- Check `~/.pypirc` has correct token
- Verify token hasn't expired
- Try re-generating token

### Package check fails

- Review error messages
- Common issues: missing README, invalid metadata
- Fix and rebuild

### Git tag already exists

```bash
# Delete local tag
git tag -d v1.2.3

# Delete remote tag
git push origin :refs/tags/v1.2.3
```

## Rollback

If you need to rollback a release:

1. You cannot delete versions from PyPI (by design)
1. Release a new patch version with fixes
1. Mark the problematic version as "yanked" on PyPI (prevents new installs)

## CI/CD (Future)

Consider setting up GitHub Actions for automated releases:

- Trigger on git tags
- Run tests
- Build package
- Upload to PyPI
- Create GitHub release
