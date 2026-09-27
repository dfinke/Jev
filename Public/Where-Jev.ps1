<#
.SYNOPSIS
    Filters pipeline objects using a plain-English condition evaluated by Jev.

.DESCRIPTION
    A semantic pipeline filter analogous to Where-Object. Evaluates each pipeline
    object against a plain-language condition (or Jev question), emitting only
    objects whose probability or score meets the specified threshold.

.PARAMETER InputObject
    The pipeline object to evaluate.

.PARAMETER Condition
    A plain-English condition string. A Noul question is automatically constructed
    from this string.

.PARAMETER Question
    An existing Jev question object to evaluate against each pipeline object.

.PARAMETER Threshold
    The minimum probability required for an object to pass the filter. Defaults to 0.7.

.PARAMETER PassThruOriginal
    When specified, emits the original unmodified object instead of the Jev-enriched object.

.PARAMETER Mock
    Runs evaluation using the offline mock.

.PARAMETER MockOnMissingKey
    Uses mock mode if TYPESAFE_API_KEY is not set.

.EXAMPLE
    Get-Service | Where-Jev 'Is this service related to networking or web hosting?' -Threshold 0.75 -Mock

.EXAMPLE
    $logs | Where-Jev -Condition 'Does this log entry indicate an authentication failure or intrusion?' -Mock
#>
function Where-Jev {
    [CmdletBinding(DefaultParameterSetName = 'Condition')]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object] $InputObject,
        [Parameter(ParameterSetName = 'Condition', Position = 0, Mandatory)]
        [string] $Condition,
        [Parameter(ParameterSetName = 'Question', Position = 0, Mandatory)]
        [object] $Question,
        [double] $Threshold = 0.7,
        [switch] $PassThruOriginal,
        [switch] $Mock,
        [switch] $MockOnMissingKey
    )

    begin {
        $activeQuestion = if ($PSCmdlet.ParameterSetName -eq 'Condition') { New-JevQuestion -Name 'filter_decision' -Type Noul -Instructions $Condition }
        else { $Question }
    }

    process {
        if ($null -eq $InputObject) { return }

        $invokeParams = @{
            State    = $InputObject
            Question = $activeQuestion
        }
        if ($Mock) { $invokeParams.Mock = $true }
        if ($MockOnMissingKey) { $invokeParams.MockOnMissingKey = $true }

        $result = Invoke-Jev @invokeParams
        $passed = $false

        $qName = [string] $activeQuestion.Name
        if ($result.PSObject.Properties[$qName]) {
            $val = [double] $result.$qName
            $passed = ($val -ge $Threshold)
        }
        elseif ($result.answers -and $result.answers.$qName) {
            $ans = $result.answers.$qName
            if ($ans.PSObject.Properties['noul']) { $passed = ([double] $ans.noul -ge $Threshold) }
            elseif ($ans.PSObject.Properties['score']) { $passed = ([double] $ans.score -ge $Threshold) }
        }

        if ($passed) {
            if ($PassThruOriginal) { $InputObject }
            else { $result }
        }
    }
}
