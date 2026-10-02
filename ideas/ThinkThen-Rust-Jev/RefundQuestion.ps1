#requires -Version 7.0

<#
.SYNOPSIS
    Pipes a customer message into a yes/no question and prints the Boolean answer.

.EXAMPLE
    ./RefundQuestion.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\..\Jev.psd1') -Force
. (Join-Path $PSScriptRoot 'Test-Jev.ps1')

$question = 'Does the customer ask for a refund?'

@'
I renewed once this morning, but my card shows two charges.
Please refund the duplicate.
'@ | Test-Jev $question
