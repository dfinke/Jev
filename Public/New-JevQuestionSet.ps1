<#
.SYNOPSIS
    Bundles and validates a set of Jev questions for batch evaluation or speculative fan-out.
.DESCRIPTION
    Accepts question definitions from parameters or the pipeline, validates that
    each question has a unique non-empty name and valid payload properties, and
    outputs a clean array of questions ready for Invoke-Jev.

.PARAMETER Question
    One or more Jev question objects created by New-JevQuestion, New-JevChoiceQuestion,
    New-JevScoreQuestion, or New-JevYesNoQuestion.

.EXAMPLE
    $batch = New-JevQuestionSet -Question @(
        (New-JevChoiceQuestion -Name dept -Instructions 'Department?' -Choices @{ tech = 'Tech'; bill = 'Bill' })
        (New-JevYesNoQuestion -Name urgent -Question 'Urgent?' -TrueCriteria 'Yes' -FalseCriteria 'No')
    )
#>
function New-JevQuestionSet {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [object[]] $Question
    )

    begin {
        $collected = [System.Collections.Generic.List[object]]::new()
        $seenNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    }
    process {
        foreach ($q in $Question) {
            if ($null -eq $q) { continue }
            $name = [string] $q.Name
            if ([string]::IsNullOrWhiteSpace($name)) {
                throw 'Each Jev question in the set must have a non-empty Name.'
            }
            if (-not $seenNames.Add($name)) {
                throw "Duplicate question name '$name' in question set. All question names must be unique."
            }
            $collected.Add($q)
        }
    }
    end {
        $collected.ToArray()
    }
}
