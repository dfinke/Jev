<#
.SYNOPSIS
    Reranks candidate items by semantic relevance to a query using Jev.

.DESCRIPTION
    Implements the "Select instead of generate" / Reranking pattern. Evaluates
    candidate strings or objects against a target query using Jev, then sorts
    the candidates by relevance score or probability.

.PARAMETER Candidates
    The candidate items or objects to evaluate and rank.

.PARAMETER Query
    The plain-English query, goal, or selection criteria.

.PARAMETER Property
    If candidate items are objects, the property name containing the text to evaluate.

.PARAMETER Top
    Maximum number of ranked results to return. Defaults to returning all candidates.

.PARAMETER Mock
    Runs evaluation using the local offline mock.

.PARAMETER MockOnMissingKey
    Uses mock mode if TYPESAFE_API_KEY is not set.

.EXAMPLE
    $files = Get-ChildItem -File
    $files | Invoke-JevRerank -Query 'Configuration file for database connection' -Property 'Name' -Top 3 -Mock
#>
function Invoke-JevRerank {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object[]] $Candidates,
        [Parameter(Mandatory, Position = 0)]
        [string] $Query,
        [string] $Property,
        [int] $Top,
        [switch] $Mock,
        [switch] $MockOnMissingKey
    )

    begin {
        $itemList = [System.Collections.Generic.List[object]]::new()
    }

    process {
        if ($null -ne $Candidates) {
            foreach ($item in $Candidates) {
                if ($null -ne $item) {
                    $itemList.Add($item)
                }
            }
        }
    }

    end {
        if ($itemList.Count -eq 0) {
            return @()
        }
        $question = New-JevScoreQuestion    -Name 'relevance' `
                                            -Instructions "How relevant is this item to the following request: '$Query'?" `
                                            -Levels @(
                                                'Irrelevant - does not match the request or purpose.'
                                                'Partially relevant - related topic but not an exact match.'
                                                'Highly relevant - directly satisfies or matches the request.'
                                            )

        $evaluated = foreach ($item in $itemList) {
            $text = if ($Property -and $item.PSObject.Properties[$Property]) {
                [string] $item.$Property
            }
            elseif ($item -is [string]) {
                $item
            }
            else {
                $item | ConvertTo-Json -Depth 5 -Compress
            }

            $invokeParams = @{
                State    = [ordered]@{ item = $text; query = $Query }
                Question = $question
            }
            if ($Mock) { $invokeParams.Mock = $true }
            if ($MockOnMissingKey) { $invokeParams.MockOnMissingKey = $true }

            $result = Invoke-Jev @invokeParams
            $score = if ($result.PSObject.Properties['relevance']) { [double] $result.relevance } else { 0.0 }
            $confidence = if ($result.answers -and $result.answers.relevance) { [double] $result.answers.relevance.confidence } else { 0.5 }

            [pscustomobject] [ordered] @{
                Item       = $item
                Score      = $score
                Confidence = $confidence
            }
        }

        $sorted = $evaluated | Sort-Object -Property Score, Confidence -Descending

        if ($Top -gt 0) {
            $sorted = $sorted | Select-Object -First $Top
        }

        foreach ($entry in $sorted) {
            $outputItem = $entry.Item
            if ($outputItem -is [pscustomobject] -or ($outputItem.GetType().IsClass -and -not ($outputItem -is [string]))) {
                Add-Member -InputObject $outputItem -NotePropertyName 'JevRelevance' -NotePropertyValue $entry.Score -Force -ErrorAction SilentlyContinue
                Add-Member -InputObject $outputItem -NotePropertyName 'JevConfidence' -NotePropertyValue $entry.Confidence -Force -ErrorAction SilentlyContinue
                $outputItem
            }
            else {
                [pscustomobject] [ordered] @{
                    Value         = $outputItem
                    JevRelevance  = $entry.Score
                    JevConfidence = $entry.Confidence
                }
            }
        }
    }
}
