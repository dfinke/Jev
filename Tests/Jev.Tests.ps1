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
        $commands | Should -Contain 'New-JevChoice'
        $commands | Should -Contain 'New-JevQuestion'
        $commands.Count | Should -Be 3
    }

    It 'creates a Noul question' {
        $question = New-JevQuestion -Name churn -Type Noul -Prompt 'Is this an active churn threat?'

        $question.Name | Should -Be 'churn'
        $question.Type | Should -Be 'Noul'
        $question.Instructions | Should -Be 'Is this an active churn threat?'
        @($question.Level).Count | Should -Be 0
        @($question.Choice).Count | Should -Be 0
    }

    It 'creates a Choice question from named choices' {
        $choices = @(
            New-JevChoice -Name support -Description 'Route to support'
            New-JevChoice -Name sales -Description 'Route to sales'
        )
        $question = New-JevQuestion -Name route -Type Choice -Prompt 'Which team should handle this?' -Choice $choices

        $question.Type | Should -Be 'Choice'
        @($question.Choice).Count | Should -Be 2
        $question.Choice[0].Name | Should -Be 'support'
    }

    It 'rejects a Score question with fewer than two levels' {
        {
            New-JevQuestion -Name urgency -Type Score -Prompt 'How urgent is this?' -Level @('Today')
        } | Should -Throw '*requires at least two*'
    }

    It 'rejects duplicate question names' {
        $questions = @(
            New-JevQuestion -Name status -Type Noul -Prompt 'Is this active?'
            New-JevQuestion -Name status -Type Noul -Prompt 'Is this urgent?'
        )

        {
            Invoke-Jev -InputObject 'A test message.' -Question $questions -Mock
        } | Should -Throw '*Duplicate Jev question name*'
    }

    It 'returns mock answers for Noul, Choice, and Score questions' {
        $choices = @(
            New-JevChoice -Name support -Description 'Route to support'
            New-JevChoice -Name sales -Description 'Route to sales'
        )
        $questions = @(
            New-JevQuestion -Name churn -Type Noul -Prompt 'Is this an active churn threat?'
            New-JevQuestion -Name route -Type Choice -Prompt 'Which team should handle this?' -Choice $choices
            New-JevQuestion -Name urgency -Type Score -Prompt 'How urgent is this?' -Level @('Can wait', 'This week', 'Today')
        )

        $result = Invoke-Jev -InputObject 'The customer is blocked by an outage and may cancel.' -Question $questions -Mock

        $result.model | Should -Be 'jev-latest'
        @($result.answers.Keys).Count | Should -Be 3
        $result.answers.Keys | Should -Contain 'churn'
        $result.answers.Keys | Should -Contain 'route'
        $result.answers.Keys | Should -Contain 'urgency'
    }
}
