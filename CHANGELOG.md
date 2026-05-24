# Changelog

## [1.0.0] - 2025-05-24

### Added

- Initial release
- `search_pubmed` — search PubMed with query strings and field tags
- `fetch_article` — fetch full metadata and abstract for a PMID
- `fetch_abstract` — get abstract text for a PMID
- `verify_citation` — verify a PMID matches an expected title
- `search_by_title` — find the correct PMID for a given article title
- NCBI API key support for higher rate limits
- Automatic `.env` loading from home directory
