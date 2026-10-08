function categorize {
    param (
        [string]$CsvPath,
        [string]$Question,
        [Parameter(ValueFromRemainingArguments)]
        $Options
    )
    
    Import-Csv $CsvPath | ForEach-Object {
        $failure = $_
        $component = $failure.Message | Get-JevChoice $Question $Options
        [pscustomobject]@{
            Id        = $failure.Id
            Component = $component
            Failure   = $failure.Message
        }
    }
}

categorize "$PSScriptRoot\test-failures.csv" 'who should investigate?' api auth database build
#categorize "$PSScriptRoot\test-failures.csv" 'Which component should investigate this failure?' api auth database build

return 
Import-Csv "$PSScriptRoot\test-failures.csv" | ForEach-Object {
    $failure = $_
    $component = $failure.Message | Get-JevChoice `
        'Which component should investigate this failure?' api auth database build
    [pscustomobject]@{
        Id        = $failure.Id
        Component = $component
        Failure   = $failure.Message
    }
} 