BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'Jev.psd1') -Force
}

AfterAll {
    Remove-Module Jev -Force -ErrorAction SilentlyContinue
}

Describe 'Add-JevTag independent labels' {
    BeforeEach {
        $tagDefinitions = [ordered]@{
            billing = 'A current billing problem.'
            urgent = 'An unresolved problem with a deadline today.'
        }
        Mock -ModuleName Jev Invoke-JevDecision {
            param($State, $Questions)
            $Questions.Count | Should -Be 2
            $Questions.billing.type | Should -Be 'noul'
            $Questions.urgent.type | Should -Be 'noul'
            $Questions.billing.criteria['true'] | Should -Be 'A current billing problem.'
            $Questions.urgent.criteria['true'] | Should -Be 'An unresolved problem with a deadline today.'
            [pscustomobject]@{
                model = 'test-model'
                answers = [ordered]@{
                    billing = [pscustomobject]@{ type = 'noul'; noul = 0.93 }
                    urgent = [pscustomobject]@{ type = 'noul'; noul = 0.88 }
                }
                usage = [pscustomobject]@{ input_tokens = 123; output_tokens = 12 }
            }
        }
    }

    It 'returns several matching labels and probabilities in one request per record' {
        $results = @(@('First message.', 'Second message.') | Add-JevTag $tagDefinitions 0.8)

        $results.Count | Should -Be 2
        $results.State | Should -Be @('First message.', 'Second message.')
        $results[0].Tags | Should -Be @('billing', 'urgent')
        ($results[0].Tags -is [string[]]) | Should -BeTrue
        $results[0].billing | Should -Be 0.93
        $results[0].urgent | Should -Be 0.88
        $results[0].model | Should -Be 'test-model'
        $results[0].usage.input_tokens | Should -Be 123
        $results[0].answers.billing.noul | Should -Be 0.93
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 2 -Scope It
    }

    It 'includes the exact threshold boundary and keeps a single tag as an array' {
        Mock -ModuleName Jev Invoke-JevDecision {
            [pscustomobject]@{ answers = @{
                billing = @{ type = 'noul'; noul = 0.8 }
                urgent = @{ type = 'noul'; noul = 0.799 }
            } }
        }
        $result = 'A message.' | Add-JevTag $tagDefinitions -Threshold 0.8

        $result.Tags.Count | Should -Be 1
        $result.Tags[0] | Should -Be 'billing'
        ($result.Tags -is [string[]]) | Should -BeTrue
        $result.urgent | Should -Be 0.799
    }

    It 'uses the default threshold of one half' {
        Mock -ModuleName Jev Invoke-JevDecision {
            [pscustomobject]@{ answers = @{
                billing = @{ type = 'noul'; noul = 0.5 }
                urgent = @{ type = 'noul'; noul = 0.49 }
            } }
        }
        $result = 'A message.' | Add-JevTag $tagDefinitions
        $result.Tags | Should -Be @('billing')
    }

    It 'keeps the record with an empty tag array when no label meets the cutoff' {
        Mock -ModuleName Jev Invoke-JevDecision {
            [pscustomobject]@{ answers = @{
                billing = @{ type = 'noul'; noul = 0.02 }
                urgent = @{ type = 'noul'; noul = 0.7 }
            } }
        }
        $results = @('No current problem.' | Add-JevTag $tagDefinitions 0.8)

        $results.Count | Should -Be 1
        $results[0].Tags.Count | Should -Be 0
        ($results[0].Tags -is [string[]]) | Should -BeTrue
        $results[0].State | Should -Be 'No current problem.'
        $results[0].urgent | Should -Be 0.7
    }

    It 'retains object properties and handles repeated collisions without modifying the input' {
        $original = [pscustomobject]@{
            Id = 'MAIL-01'
            Message = 'Charged twice today.'
            Tags = @('original')
            Jev_Tags = 'Existing tag metadata'
            billing = 'Existing billing data'
            Jev_billing = 'Older probability'
        }
        $result = $original | Add-JevTag $tagDefinitions

        $result.Id | Should -Be 'MAIL-01'
        $result.Message | Should -Be $original.Message
        $result.Tags | Should -Be @('original')
        $result.Jev_Tags | Should -Be 'Existing tag metadata'
        $result.Jev_Jev_Tags | Should -Be @('billing', 'urgent')
        $result.billing | Should -Be 'Existing billing data'
        $result.Jev_billing | Should -Be 'Older probability'
        $result.Jev_Jev_billing | Should -Be 0.93
        @($original.PSObject.Properties.Name) | Should -Not -Contain 'Jev_Jev_Tags'
        @($original.PSObject.Properties.Name) | Should -Not -Contain 'answers'
        [object]::ReferenceEquals($result, $original) | Should -BeFalse
    }

    It 'retains dictionary input properties and preserves a named array under State' {
        $dictionary = [ordered]@{ Id = 42; Message = 'A billing problem.' }
        $dictionaryResult = Add-JevTag -State $dictionary -Tags $tagDefinitions
        $dictionaryResult.Id | Should -Be 42
        $dictionary.Contains('Tags') | Should -BeFalse

        $array = @('A billing problem.', 'Due today.')
        $arrayResult = Add-JevTag -State $array -Tags $tagDefinitions
        [object]::ReferenceEquals($arrayResult.State, $array) | Should -BeTrue
        $arrayResult.Tags | Should -Be @('billing', 'urgent')
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 2 -Scope It
    }

    It 'makes no request for empty pipeline input' {
        @(@() | Add-JevTag $tagDefinitions).Count | Should -Be 0
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 0 -Scope It
    }

    It 'rejects empty definitions before making a request' {
        { 'A message.' | Add-JevTag @{} } | Should -Throw '*at least one*'
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 0 -Scope It
    }

    It 'rejects invalid definitions: <Case>' -TestCases @(
        @{ Case = 'blank name'; Definitions = @{ ' ' = 'A description.' } }
        @{ Case = 'empty description'; Definitions = @{ billing = '' } }
        @{ Case = 'null description'; Definitions = @{ billing = $null } }
        @{ Case = 'non-string description'; Definitions = @{ billing = 42 } }
    ) {
        param($Case, $Definitions)
        { 'A message.' | Add-JevTag $Definitions } | Should -Throw
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 0 -Scope It
    }

    It 'rejects labels that differ only in case before making a request' {
        $definitions = [System.Collections.Generic.Dictionary[string, string]]::new([StringComparer]::Ordinal)
        $definitions.Add('billing', 'A charge problem.')
        $definitions.Add('Billing', 'An invoice problem.')

        { 'A message.' | Add-JevTag $definitions } | Should -Throw '*case-insensitive*'
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 0 -Scope It
    }

    It 'rejects an invalid threshold: <Threshold>' -TestCases @(
        @{ Threshold = -0.1 }
        @{ Threshold = 1.1 }
    ) {
        param($Threshold)
        { 'A message.' | Add-JevTag $tagDefinitions -Threshold $Threshold } | Should -Throw
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 0 -Scope It
    }

    It 'rejects a missing tag probability without emitting a partially tagged record' {
        Mock -ModuleName Jev Invoke-JevDecision {
            [pscustomobject]@{ answers = @{ billing = @{ type = 'noul'; noul = 0.9 } } }
        }
        $emitted = [System.Collections.Generic.List[object]]::new()

        { 'A message.' | Add-JevTag $tagDefinitions | ForEach-Object { $emitted.Add($_) } } |
            Should -Throw '*Noul answer*urgent*'
        $emitted.Count | Should -Be 0
    }

    It 'rejects an invalid probability: <Probability>' -TestCases @(
        @{ Probability = -0.1 }
        @{ Probability = 1.1 }
        @{ Probability = [double]::NaN }
        @{ Probability = [double]::PositiveInfinity }
    ) {
        param($Probability)
        Mock -ModuleName Jev Invoke-JevDecision {
            [pscustomobject]@{ answers = @{
                billing = @{ type = 'noul'; noul = $Probability }
                urgent = @{ type = 'noul'; noul = 0.9 }
            } }
        }
        { 'A message.' | Add-JevTag $tagDefinitions } | Should -Throw '*invalid probability*'
    }

    It 'propagates request failures' {
        Mock -ModuleName Jev Invoke-JevDecision { throw 'API unavailable.' }
        { 'A message.' | Add-JevTag $tagDefinitions } | Should -Throw '*API unavailable*'
    }
}
