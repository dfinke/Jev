<#
.SYNOPSIS
    Records a live or mock Jev response into a reusable JSON fixture file.

.DESCRIPTION
    Executes a Jev request for the specified state and questions, and writes
    the request and raw API response to a structured JSON fixture. This allows
    capturing real model responses to be replayed offline in tests.

.PARAMETER Path
    The target file path for the JSON fixture.

.PARAMETER State
    The input state to evaluate.

.PARAMETER Question
    The Jev questions to evaluate.

.PARAMETER Mock
    Runs against the local mock instead of making a live API call.

.EXAMPLE
    Export-JevFixture -Path .\fixtures\billing_triage.json -State $ticket -Question $questions -Mock
#>
function Export-JevFixture {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string] $Path,
        [Parameter(Mandatory, Position = 1)]
        [object] $State,
        [Parameter(Mandatory, Position = 2)]
        [object[]] $Question,
        [switch] $Mock
    )
    $invokeParams = @{
        State    = $State
        Question = $Question
        Raw      = $true
    }
    if ($Mock) { $invokeParams.Mock = $true }
    $response = Invoke-Jev @invokeParams
    $fixture = [ordered]@{
        createdAt = (Get-Date -Format 'o')
        state     = $State
        questions = $Question
        response  = $response
    }
    $json = $fixture | ConvertTo-Json -Depth 50
    $fullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    $parent = Split-Path -Path $fullPath -Parent
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Set-Content -LiteralPath $fullPath -Value $json -Encoding utf8
    Get-Item -LiteralPath $fullPath
}
