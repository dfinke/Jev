<#
.SYNOPSIS
    Evaluates one state value against named Jev questions.

.DESCRIPTION
    The Question definitions use the same type, instructions, and criteria
    names as the Jev JSON payload. Use Mock while developing without an API
    key.

.PARAMETER State
    The input context Jev evaluates. This can be a string, object, or array.
    It maps to the state field in the Jev request payload.

.PARAMETER Question
    One or more questions created with New-JevQuestion or New-JevYesNoQuestion.

.PARAMETER Model
    The Jev model to use. Defaults to jev-latest.

.PARAMETER Mock
    Returns a deterministic local response without calling the API.

.PARAMETER MockOnMissingKey
    Uses the local mock only when TYPESAFE_API_KEY is missing.

.PARAMETER Raw
    Returns the raw Jev response without merging it with the input state.

.PARAMETER AsJson
    Returns the result as a JSON string for easy inspection or copying.
    Combine with Raw to serialize the raw Jev response instead of the merged result.

.PARAMETER Endpoint
    The Jev API endpoint.

.PARAMETER TimeoutSec
    Maximum time, in seconds, for each HTTP request.

.PARAMETER MaxRetries
    Number of retries for transient HTTP failures.

.PARAMETER RetryDelayMs
    Initial delay, in milliseconds, before retrying a transient failure.

.EXAMPLE
    'Checkout is unavailable.' | Invoke-Jev -Question (
        New-JevYesNoQuestion -Name pageOnCall -Question 'Page on-call now?' `
            -TrueCriteria 'Customers cannot purchase.' `
            -FalseCriteria 'Purchases work normally.'
    )
#>
function Invoke-Jev {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [Alias('InputObject')]
        [object] $State,

        [Parameter(Mandatory)]
        [object[]] $Question,

        [string] $Model = 'jev-latest',

        [switch] $Mock,

        [switch] $MockOnMissingKey,

        [switch] $Raw,

        [switch] $AsJson,

        [uri] $Endpoint = 'https://api.typesafe.ai/v1/systemone',

        [ValidateRange(1, 300)]
        [int] $TimeoutSec = 30,

        [ValidateRange(0, 5)]
        [int] $MaxRetries = 2,

        [ValidateRange(0, 10000)]
        [int] $RetryDelayMs = 250
    )

    process {
        $questionsByName = @{}
        foreach ($questionDefinition in $Question) {
            $questionName = [string] $questionDefinition.Name
            if ([string]::IsNullOrWhiteSpace($questionName)) {
                throw 'A Jev question has no name. Create it with New-JevQuestion -Name <unique-name>.'
            }
            if ($questionsByName.ContainsKey($questionName)) {
                throw "Duplicate Jev question name '$questionName'. Reset `$questions or remove the existing question before adding it."
            }

            $wireQuestion = [ordered]@{
                type         = ([string] $questionDefinition.Type).ToLowerInvariant()
                instructions = $questionDefinition.Instructions
            }

            $criteriaProperty = $questionDefinition.PSObject.Properties['Criteria']
            if ($null -ne $criteriaProperty -and $null -ne $questionDefinition.Criteria) {
                $wireQuestion['criteria'] = $questionDefinition.Criteria
            }

            $questionsByName.Add($questionName, [hashtable] $wireQuestion)
        }

        $invokeParameters = @{
            State        = $State
            Questions    = $questionsByName
            Model        = $Model
            Endpoint     = $Endpoint
            TimeoutSec   = $TimeoutSec
            MaxRetries   = $MaxRetries
            RetryDelayMs = $RetryDelayMs
        }
        if ($Mock) { $invokeParameters.UseMock = $true }
        if ($MockOnMissingKey) { $invokeParameters.MockOnMissingKey = $true }

        $response = Invoke-JevDecision @invokeParameters
        if ($Raw) {
            $result = $response
        }
        else {
            $result = ConvertTo-JevEnrichedResult -State $State -Response $response
        }

        if ($AsJson) {
            ConvertTo-Json -InputObject $result -Depth 100
        }
        else {
            $result
        }
    }
}
