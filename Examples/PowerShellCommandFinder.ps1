#requires -Version 7.0

<#
.SYNOPSIS
    Finds a likely local PowerShell command for a plain-English task.

.DESCRIPTION
    Searches installed cmdlet and function names and help text, then asks Jev
    to choose the best match from a short candidate list. Displays local help
    examples for review. The suggested command is never executed.

.PARAMETER Task
    Describe what you want PowerShell to do.

.PARAMETER CandidateCount
    Maximum number of locally matched commands Jev can choose from.

.EXAMPLE
    .\PowerShellCommandFinder.ps1 -Task 'Find files larger than 100 MB'

.EXAMPLE
    .\PowerShellCommandFinder.ps1 -Task 'Show processes using the most memory' -CandidateCount 18

.EXAMPLE
    .\PowerShellCommandFinder.ps1 -Task 'Search text inside every PowerShell script'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Task,

    [ValidateRange(3, 25)]
    [int] $CandidateCount = 12
)

# Set TYPESAFE_API_KEY before running this example.
# This script searches local command metadata. It asks Jev to choose a likely
# command, then displays help for review; it never runs the suggested command.

Import-Module (Join-Path $PSScriptRoot '..' 'Jev.psd1') -Force

$stopWords = @('the', 'and', 'for', 'with', 'from', 'that', 'this', 'into', 'using', 'use', 'find', 'get', 'show', 'list', 'all', 'how', 'can', 'want', 'need', 'please', 'powershell')
$terms = @(
    [regex]::Matches($Task.ToLowerInvariant(), '[a-z0-9]{3,}') |
        ForEach-Object Value |
        Where-Object { $_ -notin $stopWords } |
        Sort-Object -Unique
)

if ($terms.Count -eq 0) {
    throw 'Describe what you want to do with a few specific words.'
}

$candidates = foreach ($command in Get-Command -CommandType Cmdlet, Function -ErrorAction SilentlyContinue) {
    $help = Get-Help -Name $command.Name -ErrorAction SilentlyContinue
    $synopsis = [string] $help.Synopsis
    if ([string]::IsNullOrWhiteSpace($synopsis)) {
        $synopsis = [string] $command.Definition
        if ($synopsis.Length -gt 240) { $synopsis = $synopsis.Substring(0, 240) }
    }

    $searchText = "$($command.Name) $synopsis".ToLowerInvariant()
    $matchCount = @($terms | Where-Object { $searchText.Contains($_) }).Count
    if ($matchCount -gt 0) {
        [pscustomobject]@{
            Name        = $command.Name
            CommandType = [string] $command.CommandType
            Module      = [string] $command.Source
            Synopsis    = $synopsis
            MatchCount  = $matchCount
        }
    }
}

$candidates = @($candidates | Sort-Object -Property @{ Expression = 'MatchCount'; Descending = $true }, Name | Select-Object -First $CandidateCount)
if ($candidates.Count -eq 0) {
    throw 'No local commands matched those terms. Try describing the task with words that may appear in command names or help, or import the relevant module first.'
}

$criteria = [ordered]@{}
foreach ($candidate in $candidates) {
    $criteria[$candidate.Name] = "[$($candidate.CommandType); module: $($candidate.Module)] $($candidate.Synopsis)"
}

$question = New-JevQuestion `
    -Name command `
    -Type Choice `
    -Instructions "Choose the single PowerShell command that is the best fit for this task: $Task. Choose only from the supplied candidates. Prefer a command that directly accomplishes the task; do not infer that the command should be run." `
    -Criteria $criteria

$decision = Invoke-Jev -State ([pscustomobject]@{
        Task       = $Task
        Candidates = @($candidates | Select-Object Name, CommandType, Module, Synopsis)
    }) -Question $question

$answer = $decision.answers.command
$selected = $candidates | Where-Object Name -eq $decision.command | Select-Object -First 1

Write-Host "Task: $Task" -ForegroundColor Cyan
if ($null -eq $selected) {
    Write-Warning 'Jev did not return a command from the supplied candidate list.'
    $decision
    return
}

[pscustomobject]@{
    Command    = $selected.Name
    Confidence = [math]::Round([double] $answer.confidence, 2)
    Module     = $selected.Module
    Synopsis   = $selected.Synopsis
}

Write-Host "`nLocal help for $($selected.Name) (review before using):" -ForegroundColor Cyan
Get-Help -Name $selected.Name -Examples | Select-Object -ExpandProperty Examples
