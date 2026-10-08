# Find the build cause

Ask Jev to choose the line that best explains why the build failed. The log
includes successful steps, warnings, and a downstream error so the cause is
not simply the first line containing the word `error`.

```powershell
Import-Module Jev
Get-Content .\build.log | Find-Jev 'Which line best explains why the build failed?'
```

`Find-Jev` compares the candidate lines together in one Jev request and returns
the selected original line. Run from this folder. Results can vary between
live requests.
