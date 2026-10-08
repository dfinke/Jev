BeforeAll {
    . "$PSScriptRoot/Import-LoanPolicy.ps1"
}

Describe 'Reading an editable loan policy' {
    It 'loads all four named choices and multiline instructions' {
        $policy = Import-LoanPolicy
        $policy.Instructions | Should -Match 'earliest matching rule wins'
        @($policy.Criteria.Keys) | Should -Be @('Amount too high', 'Credit review', 'Debt too high', 'Approve')
        $policy.Criteria['Credit review'] | Should -Match 'overrides the debt ratio rule'
    }

    It 'loads human edits and supports <Ending> line endings' -TestCases @(
        @{ Ending = 'LF'; Newline = "`n" }
        @{ Ending = 'CRLF'; Newline = "`r`n" }
    ) {
        param($Ending, $Newline)
        $path = Join-Path $TestDrive 'Policy.md'
        $text = @('# Instructions', '', 'Use the edited policy.', '', '# Choices', '', '## Approve', 'An edited description.', 'Continues on another line.') -join $Newline
        Set-Content -LiteralPath $path -Value $text -NoNewline
        $policy = Import-LoanPolicy -Path $path
        $policy.Instructions | Should -Be 'Use the edited policy.'
        $policy.Criteria['Approve'] | Should -Be ("An edited description.${Newline}Continues on another line.")
    }

    It 'rejects <Case>' -TestCases @(
        @{ Case = 'missing choices section'; Lines = @('# Instructions', 'Apply the rules.') }
        @{ Case = 'empty instructions'; Lines = @('# Instructions', '# Choices', '## Approve', 'Allowed.') }
        @{ Case = 'missing choice descriptions'; Lines = @('# Instructions', 'Apply the rules.', '# Choices', '## Approve') }
        @{ Case = 'an empty last choice'; Lines = @('# Instructions', 'Apply the rules.', '# Choices', '## Approve', 'Allowed.', '## Deny') }
        @{ Case = 'duplicate names ignoring case'; Lines = @('# Instructions', 'Apply the rules.', '# Choices', '## Approve', 'Allowed.', '## approve', 'Also allowed.') }
    ) {
        param($Case, $Lines)
        $path = Join-Path $TestDrive 'Invalid.md'
        Set-Content -LiteralPath $path -Value ($Lines -join "`n") -NoNewline
        { Import-LoanPolicy -Path $path } | Should -Throw
    }
}
