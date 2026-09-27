<#
.SYNOPSIS
    Clears registered dynamic mock rules.

.DESCRIPTION
    Removes registered custom mock rules from the Jev session. If QuestionName
    is specified, only rules for that question are removed. Otherwise, all rules
    are cleared.

.PARAMETER QuestionName
    Optional question name whose rules should be removed.

.EXAMPLE
    Clear-JevMockRule
    Clear-JevMockRule -QuestionName 'churn'
#>
function Clear-JevMockRule {
    [CmdletBinding()]
    param(
        [string] $QuestionName
    )

    if (Get-Variable -Name 'JevMockRules' -Scope Script -ErrorAction SilentlyContinue) {
        if ([string]::IsNullOrWhiteSpace($QuestionName)) {
            $script:JevMockRules.Clear()
        }
        else {
            for ($i = $script:JevMockRules.Count - 1; $i -ge 0; $i--) {
                if ($script:JevMockRules[$i].QuestionName -eq $QuestionName) {
                    $script:JevMockRules.RemoveAt($i)
                }
            }
        }
    }
}
