# Top search hits

Keyword search can find candidate pages, but the order may not reflect which page best answers the question. This example asks Jev to score each passage against a query, then uses PowerShell to put the strongest matches first.

With PowerShell 7 and `TYPESAFE_API_KEY` configured, run from the repository root:

```powershell
.\Examples\Demos\06-top-search-hits\RankSearchHits.ps1 |
    Format-Table Path, Relevance
```

The six sample pages are about sign-in failures. The script sends Jev only the query and each page's passage; it keeps the path locally so the ranked results can point back to their source. It evaluates every candidate, sorts by the Noul yes probability, and returns the top three by default.

The recorded Rust run ranked `runbooks/database.md`, `notes/2025-11-outage.md`, and `runbooks/login.md` first. The live PowerShell run can produce a different order. Ranking changes reading order; it does not prove a page is relevant. With no minimum score, the script still returns three results even when all scores are low.

`-Top` changes how many results are returned, but does not reduce Jev requests: every candidate must be scored before PowerShell can sort them. `-Query` changes the search question, and `-Path` points to a different JSONL file. Each input line should be a JSON object with `path` and `body` properties.

Ported from `thinkthen/demos/06-top-search-hits`, using the existing `New-JevQuestion` and `Invoke-Jev` commands. Each candidate makes a live Jev request; no recording or replay data is used.
