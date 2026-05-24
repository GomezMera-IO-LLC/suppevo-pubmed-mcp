"""PubMed MCP Server — Search, fetch, and verify citations via NCBI E-utilities.

Tools:
  - search_pubmed: Search PubMed with a query string, returns article summaries
  - fetch_article: Fetch full metadata for a specific PMID
  - verify_citation: Check if a PMID matches a given title
  - search_by_title: Find the correct PMID for a given article title
  - fetch_abstract: Get the abstract text for a PMID

Environment:
  NCBI_API_KEY — Optional. Increases rate limit from 3/sec to 10/sec.
                 Get one at: https://www.ncbi.nlm.nih.gov/account/settings/
"""

from __future__ import annotations

import os
import re
import time
from pathlib import Path
from typing import Any

import httpx
from fastmcp import FastMCP

# Load .env from user home directory or project scripts/ directory
_env_locations = [
    Path.home() / ".env",
    Path(__file__).resolve().parent.parent.parent / "scripts" / ".env",
]
for _env_path in _env_locations:
    if _env_path.exists():
        try:
            from dotenv import load_dotenv
            load_dotenv(_env_path)
        except ImportError:
            # Manual .env parsing if python-dotenv not installed
            with open(_env_path) as _f:
                for _line in _f:
                    _line = _line.strip()
                    if _line and not _line.startswith("#") and "=" in _line:
                        _key, _, _val = _line.partition("=")
                        os.environ.setdefault(_key.strip(), _val.strip())
        break

mcp = FastMCP(
    "PubMed",
    instructions="Search and retrieve biomedical literature from PubMed/NCBI",
)

BASE_URL = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils"
NCBI_API_KEY = os.environ.get("NCBI_API_KEY", "")
DELAY = 0.12 if NCBI_API_KEY else 0.35

_client: httpx.Client | None = None


def _get_client() -> httpx.Client:
    global _client
    if _client is None:
        _client = httpx.Client(timeout=30.0)
    return _client


def _base_params() -> dict[str, str]:
    params: dict[str, str] = {}
    if NCBI_API_KEY:
        params["api_key"] = NCBI_API_KEY
    return params


def _parse_article_xml(xml_text: str) -> dict[str, Any] | None:
    """Parse PubMed XML response into structured article data."""
    title_match = re.search(r"<ArticleTitle>(.*?)</ArticleTitle>", xml_text, re.DOTALL)
    if not title_match:
        return None

    title = re.sub(r"<[^>]+>", "", title_match.group(1)).strip()

    # Authors
    authors = []
    for m in re.finditer(r"<LastName>(.*?)</LastName>\s*<ForeName>(.*?)</ForeName>", xml_text):
        authors.append(f"{m.group(1)} {m.group(2)}")

    # Journal
    journal_match = re.search(r"<Title>(.*?)</Title>", xml_text)
    journal = journal_match.group(1) if journal_match else ""

    # Year
    year_match = re.search(r"<PubDate>.*?<Year>(.*?)</Year>", xml_text, re.DOTALL)
    year = int(year_match.group(1)) if year_match else None

    # DOI
    doi_match = re.search(r'<ArticleId IdType="doi">(.*?)</ArticleId>', xml_text)
    doi = doi_match.group(1) if doi_match else None

    # PMID
    pmid_match = re.search(r'<ArticleId IdType="pubmed">(.*?)</ArticleId>', xml_text)
    pmid = pmid_match.group(1) if pmid_match else None

    # Abstract
    abstract_parts = re.findall(r"<AbstractText[^>]*>(.*?)</AbstractText>", xml_text, re.DOTALL)
    abstract = " ".join(re.sub(r"<[^>]+>", "", p).strip() for p in abstract_parts)

    # Volume, Issue, Pages
    volume_match = re.search(r"<Volume>(.*?)</Volume>", xml_text)
    issue_match = re.search(r"<Issue>(.*?)</Issue>", xml_text)
    pages_match = re.search(r"<MedlinePgn>(.*?)</MedlinePgn>", xml_text)

    return {
        "pmid": pmid,
        "title": title,
        "authors": authors,
        "authors_short": ", ".join(authors[:3]) + (" et al." if len(authors) > 3 else ""),
        "journal": journal,
        "year": year,
        "doi": doi,
        "abstract": abstract,
        "volume": volume_match.group(1) if volume_match else None,
        "issue": issue_match.group(1) if issue_match else None,
        "pages": pages_match.group(1) if pages_match else None,
        "url": f"https://pubmed.ncbi.nlm.nih.gov/{pmid}/" if pmid else None,
    }


