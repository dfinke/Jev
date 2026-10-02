#requires -Version 7.0

<#
.SYNOPSIS
    Classifies grocery-list items by store section and storage handling.

.DESCRIPTION
    Reads grocery items and their context from a CSV, asks Jev two bounded
    Choice questions for each item in one request, then uses PowerShell to
    group the results into a practical shopping view.

.EXAMPLE
    $env:TYPESAFE_API_KEY = 'your-api-key'
    ./Classify-GroceryList.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\..\Jev.psd1') -Force

$listPath = Join-Path $PSScriptRoot 'grocery-list.csv'
$groceryItems = @(Import-Csv -LiteralPath $listPath)

$questions = @(
    New-JevQuestion -Name section -Type Choice `
        -Instructions 'Which store section is the best place to find the grocery item described in `Item` and `Context`?' `
        -Criteria @{
            produce          = 'Fresh fruits, vegetables, and herbs.'
            dairy_eggs       = 'Milk, cheese, yogurt, eggs, and refrigerated dairy alternatives.'
            meat_seafood     = 'Fresh meat, poultry, or seafood.'
            bakery           = 'Fresh bread and baked goods.'
            center_aisle     = 'Shelf-stable packaged foods and beverages.'
            frozen           = 'Frozen food stored in a freezer.'
            household        = 'Cleaning and other non-food household supplies.'
            other            = 'The item does not fit the listed store sections.'
        }

    New-JevQuestion -Name storage -Type Choice `
        -Instructions 'How should this item be stored before it is used, based on `Item` and `Context`?' `
        -Criteria @{
            refrigerated         = 'Keep chilled in a refrigerator.'
            frozen               = 'Keep frozen in a freezer.'
            shelf_stable         = 'Can be kept unopened at room temperature in a pantry or cupboard.'
            room_temperature     = 'Keep at room temperature; it is fresh produce or bakery food.'
            other                = 'The storage need cannot be determined from the item and context.'
        }
)

Write-Host "Classifying $($groceryItems.Count) grocery items; each item gets one Jev request with both questions." -ForegroundColor Cyan

$results = foreach ($item in $groceryItems) {
    $decision = Invoke-Jev -State $item -Question $questions

    [pscustomobject]@{
        Item                = $decision.Item
        Context             = $decision.Context
        Section             = $decision.section
        SectionConfidence   = [math]::Round([double] $decision.answers.section.confidence, 2)
        Storage             = $decision.storage
        StorageConfidence   = [math]::Round([double] $decision.answers.storage.confidence, 2)
    }
}

Write-Host "`nShopping list by store section" -ForegroundColor Green
$results | Sort-Object Section, Item | Format-Table Item, Section, SectionConfidence, Storage, StorageConfidence -Wrap -AutoSize

Write-Host "`nItems per section" -ForegroundColor Green
$results | Group-Object Section | Sort-Object Name | Select-Object Name, Count | Format-Table -AutoSize

Write-Host 'Confidence values are available on each result if you want to review uncertain classifications.' -ForegroundColor DarkGray
