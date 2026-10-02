# Assess a proposed command without running it.
param([string] $Path = "$PSScriptRoot/proposed")

$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/../../../Jev.psd1"

$question = New-JevYesNoQuestion -Name readOnly `
    -Question 'Does this proposed command only read, leaving every file and setting unchanged?' `
    -TrueCriteria 'It only reads information and does not change files, settings, or other machine state.' `
    -FalseCriteria 'It writes, deletes, changes, or could otherwise alter files, settings, or machine state.'

$yesThreshold = 0.8
$noThreshold = 0.1
$proposals = @(Get-ChildItem -LiteralPath $Path -Filter '*.txt' -File | Sort-Object Name)
if ($proposals.Count -eq 0) {
    throw "No proposal files found in '$Path'."
}

foreach ($proposal in $proposals) {
    $state = Get-Content -LiteralPath $proposal.FullName -Raw

    try {
        $decision = $state | Invoke-Jev -Question $question -ErrorAction Stop
        if ($null -eq $decision -or $null -eq $decision.readOnly) {
            throw 'Jev returned no read-only probability.'
        }

        $probability = [double] $decision.readOnly
        if ($probability -lt 0 -or $probability -gt 1) {
            throw 'Jev returned a read-only probability outside the range 0 to 1.'
        }

        if ($probability -ge $yesThreshold) {
            $result = 'Allow (not executed)'
            $reason = 'confidently read-only'
        }
        elseif ($probability -le $noThreshold) {
            $result = 'Hold'
            $reason = 'likely changes state'
        }
        else {
            $result = 'Ask a person'
            $reason = 'the answer is unclear'
        }
    }
    catch {
        $probability = $null
        $result = 'Hold'
        $reason = 'Jev could not answer'
    }

    [pscustomobject]@{
        Id                   = $proposal.BaseName
        ReadOnlyProbability  = if ($null -eq $probability) { $null } else { [math]::Round($probability, 2) }
        Result               = $result
        Reason               = $reason
    }
}
