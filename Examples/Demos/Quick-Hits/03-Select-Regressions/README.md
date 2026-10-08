# Select user-visible failures

Keep test output that points to a user-visible regression. Passing tests,
environment warnings, and internal diagnostic noise give Jev useful contrast.

```powershell
Import-Module Jev
Get-Content .\test-output.txt |
    Select-Jev 'Which test results indicate a user-visible regression?'
```

`Select-Jev` returns the original lines it judges relevant. Run from this
folder. Each line is evaluated separately, so this short file makes a small
number of live requests. Results can vary between runs.
