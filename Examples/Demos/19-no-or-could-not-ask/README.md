# Fail closed on a proposed command

Before running a proposed command, ask Jev whether it only reads and leaves machine state unchanged. PowerShell allows it only after a confident yes. A no, an unclear result, or a Jev request failure is held for review.

With PowerShell 7 and `TYPESAFE_API_KEY` configured, run from the repository root:

```powershell
.\Examples\Demos\19-no-or-could-not-ask\AssessProposals.ps1 |
    Format-Table Id, ReadOnlyProbability, Result, Reason
```

Each `.txt` file in `proposed` contains a PowerShell command and its stated purpose. The examples cover listing TODOs, fetching remote Git changes, and deleting build and untracked files. The script sends the proposal text to Jev, but never executes the proposed command.

The yes probability is interpreted using two cutoffs: `0.8` or higher allows the proposal (still not executed); `0.1` or lower holds it as state-changing; the middle band asks a person. The question is phrased so that only a confident yes can permit the next step. If the request fails or Jev cannot answer, the script also holds the proposal.

The cutoffs are example policy values, not a security guarantee. Review the command yourself before running it. Each proposal makes one live Jev request, and results can vary between runs. Recording and replay are not used.

Ported from `thinkthen/demos/19-no-or-could-not-ask`, using the existing `New-JevYesNoQuestion` and `Invoke-Jev` commands.
