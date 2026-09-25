<#
.SYNOPSIS
    Adds the Jev script method to arrays when the module loads.

.DESCRIPTION
    The method evaluates each array record with a Noul question. Restores
    the previous array type data when the module is removed.
#>
function Register-JevTypeData {
    [CmdletBinding()]
    param()

    $existingArrayTypeData = Get-TypeData -TypeName System.Array

    $arrayMethod = {
        param(
            [Parameter(Mandatory, Position = 0)]
            [ValidateNotNullOrEmpty()]
            [string] $Condition
        )

        $question = New-JevQuestion -Name decision -Type Noul -Instructions $Condition

        foreach ($record in $this) {
            Invoke-Jev -State $record -Question $question
        }
    }

    Update-TypeData -TypeName System.Array `
        -MemberType ScriptMethod `
        -MemberName Jev `
        -Value $arrayMethod `
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
