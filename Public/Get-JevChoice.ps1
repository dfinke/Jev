<#
.SYNOPSIS
    Chooses one supplied label for each input.

.DESCRIPTION
    Asks a Jev Choice question and returns the selected label as a string.
    Each input makes one live request. Choices can be written as separate
    trailing arguments without commas, or supplied as a named string array.
    Use meaningful labels: each label also becomes its criterion description.

    Returns one label per input in input order. Does not enrich the input or
    apply a confidence cutoff. Include an other or unclear choice when that
    is a useful outcome. Request failures, malformed responses, and unknown
    labels remain errors. Use Invoke-Jev with a Choice question when you need
    custom criterion descriptions, probabilities, or the full response.

.PARAMETER State
    The string or object to evaluate. Accepts pipeline input or -State.
    State does not bind positionally. A named array is one state value.

.PARAMETER Question
    The question about the input. Accepts the first positional argument.

.PARAMETER Choices
    One to 255 non-empty, unique labels. Accepts all positional arguments
    after the question. Labels are case-insensitive; output uses the supplied
    spelling. Multi-word labels must be quoted.

.EXAMPLE
    'I was charged twice. Please refund the duplicate.' |
        Get-JevChoice 'Which team owns this request?' billing shipping account other

    Returns a single label such as billing.

.EXAMPLE
    $team = $ticket | Get-JevChoice 'Which team owns this request?' billing shipping account other
    switch ($team) {
        billing { 'payments' }
        shipping { 'logistics' }
        account { 'identity' }
        other { 'triage' }
    }

    Uses Jev to choose a label and PowerShell to determine the queue.

.EXAMPLE
    Get-JevChoice -State $ticket -Question 'Which team owns this request?' -Choices @('billing', 'shipping', 'account', 'other')

    Supplies the state, question, and choices by name.
#>
function Get-JevChoice {
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object] $State,

        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Question,

        [Parameter(Mandatory, Position = 1, ValueFromRemainingArguments = $true)]
        [ValidateCount(1, 255)]
        [ValidateNotNullOrEmpty()]
        [string[]] $Choices
    )

    begin {
        $criteria = [ordered]@{}
        foreach ($label in $Choices) {
            if ([string]::IsNullOrWhiteSpace($label)) {
                throw 'Choice labels cannot be empty or whitespace.'
            }
            if ($criteria.Contains($label)) {
                throw "Duplicate choice label '$label'. Labels are case-insensitive."
            }
            $criteria[$label] = $label
        }
        $jevQuestion = New-JevQuestion -Name selection -Type Choice -Instructions $Question -Criteria $criteria
    }

    process {
        $response = Invoke-Jev -State $State -Question $jevQuestion -Raw -ErrorAction Stop
        $selected = Get-JevChoiceAnswer -Response $response -Name selection
        if (-not $criteria.Contains($selected)) {
            throw "Jev returned an unknown choice: '$selected'."
        }

        $criteria[$selected]
    }
}
