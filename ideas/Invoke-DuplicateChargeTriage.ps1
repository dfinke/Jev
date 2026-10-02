#requires -Version 7.0

<#
.SYNOPSIS
    Ports tryStuff.py to the Jev PowerShell module.

.DESCRIPTION
    Sends one duplicate-charge support case as the state and asks four
    bounded questions in a single Jev request: department, frustration,
    whether a refund was requested, and whether policy supports it.

.EXAMPLE
    $env:TYPESAFE_API_KEY = 'your-api-key'
    ./ideas/Invoke-DuplicateChargeTriage.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\Jev.psd1') -Force

$state = @{
    ticket = @{
        subject  = 'Duplicate charge'
        messages = @(
            @{
                from = 'customer'
                text = 'I was charged twice for order A-104. Please refund the duplicate.'
            }
        )
    }
    order = @{
        id      = 'A-104'
        charges = @(
            @{ amount_usd = 49; status = 'captured' }
            @{ amount_usd = 49; status = 'captured' }
        )
    }
    refund_policy = 'Duplicate charges are eligible for a refund.'
}

$questions = @(
    New-JevQuestion -Name department -Type Choice `
        -Instructions 'Which team should handle this?' `
        -Criteria @{
            billing   = 'Payment or subscription issues'
            technical = 'Bugs or integration problems'
            sales     = 'Pricing or account questions'
        }

    New-JevQuestion -Name frustration -Type Score `
        -Instructions 'How frustrated does the customer appear?' `
        -Criteria @(
            'Calm, just stating facts'
            'Frustrated but civil'
            'Very angry, strong language'
        )

    New-JevQuestion -Name refund_requested -Type Noul `
        -Instructions 'The customer is explicitly asking for a refund.'

    New-JevQuestion -Name policy_supports -Type Noul `
        -Instructions 'The stated refund policy covers this situation.'
)

# One state plus all four questions means one Jev request.
$decision = Invoke-Jev -State $state -Question $questions

$department = $decision.answers.department
$frustration = $decision.answers.frustration
$refundRequested = $decision.answers.refund_requested
$policySupports = $decision.answers.policy_supports

[pscustomobject]@{
    Department                 = $department.choice
    DepartmentConfidence       = [math]::Round([double] $department.confidence, 3)
    FrustrationScore           = [math]::Round([double] $frustration.score, 3)
    FrustrationConfidence      = [math]::Round([double] $frustration.confidence, 3)
    RefundRequestedProbability = [math]::Round([double] $refundRequested.noul, 3)
    PolicySupportsProbability  = [math]::Round([double] $policySupports.noul, 3)
} | Format-List
