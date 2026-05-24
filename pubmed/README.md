# PubMed MCP Server

An MCP server that provides tools for searching and retrieving biomedical literature from PubMed via NCBI E-utilities API.

## Tools

| Tool | Description |
|------|-------------|
| `search_pubmed` | Search PubMed with a query string, returns article summaries |
| `fetch_article` | Fetch full metadata and abstract for a specific PMID |
| `fetch_abstract` | Get just the abstract text for a PMID |
| `verify_citation` | Check if a PMID matches a given title (returns similarity score) |
| `search_by_title` | Find the correct PMID for a given article title |

## Setup

### Environment

Set `NCBI_API_KEY` for faster rate limits (10 req/sec vs 3 req/sec):
- Get a free key at: https://www.ncbi.nlm.nih.gov/account/settings/

### Run standalone

```bash
cd mcp-servers/pubmed
pip install -e .
fastmcp run server.py
```

### Use with Kiro

Already configured in `.kiro/settings/mcp.json`. The server starts automatically when you use any PubMed tool.

## Example Usage

```
Search PubMed for: "vitamin D supplementation meta-analysis 2024"
Fetch article PMID 30415628
Verify citation: PMID 17846391 should be "Vitamin D supplementation and total mortality"
Find PMID for title: "Effect of zinc supplementation on C-reactive protein"
```

## Rate Limits

- Without API key: 3 requests/second
- With API key: 10 requests/second
- NCBI may throttle if limits are exceeded
