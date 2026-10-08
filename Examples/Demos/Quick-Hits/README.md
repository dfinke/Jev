# Developer quick hits

Short command-line demos using small, realistic input files. Open a demo folder,
inspect its input, then paste its command into PowerShell. Each command makes
live Jev requests; set `TYPESAFE_API_KEY` first.

| Demo | What it shows |
|---|---|
| [Find the build cause](01-Find-Build-Cause/README.md) | Pick the single log line that best explains a failed build. |
| [Rank build clues](02-Rank-Build-Clues/README.md) | Return the three most relevant lines from a noisy build log. |
| [Select user-visible failures](03-Select-Regressions/README.md) | Keep test output that signals a user-visible regression. |
| [Route test failures](04-Route-Failures/README.md) | Assign each failure to `api`, `auth`, `database`, or `build`. |

These are quick demonstrations of semantic decisions in a pipeline. For each
command, the lines in its input file are separate inputs to Jev. The ranking
example makes one request per log line; the find example compares the candidate
lines in one request.
