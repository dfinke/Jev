#requires -Version 7.0

<#
.SYNOPSIS
    Routes sample Azure Advisor cost recommendations to a review queue.

.DESCRIPTION
    Pipes recommendation rows from a CSV through one bounded Jev Choice
    question per item, then uses a PowerShell switch to create a readable route.
    The example does not connect to Azure or apply resource changes.

.PARAMETER InputPath
    Path to the recommendation CSV. Defaults to advisor-recommendations.csv
    beside this script.

.PARAMETER OutputPath
    Path for the results CSV. Defaults to output/cost-recommendation-triage.csv
    beside this script.

.PARAMETER EventPath
    Optional JSON-lines trace file used by the Wails visualizer.

.PARAMETER DelayMs
    Optional delay between trace stages, in milliseconds. Used by the visualizer
    to make the flow easier to follow.

.EXAMPLE
    $env:TYPESAFE_API_KEY = 'your-api-key'
    ./Invoke-AzureCostRecommendationRouter.ps1
#>
[CmdletBinding()]
param(
    [string] $InputPath,

    [string] $OutputPath,

    [string] $EventPath,

    [ValidateRange(0, 2000)]
    [int] $DelayMs = 0
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $PSScriptRoot 'output/cost-recommendation-triage.csv'
}
if ([string]::IsNullOrWhiteSpace($InputPath)) {
    $InputPath = Join-Path $PSScriptRoot 'advisor-recommendations.csv'
}

Import-Module (Join-Path $PSScriptRoot '../../Jev.psd1') -Force

if (-not (Test-Path -LiteralPath $InputPath -PathType Leaf)) {
    throw "Input CSV not found: $InputPath"
}

function Send-FlowEvent {
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Event
    )

    if ([string]::IsNullOrWhiteSpace($EventPath)) { return }

    $json = ConvertTo-Json -InputObject $Event -Depth 10 -Compress
    [System.IO.File]::AppendAllText(
        $EventPath,
        $json + [System.Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Wait-FlowDelay {
    if ($DelayMs -gt 0) {
        Start-Sleep -Milliseconds $DelayMs
    }
}

$routeQuestion = New-JevQuestion -Name reviewLane -Type Choice `
    -Instructions 'Which review lane best fits this Azure cost recommendation and owner note?' `
    -Criteria ([ordered]@{
        cost_owner_review = 'The recommendation appears suitable for the workload owner to validate as a cost-saving opportunity, with no specific production, capacity, or dependency concern in the note.'
        technical_review  = 'The note identifies a production workload, capacity requirement, customer impact, or dependency that needs technical review before considering a change.'
        needs_context     = 'The environment, workload owner, or business context is missing or too unclear to choose a review lane.'
    })

$rows = @(Import-Csv -LiteralPath $InputPath)
$totalRows = $rows.Count
$rowNumber = 0
$results = $rows |
    ForEach-Object {
        $rowNumber++
        Send-FlowEvent ([ordered]@{
                type  = 'record_started'
                index = $rowNumber
                total = $totalRows
                record = [ordered]@{
                    RecommendationId           = $_.RecommendationId
                    ResourceType               = $_.ResourceType
                    Environment                = $_.Environment
                    Recommendation             = $_.Recommendation
                    PotentialMonthlySavingsUsd = $_.PotentialMonthlySavingsUsd
                    OwnerNote                  = $_.OwnerNote
                }
            })
        Wait-FlowDelay
        Send-FlowEvent ([ordered]@{ type = 'jev_started'; index = $rowNumber; total = $totalRows })

        try {
            $decision = $_ | Invoke-Jev -Question $routeQuestion
        }
        catch {
            Send-FlowEvent ([ordered]@{
                    type    = 'error'
                    index   = $rowNumber
                    total   = $totalRows
                    message = $_.Exception.Message
                })
            throw
        }

        $reviewLane = [string] $decision.reviewLane
        $confidence = [double] $decision.answers.reviewLane.confidence

        Send-FlowEvent ([ordered]@{
                type       = 'classified'
                index      = $rowNumber
                total      = $totalRows
                reviewLane = $reviewLane
                confidence = $confidence
            })
        Wait-FlowDelay

        switch ($reviewLane) {
            'cost_owner_review' {
                $route = 'Workload-owner cost review'
                $routeReason = 'Ask the workload owner to validate the savings recommendation before any change.'
            }
            'technical_review' {
                $route = 'Technical review'
                $routeReason = 'The note flags production, capacity, customer-impact, or dependency context to check first.'
            }
            default {
                $route = 'Gather context'
                $routeReason = 'Confirm the environment, workload owner, or business context before routing.'
            }
        }

        Send-FlowEvent ([ordered]@{
                type       = 'switch_matched'
                index      = $rowNumber
                total      = $totalRows
                reviewLane = $reviewLane
                route      = $route
                reason     = $routeReason
            })
        Wait-FlowDelay

        $routedRecord = [pscustomobject]@{
            RecommendationId           = $decision.RecommendationId
            ResourceType               = $decision.ResourceType
            Environment                = $decision.Environment
            Recommendation             = $decision.Recommendation
            PotentialMonthlySavingsUsd = $decision.PotentialMonthlySavingsUsd
            ReviewLane                 = $reviewLane
            Confidence                 = [math]::Round($confidence, 2)
            Route                      = $route
            RouteReason                = $routeReason
            OwnerNote                  = $decision.OwnerNote
        }

        Send-FlowEvent ([ordered]@{
                type       = 'routed'
                index      = $rowNumber
                total      = $totalRows
                reviewLane = $reviewLane
                route      = $route
                reason     = $routeReason
                record     = $routedRecord
            })
        $routedRecord
    }

Send-FlowEvent ([ordered]@{ type = 'run_complete'; total = $totalRows })

$outputDirectory = Split-Path -Parent $OutputPath
if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}
$results | Export-Csv -LiteralPath $OutputPath -NoTypeInformation -Encoding utf8

Write-Host "Cost recommendation review: $($results.Count) rows from $InputPath" -ForegroundColor Cyan
$results |
    Select-Object RecommendationId, ReviewLane, Confidence, Route |
    Format-Table -AutoSize -Wrap
Write-Host "Full results written to: $OutputPath" -ForegroundColor Green
