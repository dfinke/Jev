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
        $commands.Count | Should -Be 2
    }

    It 'uses State as the canonical input parameter with a legacy alias' {
        $parameter = (Get-Command Invoke-Jev).Parameters['State']

        $parameter | Should -Not -BeNullOrEmpty
        @($parameter.Aliases) | Should -Contain 'InputObject'
    }

    It 'creates a Noul question' {
        $question = New-JevQuestion -Name churn -Type Noul -Instructions 'Is this an active churn threat?'

        $question.Name | Should -Be 'churn'
        $question.Type | Should -Be 'Noul'
        $question.Instructions | Should -Be 'Is this an active churn threat?'
        $null -eq $question.Criteria | Should -BeTrue
        $question.PSObject.Properties.Name | Should -Be @('Name', 'Type', 'Instructions', 'Criteria')
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
        $merged.answers.escalate | Should -Not -BeNullOrEmpty

        $raw = Invoke-Jev -State $state -Question $question -Mock -Raw
        @($raw.PSObject.Properties.Name) | Should -Not -Contain 'message'
        $raw.model | Should -Be 'jev-latest'
    }
}
