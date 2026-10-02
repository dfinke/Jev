<#
.SYNOPSIS
    Creates a typed Jev Score question definition.

.DESCRIPTION
    A friendly constructor for Score questions. Score rates content along
    ordered descriptive levels (2 to 10 levels). Returns the question object
    annotated with LevelCount and MaxLevel to facilitate 0-1 normalization.

.PARAMETER Name
    The key used to identify this question's answer in the response.

.PARAMETER Instructions
    The question instructions sent to Jev.

.PARAMETER Levels
    An ordered array of 2 to 10 level descriptions. Each level should describe
    a concrete situation and stand on its own.

.EXAMPLE
    $question = New-JevScoreQuestion -Name frustration `
        -Instructions 'How frustrated does the customer appear in `message`?' `
        -Levels @(
            'Calm - stating facts, no emotional language.'
            'Concerned but civil - some frustration, polite.'
            'Very angry - strong language, demanding action.'
        )
#>
function New-JevScoreQuestion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,
        [Parameter(Mandatory, Position = 1)]
        [Alias('Prompt', 'Question')]
        [object] $Instructions,
        [Parameter(Mandatory, Position = 2)]
        [string[]] $Levels
    )

    $levelsArray = @($Levels)
    if ($levelsArray.Count -lt 2) {
        throw "Score question '$Name' requires at least two -Levels values."
    }
    if ($levelsArray.Count -gt 10) {
        throw "Score question '$Name' cannot have more than 10 -Levels values."
    }
    $question = New-JevQuestion -Name $Name -Type Score -Instructions $Instructions -Criteria $levelsArray
    Add-Member -InputObject $question -NotePropertyName 'LevelCount' -NotePropertyValue $levelsArray.Count
    Add-Member -InputObject $question -NotePropertyName 'MaxLevel' -NotePropertyValue ($levelsArray.Count - 1)
    $question
}
