<#
.SYNOPSIS
    Registers a dynamic mock rule for offline testing and deterministic CI/CD pipelines.

.DESCRIPTION
    Configures the Jev mock engine to return specified answers when a question
    and state matcher match. This enables writing comprehensive offline tests for
    custom questions without requiring live API calls.

.PARAMETER QuestionName
    The name of the question to match.

.PARAMETER Matcher
    A scriptblock receiving the input state ($State). Should return $true if the rule matches.

.PARAMETER Answer
    The value to return: a float (0-1) for Noul, a string key for Choice, or a number for Score.

.PARAMETER Confidence
    The confidence value to return for Choice or Score questions. Defaults to 0.95.

.EXAMPLE
    Set-JevMockRule -QuestionName 'churn' -Matcher { $args[0].message -match 'cancel' } -Answer 0.98

.EXAMPLE
    Set-JevMockRule -QuestionName 'dept' -Matcher { $true } -Answer 'billing' -Confidence 0.92
#>
function Set-JevMockRule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $QuestionName,
        [Parameter(Mandatory, Position = 1)]
        [scriptblock] $Matcher,
        [Parameter(Mandatory, Position = 2)]
        [object] $Answer,
        [double] $Confidence = 0.95
    )

    if (-not (Get-Variable -Name 'JevMockRules' -Scope Script -ErrorAction SilentlyContinue)) {
        $script:JevMockRules = [System.Collections.Generic.List[object]]::new()
    }

    $rule = [pscustomobject] [ordered] @{
        QuestionName = $QuestionName
        Matcher      = $Matcher
        Answer       = $Answer
        Confidence   = $Confidence
    }

    $script:JevMockRules.Insert(0, $rule)
    $rule
}
