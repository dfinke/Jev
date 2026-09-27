BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' 'Jev.psd1'
    Import-Module $modulePath -Force
}

AfterAll {
    Remove-Module Jev -Force -ErrorAction SilentlyContinue
}

Describe 'Jev Decision Composition & Uncertainty' {
    Context 'Get-JevConfidenceTier' {
        It 'correctly assigns Act tier for high confidence choice' {
            $mockChoice = [pscustomobject]@{
                type       = 'choice'
                choice     = 'billing'
                confidence = 0.88
            }
            $tier = $mockChoice | Get-JevConfidenceTier

            $tier.Tier | Should -Be 'Act'
            $tier.ShouldAct | Should -BeTrue
            $tier.Confidence | Should -Be 0.88
        }

        It 'correctly assigns Review tier for medium confidence' {
            $mockChoice = [pscustomobject]@{
                type       = 'choice'
                choice     = 'technical'
                confidence = 0.65
            }
            $tier = $mockChoice | Get-JevConfidenceTier

            $tier.Tier | Should -Be 'Review'
            $tier.ShouldAct | Should -BeFalse
        }

        It 'correctly assigns Escalate tier for low confidence' {
            $mockChoice = [pscustomobject]@{
                type       = 'choice'
                choice     = 'other'
                confidence = 0.35
            }
            $tier = $mockChoice | Get-JevConfidenceTier

            $tier.Tier | Should -Be 'Escalate'
            $tier.ShouldAct | Should -BeFalse
        }

        It 'adjusts thresholds with High RiskLevel' {
            $mockChoice = [pscustomobject]@{
                type       = 'choice'
                choice     = 'security'
                confidence = 0.82
            }
            # Under Standard (0.8 cutoff), 0.82 is Act. Under High (0.9 cutoff), 0.82 is Review!
            $tierStandard = $mockChoice | Get-JevConfidenceTier -RiskLevel Standard
            $tierHigh = $mockChoice | Get-JevConfidenceTier -RiskLevel High

            $tierStandard.Tier | Should -Be 'Act'
            $tierHigh.Tier | Should -Be 'Review'
        }
    }

    Context 'Measure-JevScore' {
        It 'calculates weighted composite score' {
            $result = [pscustomobject]@{
                urgency = 0.8
                impact  = 0.6
            }

            $score = $result | Measure-JevScore -Weights @{ urgency = 0.5; impact = 0.5 }

            $score.CompositeScore | Should -Be 0.7
            $score.IsOverride | Should -BeFalse
        }

        It 'normalizes score properties using ScoreMaxLevels' {
            $result = [pscustomobject]@{
                urgency  = 1.0  # level 1 out of 2 (so normalized 0.5)
                priority = 0.9
            }

            $score = $result | Measure-JevScore -Weights @{ urgency = 0.5; priority = 0.5 } -ScoreMaxLevels @{ urgency = 2 }

            # urgency normalized = 1.0 / 2 = 0.5. priority = 0.9. Average = (0.5 * 0.5 + 0.9 * 0.5) / 1.0 = 0.70
            $score.CompositeScore | Should -Be 0.7
        }

        It 'applies policy override when threshold is met' {
            $result = [pscustomobject]@{
                policy_violation = 0.95
                urgency          = 0.2
            }

            $overrides = @(
                @{ Property = 'policy_violation'; Threshold = 0.9; Action = 'Block' }
            )

            $score = $result | Measure-JevScore -Weights @{ urgency = 1.0 } -Overrides $overrides

            $score.IsOverride | Should -BeTrue
            $score.AppliedOverride | Should -Be 'Block'
            $score.TriggerProperty | Should -Be 'policy_violation'
        }
    }

    Context 'Invoke-JevRerank' {
        It 'ranks candidate items offline with -Mock' {
            $candidates = @(
                [pscustomobject]@{ id = 1; name = 'Connection timeout in production database' }
                [pscustomobject]@{ id = 2; name = 'Minor styling glitch on button' }
            )

            $ranked = $candidates | Invoke-JevRerank -Query 'Database connection error' -Property 'name' -Mock
            $ranked.Count | Should -Be 2
            $ranked[0].PSObject.Properties.Name | Should -Contain 'JevRelevance'
        }
    }
}
