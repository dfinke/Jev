#requires -Version 7.0

<#
.SYNOPSIS
    Classifies a synthetic Azure tenant portfolio and writes a review queue.

.DESCRIPTION
    Sends one tenant summary at a time to Jev with three bounded questions:
    recommended workstream, whether discovery is needed, and urgency. PowerShell
    applies transparent routing gates and exports a CSV. This example does not
    connect to or change Azure tenants.

.PARAMETER InputPath
    Path to the tenant inventory CSV. Defaults to tenant-inventory.csv beside
    this script.

.PARAMETER OutputPath
    Path for the triage results CSV. Defaults to output/tenant-triage-results.csv
    beside this script.

.PARAMETER Mock
    Use Jev's local schema mock without an API request. The mock only verifies
    the script flow; its classifications do not represent Jev's judgment.

.EXAMPLE
    $env:TYPESAFE_API_KEY = 'your-api-key'
    ./Invoke-AzureTenantPortfolioReview.ps1

.EXAMPLE
    ./Invoke-AzureTenantPortfolioReview.ps1 -Mock -OutputPath "$env:TEMP/tenant-review.csv"
#>
[CmdletBinding()]
param(
    [string] $InputPath,

    [string] $OutputPath,

    [switch] $Mock
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($InputPath)) {
    $InputPath = Join-Path $PSScriptRoot 'tenant-inventory.csv'
}
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $PSScriptRoot 'output/tenant-triage-results.csv'
}

$modulePath = Join-Path $PSScriptRoot '../../Jev.psd1'
Import-Module $modulePath -Force

if (-not (Test-Path -LiteralPath $InputPath -PathType Leaf)) {
    throw "Input CSV not found: $InputPath"
}

$tenants = @(Import-Csv -LiteralPath $InputPath)
if ($tenants.Count -eq 0) {
    throw "Input CSV contains no tenant rows: $InputPath"
}

$workstreamQuestion = New-JevQuestion -Name workstream -Type Choice `
    -Instructions 'Which next workstream best fits this tenant summary?' `
    -Criteria ([ordered]@{
        cost_optimization    = 'Review Azure Advisor cost recommendations and potential savings against workload context.'
        governance_followup  = 'Investigate Azure Policy compliance findings or gaps in governance metadata.'
        inventory_cleanup    = 'Clarify resource or subscription ownership, tags, or inventory quality.'
        migration_planning   = 'Assess a planned migration, data-center exit, or workload move.'
        integration_planning = 'Plan how a merger or organizational change affects tenant or subscription boundaries.'
        monitor              = 'No significant project is indicated; continue routine cost and governance review.'
    })

$discoveryQuestion = New-JevYesNoQuestion -Name needsDiscovery `
    -Question 'Is more discovery needed before choosing a workstream or action?' `
    -TrueCriteria 'Important facts are stale, missing, conflicting, or the next step depends on unknown workload or ownership details.' `
    -FalseCriteria 'The inventory is current and the notes clearly support a bounded next workstream.'

$urgencyLevels = @('Routine', 'Soon', 'Priority', 'Immediate')
$urgencyQuestion = New-JevQuestion -Name urgency -Type Score `
    -Instructions 'How urgent is the next review of this tenant?' `
    -Criteria $urgencyLevels

$questions = @($workstreamQuestion, $discoveryQuestion, $urgencyQuestion)
$discoveryThreshold = 0.75
$choiceConfidenceThreshold = 0.60
$results = foreach ($tenant in $tenants) {
    $state = [pscustomobject]@{
        TenantName                       = [string] $tenant.TenantName
        SubscriptionCount                = [int] $tenant.SubscriptionCount
        MonthlyCostUsd                   = [decimal] $tenant.MonthlyCostUsd
        AdvisorCostRecommendationCount   = [int] $tenant.AdvisorCostRecommendationCount
        PotentialMonthlySavingsUsd       = [decimal] $tenant.PotentialMonthlySavingsUsd
        NonCompliantResources            = [int] $tenant.NonCompliantResources
        UntaggedResourcePercent          = [double] $tenant.UntaggedResourcePercent
        SnapshotAgeDays                  = [int] $tenant.SnapshotAgeDays
        ContextNotes                     = [string] $tenant.ContextNotes
    }

    $invokeParameters = @{
        State    = $state
        Question = $questions
    }
    if ($Mock) { $invokeParameters.Mock = $true }
    $decision = Invoke-Jev @invokeParameters

    $workstreamAnswer = $decision.answers.workstream
    $workstreamConfidence = [double] $workstreamAnswer.confidence
    $discoveryProbability = [double] $decision.needsDiscovery
    $urgencyIndex = [int] $decision.urgency
    $urgencyIndex = [math]::Clamp($urgencyIndex, 0, $urgencyLevels.Count - 1)
    $urgency = $urgencyLevels[$urgencyIndex]
    $workstream = [string] $decision.workstream

    # These are review-routing gates, not commands to make tenant changes.
    if ($state.SnapshotAgeDays -gt 60) {
        $queue = 'Refresh inventory'
        $gateReason = 'The source snapshot is more than 60 days old.'
    }
    elseif ($discoveryProbability -ge $discoveryThreshold -or $workstreamConfidence -lt $choiceConfidenceThreshold) {
        $queue = 'Discovery review'
        $gateReason = 'The decision is uncertain or key facts need confirmation.'
    }
    elseif ($urgency -eq 'Immediate') {
        $queue = "Expedited $workstream"
        $gateReason = 'Urgency reached the Immediate level.'
    }
    else {
        $queue = $workstream
        $gateReason = 'Route to the selected workstream.'
    }

    [pscustomobject]@{
        TenantName               = $state.TenantName
        SubscriptionCount        = $state.SubscriptionCount
        MonthlyCostUsd           = $state.MonthlyCostUsd
        AdvisorCostRecommendationCount = $state.AdvisorCostRecommendationCount
        PotentialMonthlySavingsUsd = $state.PotentialMonthlySavingsUsd
        NonCompliantResources    = $state.NonCompliantResources
        UntaggedResourcePercent  = $state.UntaggedResourcePercent
        SnapshotAgeDays          = $state.SnapshotAgeDays
        Workstream               = $workstream
        WorkstreamConfidence     = [math]::Round($workstreamConfidence, 2)
        NeedsDiscoveryProbability = [math]::Round($discoveryProbability, 2)
        Urgency                  = $urgency
        Queue                    = $queue
        GateReason               = $gateReason
        ContextNotes             = $state.ContextNotes
    }
}

$outputDirectory = Split-Path -Parent $OutputPath
if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}
$results | Export-Csv -LiteralPath $OutputPath -NoTypeInformation -Encoding utf8

Write-Host "Tenant portfolio review: $($results.Count) rows" -ForegroundColor Cyan
$results |
    Select-Object TenantName, Workstream, WorkstreamConfidence, Urgency, Queue |
    Format-Table -AutoSize -Wrap
Write-Host "Full results written to: $OutputPath" -ForegroundColor Green
