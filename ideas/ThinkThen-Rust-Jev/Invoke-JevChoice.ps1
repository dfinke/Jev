function Invoke-JevChoice {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0)]
        [string] $Question,

        [Parameter(Mandatory, Position = 1, ValueFromRemainingArguments)]
        [string[]] $Choices,

        [Parameter(Mandatory, ValueFromPipeline)]
        [object] $State,

        [ValidateRange(0.0, 1.0)]
        [double] $Threshold = 0.0
    )

    begin {
        $criteria = [ordered]@{}
        foreach ($choice in $Choices) { $criteria[$choice] = $choice }
        $definition = New-JevQuestion -Name answer -Type Choice -Instructions $Question -Criteria $criteria
    }

    process {
        $result = Invoke-Jev -State $State -Question $definition
        if ($result.answers.answer.confidence -ge $Threshold) { $result.answer }
        else { 'not_sure' }
    }
}
