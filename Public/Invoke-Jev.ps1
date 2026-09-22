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

            $wireQuestion = @{
                type         = [string] $questionDefinition.Type
                instructions = $questionDefinition.Instructions
            }

            switch ($wireQuestion.type) {
                'Choice' {
                    $criteria = @{}
                    foreach ($choice in @($questionDefinition.Choice)) {
                        if ($null -eq $choice.Name -or $criteria.Contains([string] $choice.Name)) {
                            throw "Choice question '$questionName' has a duplicate or empty choice name."
                        }
                        $criteria[[string] $choice.Name] = $choice.Description
                    }
                    $wireQuestion = @{
                        type         = [string] $questionDefinition.Type
                        instructions = $questionDefinition.Instructions
                        criteria     = $criteria
                    }
                }
                'Score' {
                    $wireQuestion = @{
                        type         = [string] $questionDefinition.Type
                        instructions = $questionDefinition.Instructions
                        criteria     = @($questionDefinition.Level)
                    }
                }
                'Noul' {
                    if ($questionDefinition.PSObject.Properties['TrueCriteria'] -and $null -ne $questionDefinition.TrueCriteria -or
                        $questionDefinition.PSObject.Properties['FalseCriteria'] -and $null -ne $questionDefinition.FalseCriteria) {
                        $wireQuestion = @{
                            type         = [string] $questionDefinition.Type
                            instructions = $questionDefinition.Instructions
                            criteria     = @{
                                true  = $questionDefinition.TrueCriteria
                                false = $questionDefinition.FalseCriteria
                            }
                        }
                    }
                }
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
