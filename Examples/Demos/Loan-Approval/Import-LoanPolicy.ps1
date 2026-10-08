# Read the instructions and named choices from a small Markdown policy document.
function Import-LoanPolicy {
    param([string] $Path = "$PSScriptRoot/LoanPolicy.md")

    $text = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
    $sections = [regex]::Match($text.Trim(), '(?ms)\A# Instructions[ \t]*\r?\n(?<Instructions>.*?)^# Choices[ \t]*\r?\n(?<Choices>.*)\z')
    if (-not $sections.Success) {
        throw 'Policy must contain # Instructions followed by # Choices.'
    }

    $instructions = $sections.Groups['Instructions'].Value.Trim()
    $choiceText = $sections.Groups['Choices'].Value.Trim()
    if (-not $instructions -or $choiceText -notmatch '\A##[ \t]+') {
        throw 'Policy needs instructions and choices with ## headings.'
    }
    if ($instructions -match '(?m)^# ' -or $choiceText -match '(?m)^# ') {
        throw 'Use only the two top-level sections: # Instructions and # Choices.'
    }

    $criteria = [ordered]@{}
    $choices = [regex]::Matches($choiceText, '(?ms)^##[ \t]+(?<Name>[^\r\n]+)(?:\r?\n|\z)(?<Description>.*?)(?=^##[ \t]+|\z)')
    foreach ($choice in $choices) {
        $name = $choice.Groups['Name'].Value.Trim()
        $description = $choice.Groups['Description'].Value.Trim()
        if (-not $name -or -not $description) {
            throw 'Every choice needs a name and a description.'
        }
        if ($criteria.Contains($name)) {
            throw "Duplicate policy choice: '$name'."
        }
        $criteria[$name] = $description
    }
    if ($criteria.Count -eq 0) {
        throw 'Policy needs at least one described choice.'
    }

    [pscustomobject]@{
        Instructions = $instructions
        Criteria     = $criteria
    }
}
