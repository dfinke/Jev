<##
.SYNOPSIS
    Small PowerShell-friendly facade over Invoke-JevDecision.

.EXAMPLE
    . ./Jev.PowerShell.ps1

    $questions = @(
        New-JevQuestion -Name churn -Type Noul -Prompt 'Is this an active churn threat?'
        New-JevQuestion -Name urgency -Type Score -Prompt 'How urgent is this?' -Level 'Can wait' -Level 'This week' -Level 'Today'
    )

    $decision = Invoke-Jev -InputObject $feedback -Question $questions -Mock
#>

. (Join-Path $PSScriptRoot 'Invoke-JevDecision.ps1')

function New-JevQuestion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [ValidateSet('Noul', 'Choice', 'Score')]
        [string] $Type,

        [Parameter(Mandatory)]
        [Alias('Instructions')]
        [object] $Prompt,

        [object[]] $Level,

        [object[]] $Choice,

        [AllowNull()]
        [object] $TrueCriteria,

        [AllowNull()]
        [object] $FalseCriteria
    )

    $levelCount = if ($null -eq $Level) { 0 } else { $Level.Count }
    $choiceCount = if ($null -eq $Choice) { 0 } else { $Choice.Count }

    if ($Type -eq 'Score' -and $levelCount -lt 2) {
        throw "Score question '$Name' requires at least two -Level values."
    }

    if ($Type -eq 'Score' -and $levelCount -gt 10) {
        throw "Score question '$Name' cannot have more than 10 -Level values."
    }

    if ($Type -eq 'Choice' -and $choiceCount -eq 0) {
        throw "Choice question '$Name' requires at least one -Choice."
    }

    if ($Type -eq 'Choice' -and $choiceCount -gt 255) {
        throw "Choice question '$Name' cannot have more than 255 -Choice values."
    }

    if ($Type -ne 'Noul' -and ($PSBoundParameters.ContainsKey('TrueCriteria') -or $PSBoundParameters.ContainsKey('FalseCriteria'))) {
        throw "Only Noul question '$Name' accepts -TrueCriteria or -FalseCriteria."
    }

    if ($Type -eq 'Noul' -and ($levelCount -gt 0 -or $choiceCount -gt 0)) {
        throw "Noul question '$Name' does not accept -Level or -Choice."
    }

    [pscustomobject] [ordered] @{
        Name          = $Name
        Type          = $Type
        Instructions  = $Prompt
        Level         = @($Level)
        Choice        = @($Choice)
        TrueCriteria  = $TrueCriteria
        FalseCriteria = $FalseCriteria
    }
}

function New-JevChoice {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $Description
    )

    [pscustomobject] [ordered] @{
        Name        = $Name
        Description = $Description
    }
}

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

Export-ModuleMember -Function New-JevQuestion, New-JevChoice, Invoke-Jev
