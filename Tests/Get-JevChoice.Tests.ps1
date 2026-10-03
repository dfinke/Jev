BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'Jev.psd1') -Force
}

AfterAll {
    Remove-Module Jev -Force -ErrorAction SilentlyContinue
}

Describe 'Get-JevChoice compact label selection' {
    BeforeEach {
        Mock -ModuleName Jev Invoke-JevDecision {
            param($State, $Questions)
            $Questions.Count | Should -Be 1
            $Questions.selection.type | Should -Be 'choice'
            $Questions.selection.instructions | Should -Be 'Which team owns this request?'
            @($Questions.selection.criteria.Keys) | Should -Be @('billing', 'shipping', 'account', 'other')
            $Questions.selection.criteria['billing'] | Should -Be 'billing'
            $selected = switch ($State) {
                'Refund please.' { 'billing' }
                'Order missing.' { 'shipping' }
                'Cannot sign in.' { 'account' }
                default { 'other' }
            }
            [pscustomobject]@{
                answers = @{ selection = @{ type = 'choice'; choice = $selected; confidence = 0.9 } }
            }
        }
    }

    It 'binds the question and all remaining choices without stealing the pipeline state' {
        $result = 'Refund please.' |
            Get-JevChoice 'Which team owns this request?' billing shipping account other

        $result | Should -BeExactly 'billing'
        $result | Should -BeOfType [string]
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 1 -Scope It -ParameterFilter {
            $State -eq 'Refund please.'
        }
    }

    It 'returns one label per input in input order' {
        $results = @(@('Order missing.', 'Cannot sign in.', 'Refund please.', 'Feature suggestion.') |
            Get-JevChoice 'Which team owns this request?' billing shipping account other)

        $results | Should -Be @('shipping', 'account', 'billing', 'other')
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 4 -Scope It
    }

    It 'accepts named state and a named choices array' {
        $result = Get-JevChoice -State 'Order missing.' -Question 'Which team owns this request?' `
            -Choices @('billing', 'shipping', 'account', 'other')

        $result | Should -Be 'shipping'
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 1 -Scope It
    }

    It 'accepts a named question with trailing choices and common parameters' {
        $result = 'Cannot sign in.' |
            Get-JevChoice -Question 'Which team owns this request?' billing shipping account other -ErrorAction Stop

        $result | Should -Be 'account'
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 1 -Scope It
    }

    It 'passes objects unchanged as request state without modifying their properties' {
        $record = [pscustomobject]@{ Id = 42; Message = 'Refund please.'; selection = 'Existing data' }
        Mock -ModuleName Jev Invoke-JevDecision {
            param($State, $Questions)
            [object]::ReferenceEquals($State, $record) | Should -BeTrue
            [pscustomobject]@{ answers = @{ selection = @{ choice = 'billing' } } }
        }
        $result = $record | Get-JevChoice 'Which team owns this request?' billing shipping account other

        $result | Should -Be 'billing'
        $record.selection | Should -Be 'Existing data'
        @($record.PSObject.Properties.Name) | Should -Be @('Id', 'Message', 'selection')
    }

    It 'keeps a named array as one state and supports dictionary responses' {
        $stateArray = @('Refund please.', 'Duplicate payment.')
        Mock -ModuleName Jev Invoke-JevDecision {
            param($State, $Questions)
            [object]::ReferenceEquals($State, $stateArray) | Should -BeTrue
            @{ answers = @{ selection = @{ choice = 'billing' } } }
        }
        $result = Get-JevChoice -State $stateArray 'Which team owns this request?' billing shipping account other

        $result | Should -Be 'billing'
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 1 -Scope It
    }

    It 'accepts quoted multi-word labels and preserves their spelling' {
        Mock -ModuleName Jev Invoke-JevDecision {
            param($State, $Questions)
            @($Questions.selection.criteria.Keys) | Should -Be @('account access', 'technical support', 'Other')
            @{ answers = @{ selection = @{ choice = 'ACCOUNT ACCESS' } } }
        }
        $result = 'Cannot sign in.' |
            Get-JevChoice 'Which team owns this request?' 'account access' 'technical support' Other

        $result | Should -BeExactly 'account access'
    }

    It 'does not add an implicit fallback or apply a confidence threshold' {
        Mock -ModuleName Jev Invoke-JevDecision {
            param($State, $Questions)
            $Questions.selection.criteria.Count | Should -Be 2
            @{ answers = @{ selection = @{ choice = 'shipping'; confidence = 0.1 } } }
        }
        'Order missing.' | Get-JevChoice 'Which team owns this request?' billing shipping |
            Should -Be 'shipping'
    }

    It 'makes no request for empty pipeline input' {
        @(@() | Get-JevChoice 'Which team owns this request?' billing shipping account other).Count | Should -Be 0
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 0 -Scope It
    }

    It 'accepts the 255-label boundary' {
        $labels = @(1..255 | ForEach-Object { "label$_" })
        Mock -ModuleName Jev Invoke-JevDecision {
            param($State, $Questions)
            $Questions.selection.criteria.Count | Should -Be 255
            @{ answers = @{ selection = @{ choice = 'label255' } } }
        }
        'A message.' | Get-JevChoice 'Which team owns this request?' -Choices $labels |
            Should -Be 'label255'
    }

    It 'rejects too many labels before making a request' {
        $labels = @(1..256 | ForEach-Object { "label$_" })
        { 'A message.' | Get-JevChoice 'Which team owns this request?' -Choices $labels } | Should -Throw
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 0 -Scope It
    }

    It 'rejects empty labels: <Case>' -TestCases @(
        @{ Case = 'empty array'; Labels = @() }
        @{ Case = 'empty element'; Labels = @('billing', '') }
        @{ Case = 'whitespace element'; Labels = @('billing', ' ') }
    ) {
        param($Case, $Labels)
        { 'A message.' | Get-JevChoice 'Which team owns this request?' -Choices $Labels } | Should -Throw
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 0 -Scope It
    }

    It 'rejects duplicate labels ignoring case before making a request' {
        { 'A message.' | Get-JevChoice 'Which team owns this request?' billing Billing shipping } |
            Should -Throw '*case-insensitive*'
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 0 -Scope It
    }

    It 'rejects an unknown returned label rather than treating it as other' {
        Mock -ModuleName Jev Invoke-JevDecision {
            @{ answers = @{ selection = @{ choice = 'sales' } } }
        }
        { 'A message.' | Get-JevChoice 'Which team owns this request?' billing shipping account other } |
            Should -Throw '*unknown choice*'
    }

    It 'rejects missing response fields: <Case>' -TestCases @(
        @{ Case = 'answers'; Response = [pscustomobject]@{ model = 'test' } }
        @{ Case = 'selection'; Response = [pscustomobject]@{ answers = @{} } }
        @{ Case = 'choice'; Response = [pscustomobject]@{ answers = @{ selection = @{ confidence = 0.9 } } } }
        @{ Case = 'null choice'; Response = [pscustomobject]@{ answers = @{ selection = @{ choice = $null } } } }
    ) {
        param($Case, $Response)
        Mock -ModuleName Jev Invoke-JevDecision { $Response }
        { 'A message.' | Get-JevChoice 'Which team owns this request?' billing shipping account other } |
            Should -Throw '*Jev did not return*'
    }

    It 'propagates request failures without fabricating a label' {
        Mock -ModuleName Jev Invoke-JevDecision { throw 'API unavailable.' }
        $emitted = [System.Collections.Generic.List[object]]::new()
        { 'A message.' | Get-JevChoice 'Which team owns this request?' billing shipping account other |
                ForEach-Object { $emitted.Add($_) } } | Should -Throw '*API unavailable*'
        $emitted.Count | Should -Be 0
    }
}
