BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' 'Jev.psd1'
    Import-Module $modulePath -Force
}

AfterAll {
    Remove-Module Jev -Force -ErrorAction SilentlyContinue
}

Describe 'Jev Pipeline & Array Extensions' {
    Context 'Where-Jev' {
        It 'filters pipeline items based on mock match' {
            $items = @(
                [pscustomobject]@{ id = 1; msg = 'CRITICAL: Security breach detected in authentication service' }
                [pscustomobject]@{ id = 2; msg = 'Routine daily log rotation completed normally' }
            )

            $filtered = @($items | Where-Jev 'Is this an active security threat?' -Threshold 0.8 -Mock)
            $filtered.Count | Should -Be 1
            $filtered[0].id | Should -Be 1
        }

        It 'supports -PassThruOriginal switch' {
            $items = @(
                [pscustomobject]@{ id = 1; msg = 'CRITICAL: Security breach detected' }
            )

            $filtered = @($items | Where-Jev 'Is this security?' -Threshold 0.8 -Mock -PassThruOriginal)
            $filtered[0].PSObject.Properties.Name | Should -Not -Contain 'filter_decision'
            $filtered[0].id | Should -Be 1
        }
    }

    Context 'Select-JevRoute' {
        It 'routes to matching scriptblock based on choice' {
            $routeQ = New-JevChoiceQuestion -Name 'dept' -Instructions 'Which team?' -Choices @{
                billing = 'Invoice or payment'
                network = 'Timeout or network connection'
                other   = 'None'
            }

            $events = @(
                [pscustomobject]@{ text = 'Network timeout connecting to database socket' }
            )

            $routedDestinations = [System.Collections.Generic.List[string]]::new()
            $events | Select-JevRoute -Question $routeQ -Routes @{
                billing = { param($item) $routedDestinations.Add("Billing: $($item.text)") }
                network = { param($item) $routedDestinations.Add("Network: $($item.text)") }
                other   = { param($item) $routedDestinations.Add("Other: $($item.text)") }
            } -Mock

            $routedDestinations.Count | Should -Be 1
            $routedDestinations[0] | Should -BeLike 'Network:*'
        }
    }

    Context 'Array Extensions' {
        It 'filters with .JevWhere() method' {
            $records = @(
                [pscustomobject]@{ id = 1; text = 'Unauthorized login and attack attempt' }
                [pscustomobject]@{ id = 2; text = 'Normal scheduled task run' }
            )

            $passed = $records.JevWhere('Is this an attack or security incident?', 0.8, [switch]::Present)
            $passed.Count | Should -Be 1
            $passed[0].id | Should -Be 1
        }

        It 'ranks with .JevRank() method' {
            $records = @(
                [pscustomobject]@{ id = 1; summary = 'Database connection failure and timeout' }
                [pscustomobject]@{ id = 2; summary = 'Updated css styling on navbar' }
            )

            $ranked = $records.JevRank('Database socket error', 'summary', 1, [switch]::Present)
            $ranked.Count | Should -Be 1
            $ranked[0].PSObject.Properties.Name | Should -Contain 'JevRelevance'
        }
    }
}
