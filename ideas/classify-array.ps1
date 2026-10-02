$question = New-JevQuestion -Name keep -Type Noul -Instructions ''

$jev = {
    param($condition)

    $question.Instructions = $condition
    $this | Invoke-Jev -Question $question 
}

$data = ConvertFrom-Csv @"
Region,State,Units,Price
West,Texas,927,923.71
North,Tennessee,466,770.67
East,Florida,520,458.68
East,Maine,828,661.24
West,Virginia,465,53.58
North,Missouri,436,235.67
South,Kansas,214,992.47
North,North Dakota,789,640.72
South,Delaware,712,508.55
"@

$data | Add-Member -MemberType ScriptMethod -Name jev -Value $jev -Force

# Jev makes the judgment. PowerShell applies the policy.
# The natural-language question becomes a structured decision on each record,
# then the normal pipeline decides what to keep and how to sort it.
#$data.jev('is region north') | Where-Object { $_.keep -gt .5 } | Format-Table
$timing = Measure-Command {
    $r = $data.jev('are we north') |
        Where-Object { $_.keep -gt .5 } |
        Sort-Object keep -Descending
}

$r | Format-Table

Write-Host "Total Seconds: $($timing.TotalSeconds)" -ForegroundColor Cyan
