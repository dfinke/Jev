[CmdletBinding()]
param(
    [string] $FullPath
)

$moduleName = 'Jev'
$sourcePath = (Resolve-Path $PSScriptRoot).Path

if ([string]::IsNullOrWhiteSpace($FullPath)) {
    $moduleRoot = @(
        $env:PSModulePath -split [System.IO.Path]::PathSeparator |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -and $_ -notlike "$PSHOME*" } |
            Select-Object -First 1
    )

    if ($moduleRoot.Count -eq 0) {
        throw 'Could not find a module directory in PSModulePath. Pass -FullPath explicitly.'
    }

    $FullPath = Join-Path $moduleRoot[0] $moduleName
}

$targetPath = [System.IO.Path]::GetFullPath($FullPath)
New-Item -ItemType Directory -Path (Split-Path -Parent $targetPath) -Force | Out-Null

$robocopyArguments = @(
    $sourcePath
    $targetPath
    '/MIR'
    '/XD'
    '.git'
    '.github'
    '.vscode'
    'Examples'
    'Tests'
    '/XF'
    'InstallModule.ps1'
    'PublishToGallery.ps1'
    'README.md'
    'LICENSE'
    'testResults.xml'
)

& robocopy @robocopyArguments
$robocopyExitCode = $LASTEXITCODE

# Robocopy uses 0-7 for success and success-with-differences statuses.
if ($robocopyExitCode -gt 7) {
    throw "Robocopy failed with exit code $robocopyExitCode."
}

Write-Output "Installed $moduleName to $targetPath."
