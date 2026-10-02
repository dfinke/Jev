# Refund gate

Ask Jev whether a customer wants money back, then let PowerShell choose the queue.

With PowerShell 7 and `TYPESAFE_API_KEY` configured, run from the repository root:

```powershell
.\Examples\Demos\01-refund-gate\RefundGate.ps1
# refunds

.\Examples\Demos\01-refund-gate\RefundGate.ps1 -Path .\Examples\Demos\01-refund-gate\question.txt
# normal
```

`message.txt` asks for a refund. `question.txt` asks whether a jug is dishwasher safe.

The script sends one complete message per run, asks a Noul question, and uses `>= 0.5` to choose `refunds` or `normal`. This matches the Rust demo's default cutoff. The output shown above is illustrative; each run makes a live Jev request. Request errors stop the script.

Ported from `thinkthen/demos/01-refund-gate`, using the existing `New-JevQuestion` and `Invoke-Jev` commands.