def _normalize_title(title: str) -> str:
    title = title.lower().strip()
    title = re.sub(r"[^\w\s]", "", title)
    title = re.sub(r"\s+", " ", title)
    return title


def _title_similarity(a: str, b: str) -> float:
    words_a = set(_normalize_title(a).split())
    words_b = set(_normalize_title(b).split())
    if not words_a or not words_b:
        return 0.0
    intersection = words_a & words_b
    union = words_a | words_b
    return len(intersection) / len(union)


@mcp.tool()
def search_pubmed(query: str, max_results: int = 10) -> list[dict[str, Any]]:
    """Search PubMed with a query string and return article summaries.

    Args:
        query: PubMed search query. Supports field tags like [Title], [Author],
               [Journal], boolean operators (AND, OR, NOT), and MeSH terms.
               Examples:
                 - "vitamin D supplementation meta-analysis"
                 - "curcumin AND inflammation[Title]"
                 - "Prasad AS[Author] AND zinc"
        max_results: Maximum number of results to return (1-50, default 10)
    """
    max_results = min(max(1, max_results), 50)
    client = _get_client()

    # Search
    resp = client.get(
        f"{BASE_URL}/esearch.fcgi",
        params={
            **_base_params(),
            "db": "pubmed",
            "term": query,
            "retmax": str(max_results),
            "retmode": "json",
        },
    )
    resp.raise_for_status()
    data = resp.json()
    id_list = data.get("esearchresult", {}).get("idlist", [])
    total_count = int(data.get("esearchresult", {}).get("count", 0))

    if not id_list:
        return [{"message": f"No results found for: {query}", "total_count": 0}]

    # Fetch summaries
    time.sleep(DELAY)
    resp = client.get(
        f"{BASE_URL}/efetch.fcgi",
        params={
            **_base_params(),
            "db": "pubmed",
            "id": ",".join(id_list),
            "rettype": "xml",
            "retmode": "xml",
        },
    )
    resp.raise_for_status()

    # Parse each article
    articles = []
    for article_xml in re.findall(r"<PubmedArticle>(.*?)</PubmedArticle>", resp.text, re.DOTALL):
        article = _parse_article_xml(article_xml)
        if article:
            # Return summary without full abstract for search results
            articles.append({
                "pmid": article["pmid"],
                "title": article["title"],
                "authors": article["authors_short"],
                "journal": article["journal"],
                "year": article["year"],
                "doi": article["doi"],
                "url": article["url"],
            })

    return [{"total_count": total_count, "returned": len(articles)}, *articles]


@mcp.tool()
def fetch_article(pmid: str) -> dict[str, Any]:
    """Fetch full metadata and abstract for a specific PubMed article by PMID.

    Args:
        pmid: The PubMed ID (numeric string, e.g. "30415628")
    """
    client = _get_client()
    resp = client.get(
        f"{BASE_URL}/efetch.fcgi",
        params={
            **_base_params(),
            "db": "pubmed",
            "id": pmid,
            "rettype": "xml",
            "retmode": "xml",
        },
    )
    resp.raise_for_status()

    article = _parse_article_xml(resp.text)
    if not article:
        return {"error": f"Could not parse article for PMID {pmid}"}

    return article


