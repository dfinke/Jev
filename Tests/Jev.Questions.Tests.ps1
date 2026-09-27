BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' 'Jev.psd1'
    Import-Module $modulePath -Force
}

AfterAll {
    Remove-Module Jev -Force -ErrorAction SilentlyContinue
}

Describe 'Jev Question Primitives' {
    Context 'New-JevChoiceQuestion' {
        It 'creates a valid Choice question' {
            $choices = [ordered]@{
                billing   = 'Billing issues'
                technical = 'Technical issues'
            }
            $q = New-JevChoiceQuestion -Name 'dept' -Instructions 'Which dept?' -Choices $choices

            $q.Name | Should -Be 'dept'
            $q.Type | Should -Be 'Choice'
            $q.Instructions | Should -Be 'Which dept?'
            $q.Criteria.Count | Should -Be 2
            $q.Criteria['billing'] | Should -Be 'Billing issues'
        }

        It 'automatically adds other fallback when -AllowOther is passed' {
            $choices = @{
                billing = 'Billing'
                tech    = 'Technical'
            }
            $q = New-JevChoiceQuestion -Name 'dept' -Instructions 'Which dept?' -Choices $choices -AllowOther

            $q.Criteria.Contains('other') | Should -BeTrue
            $q.Criteria['other'] | Should -Be 'None of the above.'
            $q.Criteria.Count | Should -Be 3
        }

        It 'adds custom fallback description when -FallbackDescription is passed' {
            $choices = @{
                billing = 'Billing'
            }
            $q = New-JevChoiceQuestion -Name 'dept' -Instructions 'Which dept?' -Choices $choices -FallbackDescription 'Not listed here'

            $q.Criteria.Contains('other') | Should -BeTrue
            $q.Criteria['other'] | Should -Be 'Not listed here'
        }
    }

    Context 'New-JevScoreQuestion' {
        It 'creates a valid Score question with 3 levels' {
            $levels = @('Calm', 'Frustrated', 'Angry')
            $q = New-JevScoreQuestion -Name 'frustration' -Instructions 'Customer frustration?' -Levels $levels

            $q.Name | Should -Be 'frustration'
            $q.Type | Should -Be 'Score'
            $q.Criteria.Count | Should -Be 3
            $q.LevelCount | Should -Be 3
            $q.MaxLevel | Should -Be 2
        }

        It 'throws when fewer than 2 levels are provided' {
            {
                New-JevScoreQuestion -Name 'invalid' -Instructions 'Test' -Levels @('OnlyOne')
            } | Should -Throw '*requires at least two*'
        }

        It 'throws when more than 10 levels are provided' {
            $many = 1..11 | ForEach-Object { "Level $_" }
            {
                New-JevScoreQuestion -Name 'invalid' -Instructions 'Test' -Levels $many
            } | Should -Throw '*cannot have more than 10*'
        }
    }

    Context 'New-JevCriterion' {
        It 'builds structured criterion dictionary' {
            $crit = New-JevCriterion -What 'Payment questions' -NotFor 'Account setup' -Examples @('Invoice error', 'Receipt copy')

            $crit.what | Should -Be 'Payment questions'
            $crit.not_for | Should -Be 'Account setup'
            $crit.examples.Count | Should -Be 2
            $crit.examples[0] | Should -Be 'Invoice error'
        }
    }

    Context 'New-JevQuestionSet' {
        It 'bundles and validates a question set' {
            $q1 = New-JevYesNoQuestion -Name 'urgent' -Question 'Urgent?' -TrueCriteria 'Yes' -FalseCriteria 'No'
            $q2 = New-JevScoreQuestion -Name 'severity' -Instructions 'Severity?' -Levels @('Low', 'High')

            $set = @($q1, $q2) | New-JevQuestionSet
            $set.Count | Should -Be 2
            $set[0].Name | Should -Be 'urgent'
            $set[1].Name | Should -Be 'severity'
        }

        It 'throws on duplicate question names' {
            $q1 = New-JevYesNoQuestion -Name 'status' -Question 'Active?' -TrueCriteria 'Yes' -FalseCriteria 'No'
            $q2 = New-JevScoreQuestion -Name 'status' -Instructions 'Score?' -Levels @('Low', 'High')

            {
                New-JevQuestionSet -Question @($q1, $q2)
            } | Should -Throw '*Duplicate question name*'
        }
    }
}
