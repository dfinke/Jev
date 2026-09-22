[CmdletBinding()]
param(
    [string] $NuGetApiKey = $env:NuGetApiKey,

    [ValidateNotNullOrEmpty()]
    [string] $Repository = 'PSGallery'
)

if ([string]::IsNullOrWhiteSpace($NuGetApiKey)) {
    throw 'Set $env:NuGetApiKey or pass -NuGetApiKey before publishing.'
}

$manifestPath = Join-Path $PSScriptRoot 'Jev.psd1'
$manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop

if ($manifest.Name -ne 'Jev') {
    throw "Expected Jev.psd1 to describe the Jev module, but found '$($manifest.Name)'."
}

Publish-Module `
    -Path $PSScriptRoot `
    -Repository $Repository `
    -NuGetApiKey $NuGetApiKey
