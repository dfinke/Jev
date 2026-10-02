# Keep issue reports whose descriptions explain how to reproduce a defect.
param(
    [string] $Path = "$PSScriptRoot/issues.csv",
    [ValidateRange(0.0, 1.0)]
    [double] $Threshold = 0.9
)

$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/../../../Jev.psd1"

$question = New-JevQuestion -Name reproducibleDefect -Type Noul `
    -Instructions 'Does the report give steps that would reproduce a defect?' `
    -Criteria @{
        true  = 'The report describes a defect and gives concrete steps to reproduce it.'
        false = 'The report does not give concrete steps to reproduce a defect.'
    }

foreach ($issue in Import-Csv -LiteralPath $Path) {
    # Send only the report text; keep the rest of the CSV row for the result.
    $decision = $issue.body | Invoke-Jev -Question $question

    if ($decision.reproducibleDefect -ge $Threshold) {
        $issue
    }
}
