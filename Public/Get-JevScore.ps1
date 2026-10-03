<#
.SYNOPSIS
    Scores each input on an ordered Jev scale.

.DESCRIPTION
    Asks a Score question and returns one Double per input, in input order.
    Each input makes one live request. Supply two to ten ordered level
    descriptions after the question, without commas, or as a named array.

    Levels start at index zero. Three levels define a scale from 0 to 2;
    ten levels define a scale from 0 to 9. Jev returns a weighted score that
    can fall between levels. The score is not a yes probability or confidence.
    Define the levels in the order you want; the command does not infer or
    reorder the scale, round scores, enrich inputs, or apply a threshold.

    Request failures, missing answers, and invalid or out-of-range scores
    remain errors. Use Invoke-Jev with a Score question for the full answer,
    including confidence and the probability distribution.

.PARAMETER State
    The string or object to evaluate. Accepts pipeline input or -State.
    State does not bind positionally. A named array is one state value.

.PARAMETER Question
    The question about the input. Accepts the first positional argument.

.PARAMETER Levels
    Two to ten non-empty descriptions, in scale order. Accepts all positional
    arguments after the question. Quote descriptions containing spaces.

.EXAMPLE
    'Our event starts in two hours and tickets will not download.' |
        Get-JevScore 'How urgent is this?' 'Can wait' 'Needs attention soon' 'Needs attention now'

    Returns a numeric score between 0 and 2.

.EXAMPLE
    $messages | Get-JevScore 'How urgent is this?' routine soon immediate

    Returns one score per message. No commas are needed between the levels.

.EXAMPLE
    Get-JevScore -State $ticket -Question 'How urgent is this?' -Levels @('Can wait', 'Needs attention soon', 'Needs attention now')

    Supplies the state, question, and levels by name.
#>
function Get-JevScore {
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object] $State,

        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Question,

        [Parameter(Mandatory, Position = 1, ValueFromRemainingArguments = $true)]
        [ValidateCount(2, 10)]
        [ValidateNotNullOrEmpty()]
        [string[]] $Levels
    )

    begin {
        foreach ($level in $Levels) {
            if ([string]::IsNullOrWhiteSpace($level)) {
                throw 'Score level descriptions cannot be empty or whitespace.'
            }
        }
        $jevQuestion = New-JevQuestion -Name rating -Type Score -Instructions $Question -Criteria $Levels
        $maximumScore = $Levels.Count - 1
    }

    process {
        $response = Invoke-Jev -State $State -Question $jevQuestion -Raw -ErrorAction Stop
        $responseFields = ConvertTo-JevDictionary -Value $response
        if (-not $responseFields.ContainsKey('answers') -or $null -eq $responseFields['answers']) {
            throw "Jev did not return answers for question 'rating'."
        }
        $answers = ConvertTo-JevDictionary -Value $responseFields['answers']
        if (-not $answers.ContainsKey('rating') -or $null -eq $answers['rating']) {
            throw "Jev did not return a Score answer for question 'rating'."
        }
        $answer = ConvertTo-JevDictionary -Value $answers['rating']
        if (-not $answer.ContainsKey('score') -or $null -eq $answer['score']) {
            throw "Jev did not return a Score answer for question 'rating'."
        }
        if ($answer['score'] -is [bool] -or [string]::IsNullOrWhiteSpace([string] $answer['score'])) {
            throw "Jev returned an invalid score for question 'rating'."
        }
        try {
            $score = [double] $answer['score']
        }
        catch {
            throw "Jev returned an invalid score for question 'rating'."
        }
        if ([double]::IsNaN($score) -or $score -lt 0 -or $score -gt $maximumScore) {
            throw "Jev returned an invalid score for question 'rating'. Expected a value from 0 to $maximumScore."
        }

        $score
    }
}
