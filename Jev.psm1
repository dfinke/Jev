<##
.SYNOPSIS
    PowerShell-friendly commands for making structured decisions with Jev.
#>

$privatePath = Join-Path $PSScriptRoot 'Private'
$publicPath = Join-Path $PSScriptRoot 'Public'

foreach ($script in Get-ChildItem -LiteralPath $privatePath -Filter '*.ps1' -File | Sort-Object Name) {
    . $script.FullName
}

foreach ($script in Get-ChildItem -LiteralPath $publicPath -Filter '*.ps1' -File | Sort-Object Name) {
    . $script.FullName
}

Export-ModuleMember -Function @(
    'Invoke-Jev'
    'New-JevChoice'
    'New-JevQuestion'
)
