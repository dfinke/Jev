<#
.SYNOPSIS
    Finds the original input that best answers a question.

.DESCRIPTION
    Collects finite pipeline input and compares all candidates together in
    one Jev Choice request. Returns at most one original string or object,
    preserving its identity and properties. Returns nothing when Jev selects
    the none-fits option. Empty input makes no request.

    Accepts up to 254 candidates, reserving the 255th choice for none fits.
    Strings are used directly as criteria; other inputs are represented as
    compact JSON. The question is the state sent to Jev.

    This is a model judgment, without a confidence cutoff. No output means
    Jev selected none fits, not that absence was proven. Request failures and
    malformed answers remain errors.

.PARAMETER State
    An input candidate. Accepts pipeline input or one candidate via -State.
    A named array is treated as one candidate, not multiple candidates.

.PARAMETER Question
    The question the selected candidate should answer. Accepts the first
    positional argument.

.EXAMPLE
    Get-Content ./app.log | Find-Jev 'Which entry best explains why checkout failed?'

    Returns the best original log line, or nothing if none fits.

.EXAMPLE
    $records | Find-Jev 'Which record best explains the failed payment?' |
        Select-Object Time, Message

    Returns the original record so its properties remain available.
#>
function Find-Jev {
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object] $State,

        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Question
    )

    begin {
        $candidates = [System.Collections.Generic.List[object]]::new()
    }

    process {
        if ($candidates.Count -ge 254) {
            throw 'Find-Jev accepts at most 254 candidates per call. Narrow the input before searching.'
        }
        $candidates.Add($State)
    }

    end {
        if ($candidates.Count -eq 0) { return }

        $criteria = [ordered]@{}
        $originalByLabel = @{}
        for ($index = 0; $index -lt $candidates.Count; $index++) {
            $label = 'candidate{0:D3}' -f ($index + 1)
            $candidate = $candidates[$index]
            $criteria[$label] = if ($candidate -is [string]) {
                $candidate
            }
            else {
                ConvertTo-Json -InputObject $candidate -Depth 30 -Compress
            }
            $originalByLabel[$label] = $candidate
        }
        $criteria['none'] = 'None of the candidates answers the question.'

        $jevQuestion = New-JevQuestion -Name match -Type Choice `
            -Instructions 'Which candidate best answers the question in the state? Compare the candidates together. Select none if no candidate answers the question.' `
            -Criteria $criteria

        $response = Invoke-Jev -State $Question -Question $jevQuestion -Raw -ErrorAction Stop
        $responseFields = ConvertTo-JevDictionary -Value $response
        if (-not $responseFields.ContainsKey('answers') -or $null -eq $responseFields['answers']) {
            throw "Jev did not return answers for question 'match'."
        }
        $answers = ConvertTo-JevDictionary -Value $responseFields['answers']
        if (-not $answers.ContainsKey('match') -or $null -eq $answers['match']) {
            throw "Jev did not return a Choice answer for question 'match'."
        }
        $answer = ConvertTo-JevDictionary -Value $answers['match']
        if (-not $answer.ContainsKey('choice') -or [string]::IsNullOrWhiteSpace([string] $answer['choice'])) {
            throw "Jev did not return a Choice answer for question 'match'."
        }

        $selected = [string] $answer['choice']
        if ($selected -eq 'none') { return }
        if (-not $originalByLabel.ContainsKey($selected)) {
            throw "Jev returned an unknown candidate: '$selected'."
        }

        $PSCmdlet.WriteObject($originalByLabel[$selected], $false)
    }
}
