BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'Jev.psd1') -Force
}

AfterAll {
    Remove-Module Jev -Force -ErrorAction SilentlyContinue
}

Describe 'Get-JevRanking semantic ranking' {
    BeforeEach {
        Mock -ModuleName Jev Invoke-JevDecision {
            param($State, $Questions)

            $Questions.Count | Should -Be 1
            $Questions.ranking.type | Should -Be 'noul'
            $Questions.ranking.instructions | Should -Be 'Does this need urgent attention?'
            $probability = if ($State -is [version]) {
                $State.Minor / 10
            }
            elseif ($State -is [string]) {
                switch ($State) {
                    'Low' { 0.05 }
                    'Middle' { 0.6 }
                    'High' { 0.95 }
                    'Tie A' { 0.6 }
                    'Tie B' { 0.6 }
                    'Zero' { 0.0 }
                    'One' { 1.0 }
                    default { throw "Unexpected state: $State" }
                }
            }
            else {
                $State.Probability
            }
            [pscustomobject]@{
                answers = [ordered]@{
                    ranking = [pscustomobject]@{ type = 'noul'; noul = $probability }
                }
            }
        }
    }

    It 'returns all original strings in descending order with stable ties' {
        $results = @(@('Low', 'Middle', 'High', 'Tie A', 'Tie B') | Get-JevRanking 'Does this need urgent attention?')

        $results | Should -Be @('High', 'Middle', 'Tie A', 'Tie B', 'Low')
        $results[0] | Should -BeOfType [string]
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 5 -Scope It
    }

    It 'limits output with Top while evaluating every input and keeping the earlier boundary tie' {
        $results = @(@('Low', 'Tie A', 'High', 'Tie B') | Get-JevRanking 'Does this need urgent attention?' -Top 2)

        $results | Should -Be @('High', 'Tie A')
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 4 -Scope It
    }

    It 'preserves original objects, types, and properties without using input ranking fields' {
        $ticket = [pscustomobject]@{ Id = 1; Probability = 0.7; ranking = 0.01 }
        $dictionary = [ordered]@{ Id = 2; Probability = 0.3; ranking = 0.99 }
        $version = [version] '2.9'
        $results = @(@($ticket, $dictionary, $version) | Get-JevRanking 'Does this need urgent attention?')

        $results.Count | Should -Be 3
        [object]::ReferenceEquals($results[0], $version) | Should -BeTrue
        [object]::ReferenceEquals($results[1], $ticket) | Should -BeTrue
        [object]::ReferenceEquals($results[2], $dictionary) | Should -BeTrue
        $results[0] | Should -BeOfType [version]
        $ticket.ranking | Should -Be 0.01
        $dictionary.ranking | Should -Be 0.99
        @($ticket.PSObject.Properties.Name) | Should -Not -Contain 'answers'
    }

    It 'accepts named input and preserves a complete array as one record' {
        Mock -ModuleName Jev Invoke-JevDecision {
            [pscustomobject]@{
                answers = [pscustomobject]@{
                    ranking = [pscustomobject]@{ type = 'noul'; noul = 0.9 }
                }
            }
        }

        $state = @('First part.', 'Second part.')
        $results = @(Get-JevRanking -State $state -Question 'Does this need urgent attention?' -Top 10)

        $results.Count | Should -Be 1
        [object]::ReferenceEquals($results[0], $state) | Should -BeTrue
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 1 -Scope It
    }

    It 'includes valid zero and one probabilities' {
        $results = @(@('Zero', 'One') | Get-JevRanking 'Does this need urgent attention?')

        $results | Should -Be @('One', 'Zero')
    }

    It 'makes no requests and emits nothing for an empty pipeline' {
        $results = @(@() | Get-JevRanking 'Does this need urgent attention?')

        $results.Count | Should -Be 0
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 0 -Scope It
    }

    It 'rejects Top <Top> before making a request' -TestCases @(
        @{ Top = 0 }
        @{ Top = -1 }
    ) {
        param($Top)

        { 'High' | Get-JevRanking 'Does this need urgent attention?' -Top $Top } | Should -Throw
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 0 -Scope It
    }

    It 'rejects a missing Noul answer instead of ranking it as zero' {
        Mock -ModuleName Jev Invoke-JevDecision {
            [pscustomobject]@{ answers = [pscustomobject]@{} }
        }

        { 'High' | Get-JevRanking 'Does this need urgent attention?' } | Should -Throw '*did not return a Noul answer*'
    }

    It 'rejects an invalid probability: <Probability>' -TestCases @(
        @{ Probability = -0.1 }
        @{ Probability = 1.1 }
        @{ Probability = [double]::NaN }
        @{ Probability = [double]::PositiveInfinity }
    ) {
        param($Probability)

        Mock -ModuleName Jev Invoke-JevDecision {
            [pscustomobject]@{
                answers = [pscustomobject]@{
                    ranking = [pscustomobject]@{ type = 'noul'; noul = $Probability }
                }
            }
        }

        { 'High' | Get-JevRanking 'Does this need urgent attention?' } | Should -Throw '*invalid probability*'
    }

    It 'propagates a failed request without emitting a partial ranking' {
        Mock -ModuleName Jev Invoke-JevDecision {
            param($State)

            if ($State -eq 'Middle') { throw 'Ranking backend unavailable.' }
            [pscustomobject]@{
                answers = [pscustomobject]@{
                    ranking = [pscustomobject]@{ type = 'noul'; noul = 0.9 }
                }
            }
        }

        $received = [System.Collections.Generic.List[object]]::new()
        {
            @('High', 'Middle', 'Low') | Get-JevRanking 'Does this need urgent attention?' |
                ForEach-Object { $received.Add($_) }
        } | Should -Throw '*Ranking backend unavailable*'
        $received.Count | Should -Be 0
    }
}
