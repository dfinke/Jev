#requires -Version 7.0
#requires -Modules ImportExcel

<#
.SYNOPSIS
    Recommends a negotiation move for an editable Excel deal.

.DESCRIPTION
    Reads a deal from an Excel workbook, calculates the commercial impact of
    several approved moves, and asks Jev to choose the best next move. Writes
    the recommendation and all calculated options to a separate workbook.
    Set TYPESAFE_API_KEY before running.

.EXAMPLE
    .\DealDesk.ps1

.EXAMPLE
    .\DealDesk.ps1 -Path .\my-deal.xlsx -OutputPath .\my-deal-review.xlsx
#>
[CmdletBinding()]
param(
    [string] $Path = (Join-Path $PSScriptRoot '..' 'data' 'DealDesk.xlsx'),

    [string] $OutputPath
)

Import-Module (Join-Path $PSScriptRoot '..' 'Jev.psd1') -Force

if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Deal workbook not found: $Path"
}

$sourcePath = (Resolve-Path -LiteralPath $Path).Path
if (-not $OutputPath) {
    $directory = Split-Path -Path $sourcePath -Parent
    $name = [System.IO.Path]::GetFileNameWithoutExtension($sourcePath)
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $OutputPath = Join-Path $directory "$name-review-$stamp.xlsx"
}
$reviewPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
if ([string]::Equals($sourcePath, $reviewPath, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'OutputPath must differ from the deal workbook.'
}
if (Test-Path -LiteralPath $reviewPath) {
    throw "Review workbook already exists: $reviewPath. Choose a new OutputPath."
}

$fieldRows = @(Import-Excel -Path $sourcePath -WorksheetName Deal)
$deal = @{}
foreach ($row in $fieldRows) {
    $fieldName = [string] $row.Field
    if ([string]::IsNullOrWhiteSpace($fieldName)) { continue }
    if ($deal.ContainsKey($fieldName)) { throw "Duplicate deal field: $fieldName" }
    $deal[$fieldName] = $row.Value
}

$required = @(
    'Customer', 'Product', 'Units', 'AnnualListPricePerUnit', 'AnnualCostPerUnit',
    'CurrentDiscountPct', 'RequestedDiscountPct', 'MinimumGrossMarginPct',
    'TermMonths', 'TargetAnnualBudget', 'BuyerNotes', 'SalesGoal'
)
foreach ($name in $required) {
    if (-not $deal.ContainsKey($name) -or [string]::IsNullOrWhiteSpace([string] $deal[$name])) {
        throw "Deal sheet is missing a value for $name."
    }
}

try {
    $units = [int] $deal.Units
    $listPrice = [decimal] $deal.AnnualListPricePerUnit
    $unitCost = [decimal] $deal.AnnualCostPerUnit
    $currentDiscount = [decimal] $deal.CurrentDiscountPct
    $requestedDiscount = [decimal] $deal.RequestedDiscountPct
    $minimumMargin = [decimal] $deal.MinimumGrossMarginPct
    $termMonths = [int] $deal.TermMonths
    $budget = [decimal] $deal.TargetAnnualBudget
}
catch {
    throw "Deal sheet contains an invalid number: $_"
}
if ($units -le 0 -or $listPrice -le 0 -or $unitCost -lt 0 -or $termMonths -le 0 -or $budget -le 0) {
    throw 'Units, list price, term, and budget must be positive; unit cost cannot be negative.'
}
if ($currentDiscount -lt 0 -or $currentDiscount -ge 100 -or
    $requestedDiscount -lt 0 -or $requestedDiscount -ge 100 -or
    $minimumMargin -lt 0 -or $minimumMargin -ge 100) {
    throw 'Discounts and minimum margin must be percentages from 0 up to (but not including) 100.'
}

$candidateMoves = @(
    [pscustomobject]@{
        Code = 'hold'; Move = 'Hold the current offer'; Units = $units
        DiscountPct = $currentDiscount; TermMonths = $termMonths
        Trade = 'No new concession; explain the value of the current offer.'
    }
    [pscustomobject]@{
        Code = 'direct'; Move = 'Meet the requested discount'; Units = $units
        DiscountPct = $requestedDiscount; TermMonths = $termMonths
        Trade = 'Give the requested discount without asking for a commitment.'
    }
    [pscustomobject]@{
        Code = 'term'; Move = 'Trade discount for a longer term'; Units = $units
        DiscountPct = $requestedDiscount; TermMonths = [math]::Max(24, $termMonths + 12)
        Trade = 'Offer the requested discount in return for a longer commitment.'
    }
    [pscustomobject]@{
        Code = 'volume'; Move = 'Trade discount for more units'; Units = [int][math]::Ceiling($units * 1.25)
        DiscountPct = $requestedDiscount; TermMonths = $termMonths
        Trade = 'Offer the requested discount if the buyer increases quantity by 25%.'
    }
    [pscustomobject]@{
        Code = 'scope'; Move = 'Reduce scope to fit the budget'; Units = [int][math]::Max(1, [math]::Floor($units * 0.75))
        DiscountPct = $currentDiscount; TermMonths = $termMonths
        Trade = 'Keep the current discount and offer 25% fewer units.'
    }
)

$options = foreach ($move in $candidateMoves) {
    $annualRevenue = [decimal] $move.Units * $listPrice * (1 - [decimal] $move.DiscountPct / 100)
    $annualCost = [decimal] $move.Units * $unitCost
    $annualProfit = $annualRevenue - $annualCost
    $marginPct = if ($annualRevenue -gt 0) { 100 * $annualProfit / $annualRevenue } else { 0 }

    [pscustomobject][ordered]@{
        Code = $move.Code
        Move = $move.Move
        Units = $move.Units
        DiscountPct = $move.DiscountPct
        TermMonths = $move.TermMonths
        AnnualRevenue = [math]::Round($annualRevenue, 2)
        AnnualGrossProfit = [math]::Round($annualProfit, 2)
        GrossMarginPct = [math]::Round($marginPct, 2)
        MeetsMarginFloor = $marginPct -ge $minimumMargin
        MeetsBuyerBudget = $annualRevenue -le $budget
        Trade = $move.Trade
    }
}

# Moves below the margin floor or above the buyer's budget remain visible for
# comparison, but cannot be recommended without a separate human decision.
$eligible = @($options | Where-Object { $_.MeetsMarginFloor -and $_.MeetsBuyerBudget })
$criteria = [ordered]@{}
foreach ($option in $eligible) {
    $criteria[$option.Code] = "$($option.Move). $($option.Trade) Annual revenue $($option.AnnualRevenue); gross profit $($option.AnnualGrossProfit); margin $($option.GrossMarginPct)%."
}
$criteria['review'] = 'Pause the quote for human review when none of the available moves fits the buyer context or sales goal.'

$question = New-JevQuestion -Name move -Type Choice -Criteria $criteria -Instructions @'
Choose the best next negotiation move for this deal from the supplied options.
Use the buyer notes and sales goal. Prefer a move the buyer could realistically accept,
that preserves value for the seller. Budget and margin figures are calculated facts.
Do not assume a longer term or more units is acceptable unless the buyer context supports it.
Choose review if the supplied moves do not fit. Do not invent a different move.
'@

$decision = Invoke-Jev -State ([pscustomobject]@{
    Customer = [string] $deal.Customer
    Product = [string] $deal.Product
    BuyerNotes = [string] $deal.BuyerNotes
    SalesGoal = [string] $deal.SalesGoal
    TargetAnnualBudget = $budget
    CurrentTermMonths = $termMonths
    Options = $eligible
}) -Question $question

$chosenCode = [string] $decision.move
if ($chosenCode -notin @($criteria.Keys)) {
    throw "Jev returned a move that was not offered: $chosenCode"
}
$chosen = $options | Where-Object Code -eq $chosenCode | Select-Object -First 1
$confidence = [math]::Round([double] $decision.answers.move.confidence, 2)

$recommendation = [pscustomobject][ordered]@{
    Customer = [string] $deal.Customer
    Product = [string] $deal.Product
    RecommendedMove = if ($chosen) { $chosen.Move } else { 'Pause for human review' }
    Confidence = $confidence
    Trade = if ($chosen) { $chosen.Trade } else { 'Review the deal and buyer constraints before quoting.' }
    BuyerNotes = [string] $deal.BuyerNotes
    SalesGoal = [string] $deal.SalesGoal
    MinimumGrossMarginPct = $minimumMargin
    TargetAnnualBudget = $budget
}

$reviewOptions = @($options | Select-Object *, @{ Name = 'Recommended'; Expression = { $_.Code -eq $chosenCode } })
$recommendationRows = foreach ($property in $recommendation.PSObject.Properties) {
    [pscustomobject]@{ Field = $property.Name; Value = $property.Value }
}
$recommendationRows | Export-Excel -Path $reviewPath -WorksheetName Recommendation -AutoSize -BoldTopRow -FreezeTopRow -TableName DealRecommendation
$reviewOptions | Export-Excel -Path $reviewPath -WorksheetName Options -AutoSize -BoldTopRow -FreezeTopRow -TableName DealOptions

$package = Open-ExcelPackage -Path $reviewPath
try {
    $summarySheet = $package.Workbook.Worksheets['Recommendation']
    $summarySheet.Column(1).Width = 30
    $summarySheet.Column(2).Width = 85
    $summarySheet.Cells['B2:B10'].Style.WrapText = $true
    $summarySheet.Row(6).Height = 42
    $summarySheet.Row(7).Height = 56
    $summarySheet.Row(8).Height = 42

    $optionsSheet = $package.Workbook.Worksheets['Options']
    $optionsSheet.Column(2).Width = 42
    $optionsSheet.Column(11).Width = 70
    $optionsSheet.Cells['F2:G6'].Style.Numberformat.Format = '$#,##0.00'
    $optionsSheet.Cells['H2:H6'].Style.Numberformat.Format = '0.0"%"'
    $optionsSheet.Cells['D2:D6'].Style.Numberformat.Format = '0.0"%"'
    $optionsSheet.Cells['K2:K6'].Style.WrapText = $true
    foreach ($rowNumber in 2..6) {
        $optionsSheet.Row($rowNumber).Height = 38
        if ($optionsSheet.Cells[$rowNumber, 12].Value -eq $true) {
            $range = $optionsSheet.Cells["A$rowNumber`:L$rowNumber"]
            $range.Style.Fill.PatternType = 'Solid'
            $range.Style.Fill.BackgroundColor.SetColor([System.Drawing.Color]::FromArgb(255, 221, 242, 225))
        }
        elseif ($optionsSheet.Cells[$rowNumber, 9].Value -eq $false) {
            $range = $optionsSheet.Cells["A$rowNumber`:L$rowNumber"]
            $range.Style.Fill.PatternType = 'Solid'
            $range.Style.Fill.BackgroundColor.SetColor([System.Drawing.Color]::FromArgb(255, 252, 232, 230))
        }
    }
}
finally {
    Close-ExcelPackage -ExcelPackage $package
}

Write-Host "Recommended move: $($recommendation.RecommendedMove) (confidence $confidence)" -ForegroundColor Cyan
Write-Host "Review workbook: $reviewPath" -ForegroundColor Cyan
$reviewOptions | Format-Table Move, Units, DiscountPct, TermMonths, AnnualRevenue, GrossMarginPct, MeetsBuyerBudget, MeetsMarginFloor, Recommended -AutoSize

[pscustomobject]@{
    Path = $reviewPath
    Recommendation = $recommendation
    Options = $reviewOptions
}
