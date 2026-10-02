#requires -Version 7.0

<#
.SYNOPSIS
    Semantically audits PowerShell script files for naming clarity and single-responsibility violations.
#>
[CmdletBinding()]
param(  
    [string]$Path = "d:\mygit\Jev\ideas\data\testSemanticCode.ps1"
)

Clear-Host
$ErrorActionPreference = 'Stop'

# # Extract function definitions using the PowerShell AST
$ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$null)
$functions = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)

if (-not $functions) {
    Write-Warning "No function definitions found in $Path"
    return
}

# Define bounded semantic questions
$questions = @(
    New-JevQuestion -Name single_responsibility -Type Choice `
        -Instructions 'Does this function adhere to the Single Responsibility Principle, or is it trying to do too many unrelated tasks?' `
        -Criteria @{
        focused = 'Clear, single purpose (e.g., fetches data, formats output, OR executes an action).'
        bloated = 'Combines multiple distinct responsibilities (e.g., fetches API data AND parses CSV AND writes to disk).'
        unclear = 'Function body is too vague or ambiguous to determine its primary responsibility.'
    }

    New-JevQuestion -Name naming_accuracy -Type Choice `
        -Instructions 'Does the function name accurately describe what the code inside the body actually does?' `
        -Criteria @{
        accurate     = 'The Verb-Noun name clearly aligns with the code execution.'
        misleading   = 'The name is deceptive or misses major side-effects (e.g., Get-* that actually deletes or modifies state).'
        non_standard = 'Does not use standard PowerShell Verb-Noun conventions or uses vague names like Do-Stuff.'
    }
)

Write-Host "Auditing $($functions.Count) functions in $Path..." -ForegroundColor Cyan

$results = foreach ($func in $functions) {
    # State payload contains the Function Name and raw Code Body
    $state = [PSCustomObject]@{
        FunctionName = $func.Name
        CodeBody     = $func.Extent.Text
    }

    $decision = Invoke-Jev -State $state -Question $questions

    [PSCustomObject]@{
        Function             = $func.Name
        LineNumber           = $func.Extent.StartLineNumber
        SingleResponsibility = $decision.single_responsibility
        SRConfidence         = [math]::Round([double]$decision.answers.single_responsibility.confidence, 2)
        NamingAccuracy       = $decision.naming_accuracy
        NamingConfidence     = [math]::Round([double]$decision.answers.naming_accuracy.confidence, 2)
    }
}

# 1. Immediate Alert View for Refactoring Candidates
Write-Host "`n--- Refactoring Candidates (Bloated or Misleading) ---" -ForegroundColor Red
$results | Where-Object { $_.SingleResponsibility -eq 'bloated' -or $_.NamingAccuracy -eq 'misleading' } |
Format-Table Function, LineNumber, SingleResponsibility, NamingAccuracy -AutoSize

# 2. Architectural Overview by Responsibility
Write-Host "`n--- Summary by Single Responsibility ---" -ForegroundColor Green
$results | Group-Object SingleResponsibility | Select-Object Name, Count | Format-Table -AutoSize