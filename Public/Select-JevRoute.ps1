<#
.SYNOPSIS
    Routes pipeline objects to scriptblocks based on a Jev Choice decision.

.DESCRIPTION
    Implements the Intent Routing architectural pattern. Evaluates the pipeline
    object against a Choice question and dynamically dispatches execution to a
    corresponding scriptblock in the Routes hashtable.

.PARAMETER InputObject
    The pipeline object to evaluate and route.

.PARAMETER Question
    The Jev Choice question determining the route.

.PARAMETER Routes
    A hashtable mapping option keys to scriptblocks (e.g. @{ billing = { param($item) ... }; tech = { param($item) ... } }).

.PARAMETER Default
    An optional fallback scriptblock executed if the selected choice is not found in Routes.

.PARAMETER Mock
    Runs evaluation using the offline mock.

.PARAMETER MockOnMissingKey
    Uses mock mode if TYPESAFE_API_KEY is not set.

.EXAMPLE
    $tickets | Select-JevRoute -Question $deptQuestion -Routes @{
        billing   = { param($t) Process-BillingTicket $t }
        technical = { param($t) Assign-Engineering $t }
    } -Mock
#>
function Select-JevRoute {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object] $InputObject,
        [Parameter(Mandatory, Position = 0)]
        [object] $Question,
        [Parameter(Mandatory, Position = 1)]
        [System.Collections.IDictionary] $Routes,
        [scriptblock] $Default,
        [switch] $Mock,
        [switch] $MockOnMissingKey
    )

    process {
        if ($null -eq $InputObject) { return }
        $invokeParams = @{
            State    = $InputObject
            Question = $Question
        }
        if ($Mock) { $invokeParams.Mock = $true }
        if ($MockOnMissingKey) { $invokeParams.MockOnMissingKey = $true }
        $result = Invoke-Jev @invokeParams
        $qName  = [string] $Question.Name
        $selectedChoice = $null
        if ($result.PSObject.Properties[$qName]) {
            $selectedChoice = [string] $result.$qName
        }
        elseif ($result.answers -and 
                $result.answers.$qName) {
            $selectedChoice = [string] $result.answers.$qName.choice
        }
        if (-not [string]::IsNullOrWhiteSpace($selectedChoice) -and 
            $Routes.Contains($selectedChoice)) {
            $handler = $Routes[$selectedChoice]
            if ($handler -is [scriptblock]) {
                & $handler $InputObject $result
            }
            else {
                $handler
            }
        }
        elseif ($null -ne $Default) {
            & $Default $InputObject $result
        }
        else {
            Write-Verbose "No route handler for choice '$selectedChoice' and no default provided."
            $result
        }
    }
}
