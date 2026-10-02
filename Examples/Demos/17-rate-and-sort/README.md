# Rate and sort requests

Give Jev a few named levels for how much work a request needs. It returns a score that can land between levels; PowerShell sorts the queue from hardest to easiest.

With PowerShell 7 and `TYPESAFE_API_KEY` configured, run from the repository root:

```powershell
$ranked = .\Examples\Demos\17-rate-and-sort\RateAndSort.ps1
$ranked | Format-Table Id, Score, Route, Subject
$ranked | Select-Object -First 1 | Format-List *
```

Each `.txt` file in `requests` is one request. The filename becomes its ID, the `Subject:` header is shown in the result, and only the text after the blank line is sent to Jev. Add another `.txt` file with the same simple shape to add a request.

The four sample requests range from resending a receipt to reissuing a quarter of invoices under a new business name. The scale runs from `0` (a canned reply) through `1` (one person checks the account) to `2` (a specialist must work across systems). Fractional scores are possible.

The script sorts all requests by score, highest first, and labels scores at or above `1.5` for a specialist by default. The threshold can be changed with `-SpecialistThreshold`. The probability fields show how Jev distributed its score across the three levels. Two requests with similar scores can have different distributions, so a score helps order a human work queue; it does not guarantee that an individual request belongs in a particular route. The specialist cutoff is an example policy, not a validated boundary.

Each request makes one live Jev call. Scores and order can vary between runs. This example uses the existing `New-JevQuestion` and `Invoke-Jev` commands and does not use recording or replay data.