@mcp.tool()
def fetch_abstract(pmid: str) -> dict[str, str]:
    """Get just the abstract text for a PubMed article.

    Args:
        pmid: The PubMed ID (numeric string)
    """
    client = _get_client()
    resp = client.get(
        f"{BASE_URL}/efetch.fcgi",
        params={
            **_base_params(),
            "db": "pubmed",
            "id": pmid,
            "rettype": "abstract",
            "retmode": "text",
        },
    )
    resp.raise_for_status()
    return {"pmid": pmid, "abstract": resp.text.strip()}


@mcp.tool()
def verify_citation(pmid: str, expected_title: str) -> dict[str, Any]:
    """Verify that a PubMed ID matches an expected article title.

    Returns the actual title at that PMID and a similarity score.

    Args:
        pmid: The PubMed ID to verify
        expected_title: The title you expect this PMID to correspond to
    """
    client = _get_client()
    resp = client.get(
        f"{BASE_URL}/efetch.fcgi",
        params={
            **_base_params(),
            "db": "pubmed",
            "id": pmid,
            "rettype": "xml",
            "retmode": "xml",
        },
    )
    resp.raise_for_status()

    article = _parse_article_xml(resp.text)
    if not article:
        return {
            "pmid": pmid,
            "verified": False,
            "error": "PMID not found or could not be parsed",
        }

    similarity = _title_similarity(expected_title, article["title"])
    verified = similarity >= 0.5

    result = {
        "pmid": pmid,
        "verified": verified,
        "similarity": round(similarity, 3),
        "expected_title": expected_title,
        "actual_title": article["title"],
        "actual_authors": article["authors_short"],
        "actual_journal": article["journal"],
        "actual_year": article["year"],
        "url": article["url"],
    }

    if not verified:
        result["suggestion"] = "Use search_by_title to find the correct PMID"

    return result


@mcp.tool()
def search_by_title(title: str) -> dict[str, Any]:
    """Find the correct PubMed ID for a given article title.

    Searches PubMed using multiple strategies to find the best match.

    Args:
        title: The article title to search for
    """
    client = _get_client()
    clean_title = re.sub(r"[^\w\s]", " ", title)
    clean_title = re.sub(r"\s+", " ", clean_title).strip()

    strategies = [
        # Strategy 1: Exact title field
        (f"{clean_title}[Title]", "exact_title"),
        # Strategy 2: Key words in title
        (" ".join(w for w in clean_title.split() if len(w) > 3)[:8] + "[Title]", "keywords_title"),
        # Strategy 3: Broad AND search
        (" AND ".join(w for w in clean_title.split() if len(w) > 4)[:6], "broad_and"),
    ]

    for query, strategy in strategies:
        time.sleep(DELAY)
        resp = client.get(
            f"{BASE_URL}/esearch.fcgi",
            params={
                **_base_params(),
                "db": "pubmed",
                "term": query,
                "retmax": "5",
                "retmode": "json",
            },
        )
        if resp.status_code != 200:
            continue

        data = resp.json()
        id_list = data.get("esearchresult", {}).get("idlist", [])

        for candidate_pmid in id_list[:3]:
            time.sleep(DELAY)
            resp = client.get(
                f"{BASE_URL}/efetch.fcgi",
                params={
                    **_base_params(),
                    "db": "pubmed",
                    "id": candidate_pmid,
                    "rettype": "xml",
                    "retmode": "xml",
                },
            )
            if resp.status_code != 200:
                continue

            article = _parse_article_xml(resp.text)
            if not article:
                continue

            similarity = _title_similarity(title, article["title"])
            if similarity >= 0.5:
                return {
                    "found": True,
                    "pmid": candidate_pmid,
                    "title": article["title"],
                    "authors": article["authors_short"],
                    "journal": article["journal"],
                    "year": article["year"],
                    "doi": article["doi"],
                    "url": article["url"],
                    "similarity": round(similarity, 3),
                    "strategy": strategy,
                }

    return {
        "found": False,
        "searched_title": title,
        "message": "Could not find a matching article on PubMed. Try refining the title or searching manually.",
    }


def main():
    mcp.run()


if __name__ == "__main__":
    main()
