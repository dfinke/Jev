<##
.SYNOPSIS
    Evaluates one state value against named Jev questions.

.DESCRIPTION
    The Question definitions use the same type, instructions, and criteria
    names as the Jev JSON payload. Use Mock while developing without an API
    key.
#>
function Invoke-Jev {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [object] $InputObject,

        [Parameter(Mandatory)]
        [object[]] $Question,

        [string] $Model = 'jev-latest',

        [switch] $Mock,

        [switch] $MockOnMissingKey,

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
            State        = $InputObject
            Questions    = $questionsByName
            Model        = $Model
            Endpoint     = $Endpoint
            TimeoutSec   = $TimeoutSec
            MaxRetries   = $MaxRetries
            RetryDelayMs = $RetryDelayMs
        }
        if ($Mock) { $invokeParameters.UseMock = $true }
        if ($MockOnMissingKey) { $invokeParameters.MockOnMissingKey = $true }

        Invoke-JevDecision @invokeParameters
    }
}
