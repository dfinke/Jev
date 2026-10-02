# Estimate the cost of a run from Jev's reported token usage.
# Defaults reflect TypeSafe's published Jev 1.13 pricing: $0.042 per million input tokens; output is free.
param(
    [string] $Path = "$PSScriptRoot/requests.jsonl",
    [double] $InputPricePerMillionTokens = 0.042,
    [double] $OutputPricePerMillionTokens = 0.0
)

$ErrorActionPreference = 'Stop'
if ($InputPricePerMillionTokens -lt 0 -or [double]::IsNaN($InputPricePerMillionTokens) -or [double]::IsInfinity($InputPricePerMillionTokens)) {
    throw 'Input price must be a finite, non-negative number.'
}
if ($OutputPricePerMillionTokens -lt 0 -or [double]::IsNaN($OutputPricePerMillionTokens) -or [double]::IsInfinity($OutputPricePerMillionTokens)) {
    throw 'Output price must be a finite, non-negative number.'
}

Import-Module "$PSScriptRoot/../../../Jev.psd1"
$question = New-JevYesNoQuestion -Name specialist -Question 'Does this request need a specialist?' `
    -TrueCriteria 'The request needs a specialist to work across systems.' `
    -FalseCriteria 'A routine response or one-person account check is enough.'

$rows = foreach ($line in Get-Content -LiteralPath $Path) {
    $request = $line | ConvertFrom-Json
    if ([string]::IsNullOrWhiteSpace([string] $request.id) -or [string]::IsNullOrWhiteSpace([string] $request.body)) {
        throw 'Every request needs a non-empty id and body.'
    }

    $decision = $request.body | Invoke-Jev -Question $question
    $inputProperty = if ($null -ne $decision.usage) { $decision.usage.PSObject.Properties['input_tokens'] } else { $null }
    $outputProperty = if ($null -ne $decision.usage) { $decision.usage.PSObject.Properties['output_tokens'] } else { $null }
    $hasUsage = $null -ne $inputProperty -and $null -ne $inputProperty.Value -and
        $null -ne $outputProperty -and $null -ne $outputProperty.Value

    if ($hasUsage) {
        $inputTokens = [long] $inputProperty.Value
        $outputTokens = [long] $outputProperty.Value
        $estimatedUsd = (($inputTokens * $InputPricePerMillionTokens) +
            ($outputTokens * $OutputPricePerMillionTokens)) / 1000000
    }
    else {
        $inputTokens = $null
        $outputTokens = $null
        $estimatedUsd = $null
    }

    [pscustomobject]@{
        Id             = $request.id
        Specialist     = [math]::Round([double] $decision.specialist, 2)
        InputTokens    = $inputTokens
        OutputTokens   = $outputTokens
        EstimatedUsd   = if ($null -eq $estimatedUsd) { $null } else { [math]::Round($estimatedUsd, 8) }
    }
}

$rows = @($rows)
$costedRows = @($rows | Where-Object { $null -ne $_.InputTokens -and $null -ne $_.OutputTokens })
$missingUsageIds = @($rows | Where-Object { $null -eq $_.InputTokens -or $null -eq $_.OutputTokens } | ForEach-Object Id)
$totalInputTokens = [long] (($costedRows | Measure-Object -Property InputTokens -Sum).Sum)
$totalOutputTokens = [long] (($costedRows | Measure-Object -Property OutputTokens -Sum).Sum)
$totalEstimatedUsd = (($totalInputTokens * $InputPricePerMillionTokens) +
    ($totalOutputTokens * $OutputPricePerMillionTokens)) / 1000000

[pscustomobject]@{
    Rows = $rows
    Summary = [pscustomobject]@{
        Requests                    = $rows.Count
        RequestsWithUsage           = $costedRows.Count
        MissingUsageIds             = $missingUsageIds
        InputTokens                 = $totalInputTokens
        OutputTokens                = $totalOutputTokens
        EstimatedUsd                = [math]::Round($totalEstimatedUsd, 8)
        InputPricePerMillionTokens  = $InputPricePerMillionTokens
        OutputPricePerMillionTokens = $OutputPricePerMillionTokens
    }
}
