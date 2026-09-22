[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $NuGetApiKey,

    [ValidateNotNullOrEmpty()]
    [string] $Repository = 'PSGallery'
)

$manifestPath = Join-Path $PSScriptRoot 'Jev.psd1'
$manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop

if ($manifest.Name -ne 'Jev') {
    throw "Expected Jev.psd1 to describe the Jev module, but found '$($manifest.Name)'."
}

Publish-Module `
    -Path $PSScriptRoot `
    -Repository $Repository `
    -NuGetApiKey $NuGetApiKey
