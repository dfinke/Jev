BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'Jev.psd1') -Force
}

AfterAll {
    Remove-Module Jev -Force -ErrorAction SilentlyContinue
}

Describe 'Find-Jev comparative search' {
    BeforeEach {
        Mock -ModuleName Jev Invoke-JevDecision {
            param($State, $Questions)

            $State | Should -Be 'Which entry explains the failure?'
            $Questions.Count | Should -Be 1
            $Questions.match.type | Should -Be 'choice'
            $Questions.match.criteria['none'] | Should -Not -BeNullOrEmpty
            [pscustomobject]@{
                answers = [ordered]@{
                    match = [pscustomobject]@{ type = 'choice'; choice = 'candidate002' }
                }
            }
        }
    }

    It 'compares all strings in one request and returns the exact selected line' {
        $lines = @('Process started.', 'Payment key expired.', 'Checkout failed.')
        $results = @($lines | Find-Jev 'Which entry explains the failure?')

        $results.Count | Should -Be 1
        $results[0] | Should -Be 'Payment key expired.'
        $results[0] | Should -BeOfType [string]
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 1 -Scope It -ParameterFilter {
            $Questions.match.criteria.Count -eq 4 -and
            $Questions.match.criteria['candidate001'] -eq 'Process started.' -and
            $Questions.match.criteria['candidate002'] -eq 'Payment key expired.' -and
            $Questions.match.criteria['candidate003'] -eq 'Checkout failed.'
        }
    }

    It 'returns nothing when Jev selects none fits' {
        Mock -ModuleName Jev Invoke-JevDecision {
            [pscustomobject]@{ answers = @{ match = @{ choice = 'none' } } }
        }

        $results = @(@('Healthy.', 'No errors.') | Find-Jev 'Which entry explains the failure?')

        $results.Count | Should -Be 0
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 1 -Scope It
    }

    It 'serializes object candidates but returns the original object without changes' {
        $first = [pscustomobject]@{ Id = 1; Message = 'Process started.' }
        $second = [pscustomobject]@{ Id = 2; Message = 'Payment key expired.'; match = 'Existing value' }
        $results = @(@($first, $second) | Find-Jev 'Which entry explains the failure?')

        $results.Count | Should -Be 1
        [object]::ReferenceEquals($results[0], $second) | Should -BeTrue
        $second.match | Should -Be 'Existing value'
        @($second.PSObject.Properties.Name) | Should -Be @('Id', 'Message', 'match')
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 1 -Scope It -ParameterFilter {
            ($Questions.match.criteria['candidate002'] | ConvertFrom-Json).Message -eq 'Payment key expired.'
        }
    }

    It 'preserves dictionary and dotnet object identity and accepts dictionary responses' {
        $dictionary = [ordered]@{ Id = 1; Message = 'Payment key expired.' }
        $version = [version] '2.8.0'
        Mock -ModuleName Jev Invoke-JevDecision {
            @{ answers = @{ match = @{ choice = 'candidate001' } } }
        }
        $dictionaryResult = @(@($dictionary, $version) | Find-Jev 'Which entry explains the failure?')
        [object]::ReferenceEquals($dictionaryResult[0], $dictionary) | Should -BeTrue

        Mock -ModuleName Jev Invoke-JevDecision {
            @{ answers = @{ match = @{ choice = 'candidate002' } } }
        }
        $versionResult = @(@($dictionary, $version) | Find-Jev 'Which entry explains the failure?')
        [object]::ReferenceEquals($versionResult[0], $version) | Should -BeTrue
        $versionResult[0] | Should -BeOfType [version]
    }

    It 'keeps identical candidates separate and returns the selected original' {
        $first = [pscustomobject]@{ Message = 'Same text.' }
        $second = [pscustomobject]@{ Message = 'Same text.' }
        $results = @(@($first, $second) | Find-Jev 'Which entry explains the failure?')

        [object]::ReferenceEquals($results[0], $second) | Should -BeTrue
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 1 -Scope It -ParameterFilter {
            $Questions.match.criteria.Count -eq 3
        }
    }

    It 'accepts a single named candidate and preserves a named array as one candidate' {
        Mock -ModuleName Jev Invoke-JevDecision {
            param($State, $Questions)
            $Questions.match.criteria.Count | Should -Be 2
            ($Questions.match.criteria['candidate001'] | ConvertFrom-Json).Count | Should -Be 2
            [pscustomobject]@{ answers = @{ match = @{ choice = 'candidate001' } } }
        }
        $candidate = @('First field.', 'Second field.')
        $results = @(Find-Jev -State $candidate 'Which entry explains the failure?')

        $results.Count | Should -Be 1
        [object]::ReferenceEquals($results[0], $candidate) | Should -BeTrue
        ($results[0] -is [object[]]) | Should -BeTrue
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 1 -Scope It
    }

    It 'evaluates a single piped candidate rather than automatically returning it' {
        Mock -ModuleName Jev Invoke-JevDecision {
            param($State, $Questions)
            $Questions.match.criteria.Count | Should -Be 2
            [pscustomobject]@{ answers = @{ match = @{ choice = 'none' } } }
        }
        @('Healthy.' | Find-Jev 'Which entry explains the failure?').Count | Should -Be 0
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 1 -Scope It
    }

    It 'makes no request for empty input' {
        @(@() | Find-Jev 'Which entry explains the failure?').Count | Should -Be 0
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 0 -Scope It
    }

    It 'accepts 254 candidates plus the none choice in one request' {
        $results = @(1..254 | Find-Jev 'Which entry explains the failure?')

        $results | Should -Be @(2)
        $results[0] | Should -BeOfType [int]
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 1 -Scope It -ParameterFilter {
            $Questions.match.criteria.Count -eq 255
        }
    }

    It 'rejects 255 candidates before making a request' {
        { 1..255 | Find-Jev 'Which entry explains the failure?' } | Should -Throw '*at most 254*'
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 0 -Scope It
    }

    It 'rejects an unknown selection rather than silently returning no match' {
        Mock -ModuleName Jev Invoke-JevDecision {
            [pscustomobject]@{ answers = @{ match = @{ choice = 'candidate999' } } }
        }
        { @('First.', 'Second.') | Find-Jev 'Which entry explains the failure?' } |
            Should -Throw '*unknown candidate*'
    }

    It 'rejects a missing answer: <Case>' -TestCases @(
        @{ Case = 'answers'; Response = [pscustomobject]@{ model = 'test' } }
        @{ Case = 'match'; Response = [pscustomobject]@{ answers = @{} } }
        @{ Case = 'choice'; Response = [pscustomobject]@{ answers = @{ match = @{ confidence = 0.9 } } } }
        @{ Case = 'null choice'; Response = [pscustomobject]@{ answers = @{ match = @{ choice = $null } } } }
    ) {
        param($Case, $Response)
        Mock -ModuleName Jev Invoke-JevDecision { $Response }

        { @('First.', 'Second.') | Find-Jev 'Which entry explains the failure?' } |
            Should -Throw '*Jev did not return*'
    }

    It 'propagates request failures and emits no selected candidate' {
        Mock -ModuleName Jev Invoke-JevDecision { throw 'API unavailable.' }
        $emitted = [System.Collections.Generic.List[object]]::new()

        { @('First.', 'Second.') | Find-Jev 'Which entry explains the failure?' |
                ForEach-Object { $emitted.Add($_) } } | Should -Throw '*API unavailable*'
        $emitted.Count | Should -Be 0
    }
}
