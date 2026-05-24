# PubMed MCP Server

An MCP (Model Context Protocol) server that provides tools for searching and retrieving biomedical literature from PubMed via the NCBI E-utilities API.

## Features

| Tool | Description |
|------|-------------|
| `search_pubmed` | Search PubMed with a query string, returns article summaries |
| `fetch_article` | Fetch full metadata and abstract for a specific PMID |
| `fetch_abstract` | Get just the abstract text for a PMID |
| `verify_citation` | Check if a PMID matches a given title (returns similarity score) |
| `search_by_title` | Find the correct PMID for a given article title |

## Installation

### From PyPI

```bash
pip install suppevo-pubmed-mcp
```

### From source

```bash
git clone https://github.com/gomezmera/suppevo-pubmed-mcp.git
cd suppevo-pubmed-mcp/pubmed
pip install -e .
```

## Configuration

### NCBI API Key (recommended)

An API key increases your rate limit from 3 requests/sec to 10 requests/sec.

1. Create a free NCBI account at [NCBI](https://www.ncbi.nlm.nih.gov/account/)
2. Go to [Account Settings](https://www.ncbi.nlm.nih.gov/account/settings/) and generate an API key
3. Set the environment variable:

```bash
export NCBI_API_KEY="your-api-key-here"
```

Or add it to a `.env` file in your home directory (`~/.env`):

```env
NCBI_API_KEY=your-api-key-here
```

The server will automatically load it from `~/.env` if present.

## Running the Server

### Standalone

```bash
# If installed via pip
pubmed-mcp

# Or run directly with FastMCP
fastmcp run server.py
```

### With Kiro

Add to your `.kiro/settings/mcp.json`:

```json
{
  "mcpServers": {
    "pubmed": {
      "command": "python",
      "args": ["/path/to/suppevo-pubmed-mcp/pubmed/server.py"],
      "env": {
        "NCBI_API_KEY": "your-api-key-here"
      }
    }
  }
}
```

Or if installed from PyPI:

```json
{
  "mcpServers": {
    "pubmed": {
      "command": "uvx",
      "args": ["suppevo-pubmed-mcp"],
      "env": {
        "NCBI_API_KEY": "your-api-key-here"
      }
    }
  }
}
```

### With Claude Desktop

Add to your `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "pubmed": {
      "command": "uvx",
      "args": ["suppevo-pubmed-mcp"],
      "env": {
        "NCBI_API_KEY": "your-api-key-here"
      }
    }
  }
}
```

## Usage Examples

Once connected to an MCP client, you can use natural language:

- "Search PubMed for vitamin D supplementation meta-analysis 2024"
- "Fetch the full details for PMID 30415628"
- "Verify that PMID 17846391 is about vitamin D supplementation and total mortality"
- "Find the PMID for the article titled 'Effect of zinc supplementation on C-reactive protein'"
- "Get the abstract for PMID 25927176"

### Query Syntax

The `search_pubmed` tool supports PubMed's full query syntax:

```
# Basic search
vitamin D supplementation

# Field-specific
curcumin AND inflammation[Title]

# Author search
Prasad AS[Author] AND zinc

# Date range
omega-3 AND cardiovascular[Title] AND 2020:2024[dp]

# MeSH terms
"Zinc/therapeutic use"[MeSH]
```

## Rate Limits

| Configuration | Rate Limit |
|---------------|-----------|
| Without API key | 3 requests/second |
| With API key | 10 requests/second |

The server automatically throttles requests to stay within limits. NCBI may temporarily block IPs that exceed these limits.

## Development

```bash
# Clone and install in development mode
git clone https://github.com/gomezmera/suppevo-pubmed-mcp.git
cd suppevo-pubmed-mcp/pubmed
pip install -e .

# Run the server
python server.py
```

## Publishing

See [RELEASING.md](../RELEASING.md) for instructions on publishing to PyPI.

## License

MIT
