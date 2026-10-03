<#
.SYNOPSIS
    Adds every matching semantic tag to each input.

.DESCRIPTION
    Turns a label-to-description dictionary into independent Noul questions.
    Each input makes one Jev request containing all tag questions. A tag is
    included when its yes probability reaches Threshold; zero, one, or several
    tags may apply. Labels are not mutually exclusive and their probabilities
    do not need to sum to one.

    Returns an enriched object with a string-array Tags property, individual
    tag probabilities, and full response details. Strings appear under State;
    object properties are retained and the original input is not modified.
    Property collisions receive repeated Jev_ prefixes, including Tags.

    An absent tag missed the threshold; this is not necessarily a confident
    no. Missing or invalid probabilities and request failures remain errors.

.PARAMETER State
    The string or object to tag. Accepts pipeline input or -State.

.PARAMETER Tags
    A dictionary mapping tag names to descriptions of when they apply.
    Accepts the first positional argument. Use an ordered dictionary to keep
    the matching Tags array in definition order.

.PARAMETER Threshold
    The minimum yes probability required to include a tag. Defaults to 0.5.
    Accepts the second positional argument.

.EXAMPLE
    $tags = @{ billing = 'A current charge, invoice, payment, or refund problem.' }
    'I was charged twice.' | Add-JevTag $tags

    Returns the original message under State with matching labels under Tags.

.EXAMPLE
    $messages | Add-JevTag $tags -Threshold 0.8 |
        Where-Object { $_.Tags -contains 'urgent' }

    Tags each message once, then filters the results using ordinary PowerShell.
#>
function Add-JevTag {
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object] $State,

        [Parameter(Mandatory, Position = 0)]
        [System.Collections.IDictionary] $Tags,

        [Parameter(Position = 1)]
        [ValidateRange(0.0, 1.0)]
        [double] $Threshold = 0.5
    )

    begin {
        if ($null -eq $Tags -or $Tags.Count -eq 0) {
            throw 'Add-JevTag requires at least one tag description.'
        }

        $questions = @(
            $seenLabels = @{}
            foreach ($entry in $Tags.GetEnumerator()) {
                $label = [string] $entry.Key
                if ([string]::IsNullOrWhiteSpace($label)) {
                    throw 'Tag names cannot be empty or whitespace.'
                }
                if ($seenLabels.ContainsKey($label)) {
                    throw "Duplicate tag name '$label'. Tag names are case-insensitive."
                }
                if ($entry.Value -isnot [string] -or [string]::IsNullOrWhiteSpace($entry.Value)) {
                    throw "Tag '$label' requires a non-empty string description."
                }
                $seenLabels[$label] = $true
                New-JevYesNoQuestion -Name $label `
                    -Question "Does this input match the tag '$label'?" `
                    -TrueCriteria $entry.Value `
                    -FalseCriteria 'The input does not meet the description of this tag.'
            }
        )
    }

    process {
        $response = Invoke-Jev -State $State -Question $questions -Raw -ErrorAction Stop
        [string[]] $matchingTags = @(
            foreach ($questionDefinition in $questions) {
                $label = $questionDefinition.Name
                $probability = Get-JevNoulProbability -Response $response -Name $label
                if ([double]::IsNaN($probability) -or $probability -lt 0 -or $probability -gt 1) {
                    throw "Jev returned an invalid probability for tag '$label'."
                }
                if ($probability -ge $Threshold) { $label }
            }
        )

        $result = ConvertTo-JevEnrichedResult -State $State -Response $response
        $propertyName = 'Tags'
        while ($null -ne $result.PSObject.Properties[$propertyName]) {
            $propertyName = "Jev_$propertyName"
        }
        $result.PSObject.Properties.Add([psnoteproperty]::new($propertyName, $matchingTags))
        $result
    }
}
