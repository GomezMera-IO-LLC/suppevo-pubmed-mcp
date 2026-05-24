# Suppevo PubMed MCP Server

Search and retrieve biomedical literature from PubMed/NCBI directly from Kiro.

## Overview

This MCP server provides tools to search PubMed, fetch article metadata and abstracts, verify citations, and find PMIDs by title. It uses the NCBI E-utilities API under the hood.

## Installation

### Quick Setup (recommended)

Add the following to your `.kiro/settings/mcp.json`:

```json
{
  "mcpServers": {
    "pubmed": {
      "command": "uvx",
      "args": ["suppevo-pubmed-mcp@latest"],
      "env": {
        "NCBI_API_KEY": "your-api-key-here"
      }
    }
  }
}
```

### Getting an NCBI API Key (optional but recommended)

An API key increases your rate limit from 3 requests/sec to 10 requests/sec.

1. Create a free account at https://www.ncbi.nlm.nih.gov/account/
2. Go to https://www.ncbi.nlm.nih.gov/account/settings/
3. Click "Create an API Key" under the API Key Management section
4. Copy the key and add it to the `env` block in your MCP config

Without an API key the server still works, just at a lower rate limit.

### Prerequisites

- Python 3.11 or later
- `uv` / `uvx` installed (see https://docs.astral.sh/uv/getting-started/installation/)

## Available Tools

| Tool | Description |
|------|-------------|
| `search_pubmed` | Search PubMed with a query string. Supports field tags (`[Title]`, `[Author]`, `[Journal]`), boolean operators (`AND`, `OR`, `NOT`), MeSH terms, and date ranges. Returns article summaries. |
| `fetch_article` | Fetch full metadata (title, authors, journal, year, DOI, abstract, volume, issue, pages) for a specific PMID. |
| `fetch_abstract` | Get just the abstract text for a PMID. |
| `verify_citation` | Check if a PMID matches a given title. Returns the actual title and a similarity score. |
| `search_by_title` | Find the correct PMID for a given article title using multiple search strategies. |

## Tool Parameters

### search_pubmed

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `query` | string | yes | — | PubMed search query |
| `max_results` | integer | no | 10 | Maximum results to return (1–50) |

### fetch_article

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `pmid` | string | yes | PubMed ID (e.g. "30415628") |

### fetch_abstract

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `pmid` | string | yes | PubMed ID |

### verify_citation

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `pmid` | string | yes | PubMed ID to verify |
| `expected_title` | string | yes | The title you expect this PMID to correspond to |

### search_by_title

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `title` | string | yes | The article title to search for |

## Usage Examples

```
Search PubMed for "vitamin D supplementation meta-analysis 2024"
Fetch article PMID 30415628
Get the abstract for PMID 25927176
Verify citation: PMID 17846391 should be "Vitamin D supplementation and total mortality"
Find PMID for title: "Effect of zinc supplementation on C-reactive protein"
```

### Advanced Query Syntax

```
# Field-specific search
curcumin AND inflammation[Title]

# Author search
Prasad AS[Author] AND zinc

# Date range
omega-3 AND cardiovascular[Title] AND 2020:2024[dp]

# MeSH terms
"Zinc/therapeutic use"[MeSH]
```

## Troubleshooting

### Server fails to connect

1. Ensure `uvx` is installed: `uv --version`
2. Clear the uv cache if you upgraded from an older version:
   ```bash
   uv cache clean suppevo-pubmed-mcp
   ```
3. Test manually:
   ```bash
   uvx suppevo-pubmed-mcp@latest
   ```

### Rate limit errors

- Add an `NCBI_API_KEY` to your env config (see Installation above)
- Without a key, the server throttles to 3 requests/sec

### No results returned

- Try broader search terms
- Check PubMed query syntax — field tags are case-sensitive
- Use `search_by_title` for exact title lookups

## Links

- PyPI: https://pypi.org/project/suppevo-pubmed-mcp/
- GitHub: https://github.com/GomezMera-IO-LLC/suppevo-pubmed-mcp
- NCBI E-utilities docs: https://www.ncbi.nlm.nih.gov/books/NBK25500/
