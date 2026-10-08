# Rank build clues

Ask for the three lines that best explain why the release build failed. This
file contains incidental activity as well as symptoms and a likely cause.

```powershell
Import-Module Jev
Get-Content .\release-build.log |
    Get-JevRanking 'Which lines best explain why the release build failed?' -Top 3
```

`Get-JevRanking` evaluates each line, then returns the top three original lines.
That means one Jev request per line. Run from this folder. Results can vary
between live requests.
