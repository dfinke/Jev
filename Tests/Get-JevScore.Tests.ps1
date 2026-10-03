BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'Jev.psd1') -Force
}

AfterAll {
    Remove-Module Jev -Force -ErrorAction SilentlyContinue
}

Describe 'Get-JevScore ordered ratings' {
    BeforeEach {
        $levels = @('Can wait', 'Needs attention soon', 'Needs attention now')
        Mock -ModuleName Jev Invoke-JevDecision {
            param($State, $Questions)
            $Questions.Count | Should -Be 1
            $Questions.rating.type | Should -Be 'score'
            $Questions.rating.instructions | Should -Be 'How urgent is this?'
            $Questions.rating.criteria | Should -Be @('Can wait', 'Needs attention soon', 'Needs attention now')
            $score = switch ($State) {
                'No rush.' { 0.12 }
                'An event in two hours.' { 1.93 }
                default { 0.76 }
            }
            [pscustomobject]@{
                answers = @{ rating = @{ type = 'score'; score = $score; confidence = 0.8 } }
            }
        }
    }

    It 'binds quoted levels without commas and returns the unrounded weighted score' {
        $result = 'An event in two hours.' |
            Get-JevScore 'How urgent is this?' 'Can wait' 'Needs attention soon' 'Needs attention now'

        $result | Should -Be 1.93
        $result | Should -BeOfType [double]
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 1 -Scope It -ParameterFilter {
            $State -eq 'An event in two hours.'
        }
    }

    It 'returns one score per input in input order without sorting' {
        $results = @(@('An event in two hours.', 'No rush.', 'A current problem.') |
            Get-JevScore 'How urgent is this?' -Levels $levels)

        $results | Should -Be @(1.93, 0.12, 0.76)
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 3 -Scope It
    }

    It 'accepts fully named state, question, and levels' {
        Get-JevScore -State 'No rush.' -Question 'How urgent is this?' -Levels $levels |
            Should -Be 0.12
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 1 -Scope It
    }

    It 'accepts a named question and trailing levels with common parameters' {
        'An event in two hours.' | Get-JevScore -Question 'How urgent is this?' `
            'Can wait' 'Needs attention soon' 'Needs attention now' -ErrorAction Stop |
            Should -Be 1.93
    }

    It 'passes an object as the request state without altering its properties' {
        $record = [pscustomobject]@{ Id = 42; Message = 'A current problem.'; rating = 'Original field' }
        Mock -ModuleName Jev Invoke-JevDecision {
            param($State, $Questions)
            [object]::ReferenceEquals($State, $record) | Should -BeTrue
            [pscustomobject]@{ answers = @{ rating = @{ score = 1.3 } } }
        }

        $record | Get-JevScore 'How urgent is this?' -Levels $levels | Should -Be 1.3
        $record.rating | Should -Be 'Original field'
        @($record.PSObject.Properties.Name) | Should -Be @('Id', 'Message', 'rating')
    }

    It 'keeps a named array as one state and accepts dictionary responses' {
        $stateArray = @('An event.', 'In two hours.')
        Mock -ModuleName Jev Invoke-JevDecision {
            param($State, $Questions)
            [object]::ReferenceEquals($State, $stateArray) | Should -BeTrue
            @{ answers = @{ rating = @{ score = 1.9 } } }
        }

        Get-JevScore -State $stateArray 'How urgent is this?' -Levels $levels | Should -Be 1.9
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 1 -Scope It
    }

    It 'accepts a valid scale endpoint: <Score>' -TestCases @(
        @{ Score = 0 }
        @{ Score = 2 }
    ) {
        param($Score)
        Mock -ModuleName Jev Invoke-JevDecision {
            @{ answers = @{ rating = @{ score = $Score; confidence = 0.1 } } }
        }
        $result = 'A message.' | Get-JevScore 'How urgent is this?' -Levels $levels
        $result | Should -Be $Score
        $result | Should -BeOfType [double]
    }

    It 'supports the minimum two-level scale with a fractional score' {
        Mock -ModuleName Jev Invoke-JevDecision {
            param($State, $Questions)
            $Questions.rating.criteria | Should -Be @('Low', 'High')
            @{ answers = @{ rating = @{ score = 0.65 } } }
        }
        'A message.' | Get-JevScore 'How urgent is this?' Low High | Should -Be 0.65
    }

    It 'supports ten levels and their zero-based maximum of nine' {
        $tenLevels = @(0..9 | ForEach-Object { "Level $_" })
        Mock -ModuleName Jev Invoke-JevDecision {
            param($State, $Questions)
            $Questions.rating.criteria.Count | Should -Be 10
            @{ answers = @{ rating = @{ score = 9 } } }
        }
        'A message.' | Get-JevScore 'How urgent is this?' -Levels $tenLevels | Should -Be 9
    }

    It 'makes no request for empty pipeline input' {
        @(@() | Get-JevScore 'How urgent is this?' -Levels $levels).Count | Should -Be 0
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 0 -Scope It
    }

    It 'rejects invalid levels before making a request: <Case>' -TestCases @(
        @{ Case = 'empty array'; Levels = @() }
        @{ Case = 'one level'; Levels = @('Only one') }
        @{ Case = 'eleven levels'; Levels = @('0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10') }
        @{ Case = 'empty description'; Levels = @('Low', '') }
        @{ Case = 'whitespace description'; Levels = @('Low', ' ') }
    ) {
        param($Case, $Levels)
        { 'A message.' | Get-JevScore 'How urgent is this?' -Levels $Levels } | Should -Throw
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 0 -Scope It
    }

    It 'rejects missing answers rather than returning zero: <Case>' -TestCases @(
        @{ Case = 'answers'; Response = [pscustomobject]@{ model = 'test' } }
        @{ Case = 'rating'; Response = [pscustomobject]@{ answers = @{} } }
        @{ Case = 'score'; Response = [pscustomobject]@{ answers = @{ rating = @{ confidence = 0.9 } } } }
        @{ Case = 'null score'; Response = [pscustomobject]@{ answers = @{ rating = @{ score = $null } } } }
    ) {
        param($Case, $Response)
        Mock -ModuleName Jev Invoke-JevDecision { $Response }
        { 'A message.' | Get-JevScore 'How urgent is this?' -Levels $levels } |
            Should -Throw '*Jev did not return*'
    }

    It 'rejects invalid returned scores: <Score>' -TestCases @(
        @{ Score = -0.1 }
        @{ Score = 2.1 }
        @{ Score = [double]::NaN }
        @{ Score = [double]::PositiveInfinity }
        @{ Score = 'not numeric' }
        @{ Score = '' }
        @{ Score = $true }
    ) {
        param($Score)
        Mock -ModuleName Jev Invoke-JevDecision {
            @{ answers = @{ rating = @{ score = $Score } } }
        }
        { 'A message.' | Get-JevScore 'How urgent is this?' -Levels $levels } |
            Should -Throw '*invalid score*'
    }

    It 'propagates request failures without fabricating a score' {
        Mock -ModuleName Jev Invoke-JevDecision { throw 'API unavailable.' }
        $emitted = [System.Collections.Generic.List[object]]::new()
        { 'A message.' | Get-JevScore 'How urgent is this?' -Levels $levels |
                ForEach-Object { $emitted.Add($_) } } | Should -Throw '*API unavailable*'
        $emitted.Count | Should -Be 0
    }
}
