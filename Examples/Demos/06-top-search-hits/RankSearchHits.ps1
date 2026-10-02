# Rerank search hits by how well each passage answers the query.
param(
    [string] $Path = "$PSScriptRoot/hits.jsonl",
    [string] $Query = 'Why is signing in slow or failing?',
    [ValidateRange(1, 255)]
    [int] $Top = 3
)

$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/../../../Jev.psd1"

$question = New-JevQuestion -Name relevant -Type Noul `
    -Instructions 'Does this passage answer the search query?' `
    -Criteria @{
        true  = 'The passage directly or materially helps answer the query.'
        false = 'The passage does not help answer the query.'
    }

$rankedHits = foreach ($line in Get-Content -LiteralPath $Path) {
    $hit = $line | ConvertFrom-Json
    $state = [pscustomobject]@{
        query    = $Query
        passage  = $hit.body
    }

    $decision = $state | Invoke-Jev -Question $question

    [pscustomobject]@{
        Path        = $hit.path
        Relevance   = [double] $decision.relevant
        Passage     = $hit.body
    }
}

$rankedHits |
    Sort-Object -Property Relevance -Descending |
    Select-Object -First $Top
