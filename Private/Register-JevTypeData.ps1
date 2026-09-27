<#
.SYNOPSIS
    Adds Jev script methods to arrays when the module loads.

.DESCRIPTION
    Extends System.Array with:
      - .Jev(ConditionOrQuestions, [switch]$Mock): Evaluates array records against a condition or Jev questions.
      - .JevWhere(Condition, [double]$Threshold, [switch]$Mock): Filters array elements based on a semantic condition.
      - .JevRank(Query, [string]$Property, [int]$Top, [switch]$Mock): Reranks array elements by relevance.
#>
function Register-JevTypeData {
    [CmdletBinding()]
    param()

    $existingArrayTypeData = Get-TypeData -TypeName System.Array

    $arrayJevMethod = {
        param(
            [Parameter(Mandatory, Position = 0)]
            [ValidateNotNullOrEmpty()]
            [object] $ConditionOrQuestion,

            [switch] $Mock
        )

        $questions = if ($ConditionOrQuestion -is [string]) {
            @(
                New-JevQuestion -Name decision 
                                -Type Noul 
                                -Instructions $ConditionOrQuestion
            )
        }
        else {
            @($ConditionOrQuestion)
        }

        $invokeParams = @{
            Question = $questions
        }
        if ($Mock.IsPresent) { $invokeParams.Mock = $true }

        foreach ($record in $this) {
            Invoke-Jev -State $record @invokeParams
        }
    }

    $arrayJevWhereMethod = {
        param(
            [Parameter(Mandatory, Position = 0)]
            [string] $Condition,
            [double] $Threshold = 0.7,
            [switch] $Mock
        )

        $invokeParams = @{
            Condition = $Condition
            Threshold = $Threshold
        }
        if ($Mock.IsPresent) { $invokeParams.Mock = $true }

        @($this | Where-Jev @invokeParams)
    }

    $arrayJevRankMethod = {
        param(
            [Parameter(Mandatory, Position = 0)]
            [string] $Query,
            [string] $Property,
            [int] $Top = 0,
            [switch] $Mock
        )

        $invokeParams = @{
            Candidates = $this
            Query      = $Query
        }
        if ($Property) { $invokeParams.Property = $Property }
        if ($Top -gt 0) { $invokeParams.Top = $Top }
        if ($Mock.IsPresent) { $invokeParams.Mock = $true }

        @(Invoke-JevRerank @invokeParams)
    }

    Update-TypeData -TypeName System.Array `
        -MemberType ScriptMethod `
        -MemberName Jev `
        -Value $arrayJevMethod `
        -Force

    Update-TypeData -TypeName System.Array `
        -MemberType ScriptMethod `
        -MemberName JevWhere `
        -Value $arrayJevWhereMethod `
        -Force

    Update-TypeData -TypeName System.Array `
        -MemberType ScriptMethod `
        -MemberName JevRank `
        -Value $arrayJevRankMethod `
        -Force

    $module = $ExecutionContext.SessionState.Module
    if ($null -ne $module) {
        $module.OnRemove = {
            Remove-TypeData -TypeName System.Array -ErrorAction SilentlyContinue

            if ($null -ne $existingArrayTypeData) {
                Update-TypeData -TypeData $existingArrayTypeData -Force
            }
        }.GetNewClosure()
    }
}
