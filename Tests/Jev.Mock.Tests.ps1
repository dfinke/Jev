BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' 'Jev.psd1'
    Import-Module $modulePath -Force
}

AfterAll {
    Remove-Module Jev -Force -ErrorAction SilentlyContinue
}

Describe 'Jev Dynamic Mock & Fixtures' {
    BeforeEach {
        Clear-JevMockRule
    }

    AfterEach {
        Clear-JevMockRule
    }

    Context 'Dynamic Mock Rules' {
        It 'matches custom mock rule for Noul' {
            Set-JevMockRule -QuestionName 'custom_check' -Matcher { $args[0].text -match 'special_token' } -Answer 0.99

            $stateMatch = [pscustomobject]@{ text = 'Contains special_token here' }
            $stateNoMatch = [pscustomobject]@{ text = 'Ordinary text' }
            $q = New-JevQuestion -Name 'custom_check' -Type Noul -Instructions 'Check token'

            $res1 = Invoke-Jev -State $stateMatch -Question $q -Mock
            $res1.custom_check | Should -Be 0.99

            $res2 = Invoke-Jev -State $stateNoMatch -Question $q -Mock
            $res2.custom_check | Should -Be 0.08
        }

        It 'matches custom mock rule for Choice' {
            Set-JevMockRule -QuestionName 'priority' -Matcher { $true } -Answer 'p1' -Confidence 0.96

            $q = New-JevChoiceQuestion -Name 'priority' -Instructions 'Priority?' -Choices @{ p1 = 'P1'; p2 = 'P2' }
            $res = Invoke-Jev -State 'Any message' -Question $q -Mock

            $res.priority | Should -Be 'p1'
            $res.answers.priority.confidence | Should -Be 0.96
        }

        It 'clears mock rules' {
            Set-JevMockRule -QuestionName 'test' -Matcher { $true } -Answer 0.99
            Clear-JevMockRule -QuestionName 'test'

            $q = New-JevQuestion -Name 'test' -Type Noul -Instructions 'Test?'
            $res = Invoke-Jev -State 'test' -Question $q -Mock
            $res.test | Should -Not -Be 0.99
        }
    }

    Context 'Fixture Export and Import' {
        It 'exports and imports fixture for replay' {
            $tempFixture = Join-Path ([System.IO.Path]::GetTempPath()) "jev_test_fixture_$(Get-Random).json"
            try {
                $q = New-JevChoiceQuestion -Name 'route' -Instructions 'Route?' -Choices @{ support = 'Support'; sales = 'Sales' }
                $state = [pscustomobject]@{ issue = 'Billing question' }

                Set-JevMockRule -QuestionName 'route' -Matcher { $true } -Answer 'support' -Confidence 0.91

                $exported = Export-JevFixture -Path $tempFixture -State $state -Question $q -Mock
                Test-Path -LiteralPath $tempFixture | Should -BeTrue

                Clear-JevMockRule

                $importedRules = Import-JevFixture -Path $tempFixture
                $importedRules.Count | Should -Be 1

                $replayResult = Invoke-Jev -State $state -Question $q -Mock
                $replayResult.route | Should -Be 'support'
                $replayResult.answers.route.confidence | Should -Be 0.91
            }
            finally {
                if (Test-Path -LiteralPath $tempFixture) {
                    Remove-Item -LiteralPath $tempFixture -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
}
