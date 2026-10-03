<#
.SYNOPSIS
    Ranks inputs by their probability of meeting a yes/no Jev question.

.DESCRIPTION
    Asks the same Noul question about each input, then returns the original
    inputs in descending yes-probability order. Exact ties keep input order.
    Preserves object identity, types, and properties without modifying inputs.

    Each input makes one live request. Top limits the output, but every input
    is evaluated. Results are buffered until the input ends; use finite input.
    This is semantic ranking: inputs are judged independently, then sorted in
    PowerShell. The question should describe what belongs near the top.

.PARAMETER State
    The text or object to rank. Accepts pipeline input or -State.

.PARAMETER Question
    The yes/no question used to rank inputs. Accepts the first positional
    argument. Higher yes probabilities appear first.

.PARAMETER Top
    Returns at most this many inputs. Must be at least 1. Defaults to all
    inputs. All inputs still require evaluation.

.EXAMPLE
    $messages | Get-JevRanking 'Does this need urgent attention?'

    Returns the original messages, highest yes probability first.

.EXAMPLE
    $tickets | Get-JevRanking 'Does this need urgent attention?' -Top 3

    Returns the three highest-ranked original ticket objects.

.EXAMPLE
    $messages | Select-Jev 'Does this need a reply?' |
        Get-JevRanking 'Does this need urgent attention?' -Top 3

    Ranks only the messages selected by the first step.
#>
function Get-JevRanking {
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object] $State,

        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Question,

        [ValidateRange(1, [int]::MaxValue)]
        [int] $Top
    )

    begin {
        $jevQuestion = New-JevQuestion -Name ranking -Type Noul -Instructions $Question
        $rankedInputs = [System.Collections.Generic.List[object]]::new()
    }

    process {
        $response = Invoke-Jev -State $State -Question $jevQuestion -Raw -ErrorAction Stop
        $probability = Get-JevNoulProbability -Response $response -Name ranking
        if ([double]::IsNaN($probability) -or $probability -lt 0 -or $probability -gt 1) {
            throw "Jev returned an invalid probability for question 'ranking'."
        }

        $rankedInputs.Add([pscustomobject]@{ State = $State; Probability = $probability })
    }

    end {
        $orderedInputs = $rankedInputs | Sort-Object -Property Probability -Descending -Stable
        if ($PSBoundParameters.ContainsKey('Top')) {
            $orderedInputs = $orderedInputs | Select-Object -First $Top
        }

        foreach ($rankedInput in $orderedInputs) {
            $PSCmdlet.WriteObject($rankedInput.State, $false)
        }
    }
}
