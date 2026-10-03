BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' 'Jev.psd1'
    Import-Module $modulePath -Force
}

AfterAll {
    Remove-Module Jev -Force -ErrorAction SilentlyContinue
}

Describe 'Jev module' {
    It 'exports the public commands' {
        $commands = @(Get-Command -Module Jev | Select-Object -ExpandProperty Name)

        $commands | Should -Contain 'Invoke-Jev'
        $commands | Should -Contain 'New-JevQuestion'
        $commands | Should -Contain 'New-JevYesNoQuestion'
        $commands | Should -Contain 'Test-Jev'
        $commands | Should -Contain 'Select-Jev'
        $commands | Should -Contain 'Add-JevAnnotation'
        $commands | Should -Contain 'Get-JevRanking'
        $commands | Should -Contain 'Find-Jev'
        $commands | Should -Contain 'Add-JevTag'
        $commands.Count | Should -Be 9
    }

    It 'imports without command-name warnings' {
        $importWarnings = @()
        Import-Module $modulePath -Force -WarningVariable importWarnings

        $importWarnings.Count | Should -Be 0
    }

    It 'uses State as the canonical input parameter with a legacy alias' {
        $parameter = (Get-Command Invoke-Jev).Parameters['State']

        $parameter | Should -Not -BeNullOrEmpty
        @($parameter.Aliases) | Should -Contain 'InputObject'
    }

    It 'adds Jev to arrays and evaluates each record' {
        Mock -ModuleName Jev Invoke-JevDecision {
            param($State, $Questions, $Model)

            [pscustomobject] [ordered]@{
                model   = $Model
                answers = [ordered]@{
                    decision = [pscustomobject] [ordered]@{
                        type = 'noul'
                        noul = 0.93
                    }
                }
                usage   = [pscustomobject] [ordered]@{
                    input_tokens  = 0
                    output_tokens = 0
                }
            }
        }

        $records = @(
            [pscustomobject] @{ id = 1; message = 'First record.' }
            [pscustomobject] @{ id = 2; message = 'Second record.' }
        )

        $results = @($records.Jev('should this record be kept?'))

        $results.Count | Should -Be 2
        $results.id | Should -Be @(1, 2)
        $results.decision | Should -Be @(0.93, 0.93)
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 2 -Scope It
    }

    It 'creates a Noul question' {
        $question = New-JevQuestion -Name churn -Type Noul -Instructions 'Is this an active churn threat?'

        $question.Name | Should -Be 'churn'
        $question.Type | Should -Be 'Noul'
        $question.Instructions | Should -Be 'Is this an active churn threat?'
        $null -eq $question.Criteria | Should -BeTrue
        $question.PSObject.Properties.Name | Should -Be @('Name', 'Type', 'Instructions', 'Criteria')
    }

    It 'creates a yes/no question with explicit criteria' {
        $question = New-JevYesNoQuestion -Name pageOnCall `
            -Question 'Should the on-call engineer be paged now?' `
            -TrueCriteria 'Customers cannot complete purchases' `
            -FalseCriteria 'Purchases are working normally'

        $question.Name | Should -Be 'pageOnCall'
        $question.Type | Should -Be 'Noul'
        $question.Instructions | Should -Be 'Should the on-call engineer be paged now?'
        $question.Criteria['true'] | Should -Be 'Customers cannot complete purchases'
        $question.Criteria['false'] | Should -Be 'Purchases are working normally'
    }

    It 'returns one thresholded Boolean for each piped state' {
        Mock -ModuleName Jev Invoke-JevDecision {
            param($State, $Questions, $Model)

            $probability = if ([string] $State -like '*charged twice*') { 0.91 } else { 0.27 }
            [pscustomobject] [ordered]@{
                answers = [ordered]@{
                    answer = [pscustomobject] [ordered]@{
                        type = 'noul'
                        noul = $probability
                    }
                }
            }
        }

        $states = @(
            'The customer was charged twice and asks for a refund.'
            'The customer asks whether the package has shipped.'
        )
        $results = @($states | Test-Jev -Question 'Does the customer ask for a refund?' -Threshold 0.8)

        $results.Count | Should -Be 2
        $results[0] | Should -BeTrue
        $results[0] | Should -BeOfType [bool]
        $results[1] | Should -BeFalse
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 2 -Scope It
    }

    It 'accepts a named state and uses the default 0.5 threshold' {
        Mock -ModuleName Jev Invoke-JevDecision {
            [pscustomobject] [ordered]@{
                answers = [ordered]@{
                    answer = [pscustomobject] [ordered]@{ type = 'noul'; noul = 0.6 }
                }
            }
        }

        $result = Test-Jev -State 'The customer requests a refund.' -Question 'Does the customer ask for a refund?'

        $result | Should -BeTrue
        $result | Should -BeOfType [bool]
    }

    It 'accepts a positional question with piped reviews' {
        Mock -ModuleName Jev Invoke-JevDecision {
            param($State, $Questions)

            $Questions.answer.instructions | Should -Be 'Is this a complaint?'
            $probability = switch ([string] $State) {
                'Arrived a day early. Thank you!' { 0.1 }
                'The zipper broke the first time I used it.' { 0.95 }
                'Does this come in blue?' { 0.2 }
                'The strap snapped on day two.' { 0.7 }
                default { throw "Unexpected state: $State" }
            }
            [pscustomobject]@{
                answers = [pscustomobject]@{
                    answer = [pscustomobject]@{ noul = $probability }
                }
            }
        }

        $reviews = @(
            'Arrived a day early. Thank you!'
            'The zipper broke the first time I used it.'
            'Does this come in blue?'
            'The strap snapped on day two.'
        )

        $results = @($reviews | Test-Jev 'Is this a complaint?')
        $results | Should -Be @($false, $true, $false, $true)

        $strictResults = @($reviews | Test-Jev 'Is this a complaint?' 0.8)
        $strictResults | Should -Be @($false, $true, $false, $false)
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 8 -Scope It
    }

    It 'creates a Choice question from criteria' {
        $criteria = [ordered]@{
            support = 'Route to support'
            sales = 'Route to sales'
        }
        $question = New-JevQuestion -Name route -Type Choice -Instructions 'Which team should handle this?' -Criteria $criteria

        $question.Type | Should -Be 'Choice'
        $question.Criteria.Count | Should -Be 2
        $question.Criteria['support'] | Should -Be 'Route to support'
    }

    It 'rejects a Score question with fewer than two levels' {
        {
            New-JevQuestion -Name urgency -Type Score -Instructions 'How urgent is this?' -Criteria @('Today')
        } | Should -Throw '*requires at least two*'
    }

    It 'rejects duplicate question names' {
        $questions = @(
            New-JevQuestion -Name status -Type Noul -Instructions 'Is this active?'
            New-JevQuestion -Name status -Type Noul -Instructions 'Is this urgent?'
        )

        {
            Invoke-Jev -State 'A test message.' -Question $questions -Mock
        } | Should -Throw '*Duplicate Jev question name*'
    }

    It 'returns mock answers for Noul, Choice, and Score questions' {
        $criteria = [ordered]@{
            support = 'Route to support'
            sales = 'Route to sales'
        }
        $questions = @(
            New-JevQuestion -Name churn -Type Noul -Instructions 'Is this an active churn threat?'
            New-JevQuestion -Name route -Type Choice -Instructions 'Which team should handle this?' -Criteria $criteria
            New-JevQuestion -Name urgency -Type Score -Instructions 'How urgent is this?' -Criteria @('Can wait', 'This week', 'Today')
        )

        $result = Invoke-Jev -State 'The customer is blocked by an outage and may cancel.' -Question $questions -Mock

        $result.model | Should -Be 'jev-latest'
        @($result.answers.Keys).Count | Should -Be 3
        $result.answers.Keys | Should -Contain 'churn'
        $result.answers.Keys | Should -Contain 'route'
        $result.answers.Keys | Should -Contain 'urgency'
    }

    It 'merges state by default and returns only the API response with Raw' {
        $state = [pscustomobject]@{
            message = 'The checkout service is returning errors.'
            source  = 'system-log'
        }
        $question = New-JevQuestion -Name escalate -Type Noul -Instructions 'Should this incident be escalated?'

        $merged = Invoke-Jev -State $state -Question $question -Mock
        $merged.message | Should -Be $state.message
        $merged.source | Should -Be 'system-log'
        $merged.model | Should -Be 'jev-latest'
        $merged.escalate | Should -Be 0.08
        $merged.answers.escalate | Should -Not -BeNullOrEmpty

        $raw = Invoke-Jev -State $state -Question $question -Mock -Raw
        @($raw.PSObject.Properties.Name) | Should -Not -Contain 'message'
        $raw.model | Should -Be 'jev-latest'

        $states = @(
            [pscustomobject] @{ message = 'First event.' }
            [pscustomobject] @{ message = 'Second event.' }
        )
        $rawItems = @($states | Invoke-Jev -Question $question -Mock -Raw)
        $rawItems.Count | Should -Be 2
    }

    It 'returns JSON text for merged and raw responses' {
        $question = New-JevQuestion -Name escalate -Type Noul -Instructions 'Escalate this?'

        $mergedJson = Invoke-Jev -State 'Checkout is unavailable.' -Question $question -Mock -AsJson
        $mergedJson | Should -BeOfType [string]
        $merged = $mergedJson | ConvertFrom-Json
        $merged.State | Should -Be 'Checkout is unavailable.'
        $merged.PSObject.Properties.Name | Should -Contain 'escalate'

        $rawJson = Invoke-Jev -State 'Checkout is unavailable.' -Question $question -Mock -Raw -AsJson
        $rawJson | Should -BeOfType [string]
        $raw = $rawJson | ConvertFrom-Json
        $raw.PSObject.Properties.Name | Should -Not -Contain 'State'
        $raw.answers.escalate.type | Should -Be 'noul'
    }
}
